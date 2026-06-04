#!/usr/bin/env bash
#
# export-3d.sh - regenerate the 3D models (.glb + .dae) for the Cyber Ægg PCB.
#
# Pipeline (one deterministic path):
#   PCB (.kicad_pcb) --kicad-cli--> GLB --Blender + pycollada--> DAE
#
# Why two steps?  KiCad has no DAE/Collada export target, and Blender 5.0 has
# dropped its native Collada exporter.  So KiCad gives us a GLB, and we convert
# that to Collada inside Blender using pycollada (a pure-Python library we drop
# into a throwaway venv - we never touch the Blender install and never need sudo).
#
# Usage:
#   tools/export-3d.sh [path/to/board.kicad_pcb]
#
# Defaults to the repo's bornhack2026-hardware.kicad_pcb.  Outputs land next to
# the repo root as <NAME>.glb and <NAME>.dae (override the directory with $OUTDIR).
#
# Environment overrides:
#   KICAD_CLI            path to kicad-cli            (default: autodetected)
#   BLENDER              path to the Blender binary   (default: autodetected)
#   KICAD9_3DMODEL_DIR   KiCad 3D model library dir   (default: autodetected)
#   VENV_DIR             pycollada venv location      (default: tools/.venv-3d)
#   OUTDIR               output directory             (default: repo root)
#
set -euo pipefail

# Pin pycollada for reproducible output.
PYCOLLADA_VERSION="0.9.3"

# --- Locate ourselves & the repo root, robust to CWD and spaces -------------
# (resolve the real path of this script even if invoked via a symlink)
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }

# --- Resolve the input PCB --------------------------------------------------
PCB="${1:-$REPO_ROOT/bornhack2026-hardware.kicad_pcb}"
[ -f "$PCB" ] || die "PCB file not found: $PCB"

# NAME = the PCB basename without its .kicad_pcb extension.
PCB_BASE="$(basename "$PCB")"
NAME="${PCB_BASE%.kicad_pcb}"

OUTDIR="${OUTDIR:-$REPO_ROOT}"
mkdir -p "$OUTDIR"
GLB="$OUTDIR/$NAME.glb"
DAE="$OUTDIR/$NAME.dae"

# --- Locate kicad-cli -------------------------------------------------------
if [ -n "${KICAD_CLI:-}" ]; then
    command -v "$KICAD_CLI" >/dev/null 2>&1 || die "\$KICAD_CLI is set but not executable: $KICAD_CLI"
elif command -v kicad-cli >/dev/null 2>&1; then
    KICAD_CLI="kicad-cli"
else
    die "kicad-cli not found. Install KiCad 10, or set \$KICAD_CLI to its path.
       On macOS it usually lives at /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"
fi

# --- Locate Blender ---------------------------------------------------------
# We only need a Blender with a bundled Python (>=4 ships 3.11+, 5.0 ships 3.13).
# Older Collada-capable Blenders are deliberately NOT special-cased: we keep one
# deterministic GLB->pycollada path for every version.
if [ -n "${BLENDER:-}" ]; then
    command -v "$BLENDER" >/dev/null 2>&1 || die "\$BLENDER is set but not executable: $BLENDER"
else
    BLENDER=""
    # First try plain PATH names (Linux distro packages, manual installs on PATH).
    for cand in blender blender-5.1 blender-5.0 blender-4.5 blender-4.4 blender-4.3 blender-4.2; do
        if command -v "$cand" >/dev/null 2>&1; then
            BLENDER="$cand"
            break
        fi
    done
    # Then probe the macOS .app bundle, whose binary is NOT on PATH by default.
    if [ -z "$BLENDER" ]; then
        for app in \
            /Applications/Blender.app/Contents/MacOS/Blender \
            "$HOME/Applications/Blender.app/Contents/MacOS/Blender"; do
            if [ -x "$app" ]; then
                BLENDER="$app"
                break
            fi
        done
    fi
    [ -n "$BLENDER" ] || die "Blender not found. Install Blender >=4, or set \$BLENDER to its path.
       Tried PATH names: blender, blender-5.1, blender-5.0, blender-4.5, blender-4.4, blender-4.3, blender-4.2
       On macOS it usually lives at /Applications/Blender.app/Contents/MacOS/Blender"
fi

# Soft version check: warn (do not fail) if we can tell it is older than 5.0.
BLENDER_VER="$("$BLENDER" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
if [ -n "$BLENDER_VER" ]; then
    BL_MAJOR="${BLENDER_VER%%.*}"
    if [ "$BL_MAJOR" -lt 5 ] 2>/dev/null; then
        info "Note: Blender $BLENDER_VER (<5.0) detected; using the same GLB->pycollada path anyway."
    fi
fi

# --- Locate KiCad 3D model dir (for KICAD9_3DMODEL_DIR substitution) ---------
# KiCad footprints reference \${KICAD9_3DMODEL_DIR}.  If it is unset KiCad still
# finds its own default install dir on most systems, but passing -D makes the
# export deterministic, so we probe common locations.
MODEL_DIR="${KICAD9_3DMODEL_DIR:-}"
if [ -z "$MODEL_DIR" ]; then
    for d in \
        /usr/share/kicad/3dmodels \
        /usr/local/share/kicad/3dmodels \
        /Applications/KiCad/KiCad.app/Contents/SharedSupport/3dmodels \
        "$HOME/.local/share/kicad/3dmodels"; do
        if [ -d "$d" ]; then
            MODEL_DIR="$d"
            break
        fi
    done
fi

