# Cyber Ægg

## Introduction

## Functionality

### Display

### Manual input

Because the Cyber Ægg badge is inspired by the 90's Tamagotchi egg shaped game, the buttons are named the same.

| button name | function                          |
| ----------- | --------------------------------- |
| Select      | Navigate through the menu options |
| Execute     | Start the option under the cursor |
| Cancel      | Cancel current operation          |

In order to make nativation a bit more convenient, the select button has been upgraded to a joystick + button.

### Bluetooth

The Bluetooth implementation on this board is provided by the NRF52840 MCU.
Texas instruments has released a design for a 2.4GHz antenna, the antenna is provided as a Footprint included with Kicad 9.0.

#### BlueTooth Antenna

Bluetooth is using 2.4GHz, and a PCB antenna suitable for this frequency band is integrated into the PCB.
The design used is available in KiCAD 9 in the standard library and is originally from Texas instruments.

The documentation for the antenna can be found here : [swra228.pdf](https://www.ti.com/lit/an/swra228c/swra228c.pdf)

### LoRa

LoRa is provided by a separate SX1262 IC, with a tuning circuit as specified by the datasheet.

The datasheet that specifies the layout/balun/matching curcuit for the sx1262 is named an1200.54 and can be found at [this page](https://www.semtech.com/products/wireless-rf/lora-connect/sx1261)

#### Lora Antenna

The LoRa antenna is also a Texas instruments design, the specifications can be found here [swra416](https://www.ti.com/lit/an/swra416/swra416.pdf)

### NFC

### QWIIC

## Pinout

| Ball (aQFN73) | nRF pin      | Pin type(s)              | Project net         | Project function                                         |
| :------------ | :----------- | :----------------------- | :------------------ | :------------------------------------------------------- |
| A12           | P0.02 AIN0   | Digital I/O Analog input | P0.06/BLUE          | LED blue (GPIO output)                                   |
| B13           | P0.03 AIN1   | Digital I/O Analog input | P1.14_LORA_MISO     | LoRa (SX1262) SPI MISO (GPIO input)                      |
| J1            | P0.04 AIN2   | Digital I/O Analog input | P0.04_LORA_RF_SW1   | LoRa RF switch control SW1 (GPIO output)                 |
| L1            | P0.06        | Digital I/O              | BTN_CANCEL          | Button: cancel (GPIO input)                              |
| L24           | P0.07        | Digital I/O              | P0.07_READ_BAT      | Battery read enable: pull low to read VBAT (GPIO output) |
| N1            | P0.08        | Digital I/O              | P0.07_DSP_SCK       | Display (DSP) SPI SCK (GPIO output)                      |
| L24           | P0.09 NFC1   | NFC input                | NFC1                | NFC antenna connection                                   |
| J24           | P0.10 NFC2   | NFC input                | NFC2                | NFC antenna connection                                   |
| U1            | P0.11        | Digital I/O              | P0.11_DSP_BUSY      | Display busy/IRQ (GPIO input)                            |
| V23           | P0.12        | Digital I/O              | P0.12_DSP_RESET     | Display reset (GPIO output)                              |
| AC11          | P0.17        | Digital I/O              | P0.17_PS_SYNC       | PS_SYNC (GPIO, sync/control)                             |
| G1            | P0.26        | Digital I/O              | P0.26_BTN_EXECUTE   | Button: execute (GPIO input)                             |
| H2            | P0.27        | Digital I/O              | P0.27_DSP_MOSI      | Display (DSP) SPI MOSI (GPIO output)                     |
| B11           | P0.28 AIN4   | Digital I/O Analog input | P0.28_LORA_BUSY     | LoRa (SX1262) BUSY (GPIO input)                          |
| A10           | P0.29 AIN5   | Digital I/O Analog input | P0.29_LORA_DIO1     | LoRa (SX1262) DIO1 IRQ (GPIO input)                      |
| B9            | P0.30 AIN6   | Digital I/O Analog input | P0.30_LORA_RST      | LoRa (SX1262) reset (GPIO output)                        |
| A8            | P0.31 AIN7   | Digital I/O Analog input | P0.31/VBAT          | Battery voltage sense (ADC input)                        |
| Y23           | P1.01        | Digital I/O              | P1.01_BTN_JOY_RIGHT | Joystick button: right (GPIO input)                      |
| W24           | P1.02        | Digital I/O              | P1.02_BTN_JOY_FIRE  | Joystick button: fire (GPIO input)                       |
| V23           | P1.03        | Digital I/O              | P1.03_BTN_JOY_DOWN  | Joystick button: down (GPIO input)                       |
| U24           | P1.04        | Digital I/O              | P1.04_BTN_JOY_UP    | Joystick button: up (GPIO input)                         |
| T23           | P1.05        | Digital I/O              | P1.05_BTN_JOY_LEFT  | Joystick button: left (GPIO input)                       |
| P23           | P1.07        | Digital I/O              | P1.07/RED           | LED red (GPIO output)                                    |
| P2            | P1.08        | Digital I/O              | P1.08_CHRG          | Charge status: low when charging (GPIO input)            |
| R1            | P1.09        | Digital I/O              | P1.09_DSP_CSN       | Display (DSP) SPI CSN (GPIO output)                      |
| A20           | P1.10        | Digital I/O              | P1.10_QWIIC_SDA     | Qwiic I²C SDA (open-drain)                               |
| B19           | P1.11        | Digital I/O              | P1.11_QWIIC_SCL     | Qwiic I²C SCL (open-drain)                               |
| B17           | P1.12        | Digital I/O              | P1.12_LORA_SPI_NSS  | LoRa (SX1262) SPI NSS/CS (GPIO output)                   |
| A16           | P1.13        | Digital I/O              | P1.13_LORA_SCK      | LoRa (SX1262) SPI SCK (GPIO output)                      |
| B15           | P1.14        | Digital I/O              | P1.14_LORA_MOSI     | LoRa (SX1262) SPI MOSI (GPIO output)                     |
| A14           | P1.15        | Digital I/O              | P1.15/GREEN         | LED green (GPIO output)                                  |
| AC13          | P0.18 nRESET | Digital I/O              | MCU_RESET           | nRESET (active low)                                      |
| AD6           | D+           | USB                      | USB_D+              | USB data +                                               |
| AD4           | D-           | USB                      | USB_D-              | USB data -                                               |
