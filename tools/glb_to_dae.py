#!/usr/bin/env python3
"""Convert a KiCad-exported GLB into a Collada (.dae) file, inside Blender.

This script is meant to be run by Blender's bundled Python, e.g.:

    blender --background --factory-startup \
        --python tools/glb_to_dae.py -- \
        --glb in.glb --dae out.dae --pycollada /path/to/site-packages

(It is not executable on purpose: it is only ever invoked via
``blender --python``, never directly, so it carries no exec bit.)

Why this exists
---------------
KiCad has no native DAE/Collada export target, and Blender 5.0 removed its
own Collada exporter (``bpy.ops.wm.collada_export`` is now a non-functional
stub).  So we let KiCad produce a GLB, import that here, and write the DAE
ourselves with ``pycollada`` (a pure-Python library, so it loads happily on
top of Blender's bundled numpy without any compiled extensions).

The actual GLB->DAE export logic is byte-for-byte the verified pipeline; the
only thing parameterised here is where the inputs/outputs live and where the
pycollada package can be found, all passed in via argv after ``--``.
"""

import argparse
import sys


def parse_args(argv):
    """Parse the args that appear AFTER the Blender ``--`` separator.

    Blender swallows everything before ``--`` for itself; anything after it is
    ours.  If ``--`` is absent (e.g. the script is run outside Blender) we just
    parse the whole argv tail.
    """
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    p = argparse.ArgumentParser(
        prog="glb_to_dae.py",
        description="Convert a GLB to Collada (.dae) using Blender + pycollada.",
    )
    p.add_argument("--glb", required=True, help="Input .glb path")
    p.add_argument("--dae", required=True, help="Output .dae path")
    p.add_argument(
        "--pycollada",
        required=True,
        help="site-packages dir of the venv that has pycollada installed",
    )
    return p.parse_args(argv)


def main():
    args = parse_args(sys.argv)

    # Append (do NOT prepend) the venv's site-packages so Blender's own bundled
    # numpy / packages always take precedence and are never shadowed by anything
    # in the venv.  pycollada is pure Python, so this is all it needs.
    sys.path.append(args.pycollada)

    try:
        import bpy
    except ImportError:
        sys.exit(
            "ERROR: 'bpy' not importable. Run this with Blender:\n"
            "  blender --background --factory-startup --python tools/glb_to_dae.py -- ..."
        )

    try:
        import numpy as np
        import collada
        from collada import (
            Collada,
            source,
            geometry as cgeom,
            material as cmat,
            scene as cscene,
        )
    except ImportError as exc:
        sys.exit(
            "ERROR: failed to import pycollada/numpy from the provided "
            "site-packages dir (%s): %s\n"
            "Make sure tools/export-3d.sh provisioned the venv correctly."
            % (args.pycollada, exc)
        )

    # --- Import the GLB into a clean, factory-default Blender scene ----------
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # The glTF importer is a bundled add-on; it is enabled by default under
    # --factory-startup (verified on Blender 5.0), but enable it defensively so
    # this also works on Blender builds/versions where it is not pre-enabled.
    # enable() is idempotent, so this is a no-op when it is already on.
    try:
        import addon_utils
        addon_utils.enable("io_scene_gltf2", default_set=False)
    except Exception:  # noqa: BLE001 - if this fails the import below reports it
        pass
    try:
        bpy.ops.import_scene.gltf(filepath=args.glb)
    except Exception as exc:  # noqa: BLE001 - surface any importer failure clearly
        sys.exit("ERROR: glTF import of %r failed: %s" % (args.glb, exc))

    mesh_objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not mesh_objs:
        sys.exit("ERROR: no mesh objects found after importing %r" % args.glb)

    # --- Build the Collada document -----------------------------------------
    mesh = Collada()
    mesh.assetInfo.upaxis = collada.asset.UP_AXIS.Z_UP

    def base_color(blmat):
        """Best-effort RGBA for a Blender material (Principled BSDF, else diffuse)."""
        if blmat and blmat.use_nodes:
            for n in blmat.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    c = n.inputs["Base Color"].default_value
                    return (c[0], c[1], c[2], c[3])
        if blmat:
            c = blmat.diffuse_color
            return (c[0], c[1], c[2], c[3])
        return (0.75, 0.75, 0.75, 1.0)

    mat_index = {}

    def get_mat(blmat):
        """Return (collada material, symbol) for a Blender material, creating once."""
        key = blmat.name if blmat else "__default__"
        if key in mat_index:
            return mat_index[key]
        r, g, b, a = base_color(blmat)
        sym = "mat%d" % len(mat_index)
        eff = cmat.Effect(
            "eff_%s" % sym,
            [],
            "phong",
            diffuse=(r, g, b),
            specular=(0.1, 0.1, 0.1),
            shininess=16.0,
            double_sided=True,
        )
        cm = cmat.Material("material_%s" % sym, key, eff)
        mesh.effects.append(eff)
        mesh.materials.append(cm)
        mat_index[key] = (cm, sym)
        return mat_index[key]

    depsgraph = bpy.context.evaluated_depsgraph_get()
    nodes = []
    gi = 0
    for obj in mesh_objs:
        ev = obj.evaluated_get(depsgraph)
        me = ev.to_mesh()
        if len(me.vertices) == 0:
            ev.to_mesh_clear()
            continue
        me.calc_loop_triangles()

        verts = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("co", verts)
        norms = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("normal", norms)

        gid = "geom%d" % gi
        src_v = source.FloatSource(gid + "-v", verts, ("X", "Y", "Z"))
        src_n = source.FloatSource(gid + "-n", norms, ("X", "Y", "Z"))
        geom = cgeom.Geometry(mesh, gid, obj.name, [src_v, src_n])

        slot_mats = (
            [s.material for s in obj.material_slots] if obj.material_slots else [None]
        )
        by_slot = {}
        for tri in me.loop_triangles:
            by_slot.setdefault(tri.material_index, []).append(tri.vertices)

        matnodes = []
        for slot, tris in by_slot.items():
            blmat = slot_mats[slot] if slot < len(slot_mats) else None
            cm, sym = get_mat(blmat)
            idx = np.array(tris, dtype=np.int64).reshape(-1, 1)
            indices = np.hstack([idx, idx]).reshape(-1)
            il = source.InputList()
            il.addInput(0, "VERTEX", "#" + gid + "-v")
            il.addInput(1, "NORMAL", "#" + gid + "-n")
            ts = geom.createTriangleSet(indices, il, sym)
            geom.primitives.append(ts)
            matnodes.append(cscene.MaterialNode(sym, cm, inputs=[]))

        mesh.geometries.append(geom)

        M = obj.matrix_world
        flat = [M[r][c] for r in range(4) for c in range(4)]
        tf = cscene.MatrixTransform(np.array(flat, dtype=np.float32))
        geomnode = cscene.GeometryNode(geom, matnodes)
        nodes.append(
            cscene.Node(
                "node_%d_%s" % (gi, obj.name),
                children=[geomnode],
                transforms=[tf],
            )
        )
        ev.to_mesh_clear()
        gi += 1

    myscene = cscene.Scene("scene", nodes)
    mesh.scenes.append(myscene)
    mesh.scene = myscene
    mesh.write(args.dae)

    # Final line the orchestrator greps for to confirm success.
    print("WROTE_DAE geometries=%d materials=%d" % (gi, len(mat_index)))


if __name__ == "__main__":
    main()