# --- Provision pycollada into a throwaway venv (no sudo, no Blender changes) -
VENV_DIR="${VENV_DIR:-$REPO_ROOT/tools/.venv-3d}"
VENV_PY="$VENV_DIR/bin/python"
# Test on the interpreter, not just the dir, so an empty/corrupt/interrupted
# venv (a leftover directory with no usable python) is rebuilt rather than
# tripping a confusing failure later.
if [ ! -x "$VENV_PY" ]; then
    command -v python3 >/dev/null 2>&1 || die "python3 not found (needed to create the pycollada venv)."
    if [ -d "$VENV_DIR" ]; then
        info "Existing venv at $VENV_DIR looks incomplete; recreating it."
        rm -rf "$VENV_DIR"
    fi
    info "Creating pycollada venv at: $VENV_DIR"
    python3 -m venv "$VENV_DIR" || die "failed to create venv at $VENV_DIR"
fi
[ -x "$VENV_PY" ] || die "venv python missing/not executable: $VENV_PY
       (delete $VENV_DIR and re-run to recreate the venv)"

# Make sure the venv actually has pip.  On Debian/Ubuntu without the
# python3-venv package, 'python3 -m venv' creates a venv with no pip, which
# would otherwise fail later with a misleading 'check your network' message.
if ! "$VENV_PY" -m pip --version >/dev/null 2>&1; then
    info "venv has no pip; bootstrapping with ensurepip..."
    "$VENV_PY" -m ensurepip --upgrade >/dev/null 2>&1 \
        || die "venv has no pip and ensurepip is unavailable.
       Install the python3-venv / python3-pip package for your python3 and re-run."
fi

# Cache: only pip-install if pycollada is not already importable in the venv.
if "$VENV_PY" -c 'import collada' >/dev/null 2>&1; then
    info "pycollada already present in venv (skipping install)."
else
    info "Installing pycollada==$PYCOLLADA_VERSION into venv (needs network on first run)..."
    "$VENV_PY" -m pip install --upgrade pip >/dev/null 2>&1 || true
    "$VENV_PY" -m pip install "pycollada==$PYCOLLADA_VERSION" \
        || die "pip install pycollada==$PYCOLLADA_VERSION failed.
       Check your network connection (first run needs it), or that the venv has
       a working pip (install the python3-venv / python3-pip package)."
fi

# Compute the venv's purelib site-packages dir; that is what the Blender script
# appends to sys.path so Blender's bundled numpy is never shadowed.  Capture in
# its own 'if' so a non-zero exit is caught by the guard rather than aborting
# the whole script via set -e on the bare assignment.
if ! PYCOLLADA_SITE="$("$VENV_PY" -c 'import sysconfig;print(sysconfig.get_path("purelib"))')"; then
    die "could not query venv site-packages dir from $VENV_PY"
fi
[ -d "$PYCOLLADA_SITE" ] || die "venv site-packages dir does not exist (got: '$PYCOLLADA_SITE')"

# --- Failure hint: outputs may be left in an inconsistent state -------------
# We write each output to a temp file and atomically mv it into place only on
# success (below), so a mid-run failure never overwrites a previously-good
# artifact.  This trap just reminds the user if anything bailed out.
trap 'rc=$?; [ "$rc" -ne 0 ] && echo "export-3d.sh failed (rc=$rc); outputs left unchanged." >&2' EXIT

# --- Step 1: PCB -> GLB via kicad-cli ---------------------------------------
info "Exporting GLB:  $GLB"
GLB_TMP="$GLB.tmp.$$"
KICAD_ARGS=(pcb export glb --include-silkscreen --include-soldermask --subst-models)
if [ -n "$MODEL_DIR" ]; then
    info "Using KiCad 3D model dir: $MODEL_DIR"
    KICAD_ARGS+=(-D "KICAD9_3DMODEL_DIR=$MODEL_DIR")
else
    info "No KiCad 3D model dir found; relying on KiCad's built-in default."
fi
KICAD_ARGS+=(-f -o "$GLB_TMP" "$PCB")
# Note: warnings about missing FPC1 / L1 models are EXPECTED and harmless -
# those two footprints are not in the standard KiCad 3D model library.
"$KICAD_CLI" "${KICAD_ARGS[@]}" || { rm -f "$GLB_TMP"; die "kicad-cli GLB export failed."; }
[ -s "$GLB_TMP" ] || { rm -f "$GLB_TMP"; die "GLB export produced no/empty file."; }
mv -f "$GLB_TMP" "$GLB"

# --- Step 2: GLB -> DAE via Blender + pycollada -----------------------------
info "Converting GLB -> DAE with Blender ($BLENDER)..."
DAE_TMP="$DAE.tmp.$$"
"$BLENDER" --background --factory-startup \
    --python "$SCRIPT_DIR/glb_to_dae.py" -- \
    --glb "$GLB" --dae "$DAE_TMP" --pycollada "$PYCOLLADA_SITE" \
    || { rm -f "$DAE_TMP"; die "Blender GLB->DAE conversion failed."; }
[ -s "$DAE_TMP" ] || { rm -f "$DAE_TMP"; die "DAE conversion produced no/empty file."; }
mv -f "$DAE_TMP" "$DAE"

# --- Report -----------------------------------------------------------------
glb_size="$(du -h "$GLB" | cut -f1)"
dae_size="$(du -h "$DAE" | cut -f1)"
echo
info "Done. Generated:"
echo "    $GLB   ($glb_size)"
echo "    $DAE   ($dae_size)"
