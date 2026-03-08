# Cyber Ægg

<img src="./imgs/badge-front.png" width="400" height="500">
<img src="./imgs/badge-back.png" width="400" height="500">

## Introduction

The badge is intended to be a low power LoRa device, that should be able to at least run for the whole duration of the BornHack camp on one battery charge (One week).
At least that is one of our design goals, lot's of hours chasing down power use in both the hardware and the software are still ahead of us, when measurements have been done I'll share them in the Badge.Team Discord.

At this moment the design is at prototype stage one, and is not fully developed.

For example the NFC, LoRa and Bluetooth circuits still have IPEX connectors integrated to make tuning the circuits easier.

Also certain aspects, especially the on PCB antennas should at least work, but how well, we do not know yet.

Long story short, consider this design BETA, and do not order your own boards yet. (Or if you do, you are on your own.)

## Functionality

The is designed with MeshCore in mind, to connect up to a smart phone using Bluetooth and connect to the greater MeshCore network using the on PCB LoRa circuit.

To provide some extra camp fun, we hope the communication technologies combined with the NFC tag functionality will result in some really cool location based games that will run on the badge.
For now the game ideas being worked out, and it's up to the game team of BornHack what they share.

### Display

For now the e-paper display is designed in from SWI, model number: SG0154BNS800F35HP

The display has a 1.54Inch size with 152x152 pixels.

These displays have the [SSD1680Z8](https://cdn-learn.adafruit.com/assets/assets/000/097/631/original/SSD1680_Datasheet.pdf?1607625960) controller controller IC.

### Manual input

Because the Cyber Ægg badge is inspired by the 90's Tamagotchi egg shaped game, the buttons are named the same.

| button name | function                          |
| ----------- | --------------------------------- |
| Select      | Navigate through the menu options |
| Execute     | Start the option under the cursor |
| Cancel      | Cancel current operation          |

In order to make navigation a more intuitive, the select button has been upgraded to a joystick + button.

### Bluetooth

The Bluetooth implementation on this board is provided by the NRF52840 MCU.
Texas instruments has released a design for a 2.4GHz antenna, the antenna is provided as a Footprint included with Kicad 9.0.

#### BlueTooth Antenna

Bluetooth is using 2.4GHz, and a PCB antenna suitable for this frequency band is integrated into the PCB.
The design used is available in KiCAD 9 in the standard library and is originally by Texas instruments.

The documentation for the antenna can be found here : [swra228.pdf](https://www.ti.com/lit/an/swra228c/swra228c.pdf)

### LoRa

LoRa is provided by a separate SX1262 IC, with a tuning circuit as specified by the data sheet and implementation notes provided by Semtech.

The document that specifies the layout/balun/matching circuit for the sx1262 is named *"AN1200.54"* and can be found at [this page](https://www.semtech.com/products/wireless-rf/lora-connect/sx1261)

#### Lora Antenna

The LoRa antenna is also a Texas instruments design, the specifications can be found here [swra416](https://www.ti.com/lit/an/swra416/swra416.pdf)

### NFC

NRF is again provided by a PHY in the NRF82840 core, which drives a resonant circuit consisting of 2 (eventually) capacitors, and a CPB coil.

The NRF52840 only supports TAG functionality no reader functionality.

The coil in this design has a inductance of around 2.8uH, which together with the capacitors and the paracytics (both capacitance and inductance) should form a tank circuit that matches the 13.56MHz for interacting with an NRC reader.

### QWIIC

The QWIIC port is a standardized connector utilizing I2C, it's included on the badge because many boards have been produced for this [standard](https://www.sparkfun.com/qwiic) setup by Sparkfun.

Pins used for the SDA and SCL pins are listed below.

Two 10k pull up resistors are provided on the board, when the capacitance is too high on the I2C lines, the internal pull-ups can also be enabled (the provide an extra 10k pull-up resistance).

## Pinout

| Ball (aQFN73) | nRF pin      | Pin type(s)              | Project net  | Project function                                         |
| :------------ | :----------- | :----------------------- | :----------- | :------------------------------------------------------- |
| A12           | P0.02 AIN0   | Digital I/O Analog input | LED_BLUE     | LED blue (active low, GPIO output)                       |
| B13           | P0.03 AIN1   | Digital I/O Analog input | LORA_MISO    | LoRa (SX1262) SPI MISO (GPIO input)                      |
| J1            | P0.04 AIN2   | Digital I/O Analog input | LORA_RF_SW   | LoRa RF switch control (GPIO output)                     |
| K2            | P0.05 AIN3   | Digital I/O Analog input | BAT_CHARGE   | Charge status: low when charging (GPIO input)            |
| L1            | P0.06        | Digital I/O              | BTN_CANCEL   | Button: cancel (active low, GPIO input)                  |
| M2            | P0.07        | Digital I/O              | BAT_V_READ   | Battery read enable: pull low to read VBAT (GPIO output) |
| N1            | P0.08        | Digital I/O              | EPD_SCK      | EPD (SDD1680) SPI SCK (GPIO output)                      |
| M24           | P0.09 NFC1   | NFC I/O                  | NFC1         | NFC antenna connection                                   |
| L24           | P0.10 NFC2   | NFC I/O                  | NFC2         | NFC antenna connection                                   |
| U1            | P0.11        | Digital I/O              | EPD_RESET    | EPD (SDD1680) reset (GPIO output)                        |
| V2            | P0.12        | Digital I/O              | EPD_DC       | EPD (SDD1680) data/command (GPIO output)                 |
| W1            | P0.13        | Digital I/O              | BUZZER       | Buzzer square wave output (PWM/GPIO output)              |
| X2            | P0.14        | Digital I/O              | EPD_BUSY     | EPD (SDD1680) busy signal (GPIO input)                   |
| AC12          | P0.15        | Digital I/O              | GPIO_1       | General purpose I/O 1                                    |
| AB13          | P0.16        | Digital I/O              | GPIO_2       | General purpose I/O 2                                    |
| AC11          | P0.17        | Digital O                | PS_SYNC      | Power mode buck/boost hi/low power mode                  |
| AC13          | P0.18 nRESET | Digital O                | MCU_RESET    | nRESET (active low)                                      |
| AB11          | P0.19        | Digital I/O              | GPIO_3       | General purpose I/O 3                                    |
| AC9           | P0.20        | Digital I/O (QSPI)       | FLASH_IO0    | QSPI Flash IO0/D0                                        |
| AB9           | P0.21        | Digital I/O (QSPI)       | FLASH_SCK    | QSPI Flash clock (GPIO output)                           |
| AC7           | P0.22        | Digital I/O (QSPI)       | FLASH_IO2    | QSPI Flash IO2/D2                                        |
| AB7           | P0.23        | Digital I/O (QSPI)       | FLASH_IO3    | QSPI Flash IO3/D3                                        |
| AC5           | P0.24        | Digital I/O (QSPI)       | FLASH_IO1    | QSPI Flash IO1/D1                                        |
| AB5           | P0.25        | Digital I/O (QSPI)       | FLASH_CSN    | QSPI Flash chip select (active low, GPIO output)         |
| G1            | P0.26        | Digital I/O              | BTN_EXECUTE  | Button: execute (active low, GPIO input)                 |
| H2            | P0.27        | Digital I/O              | EPD_MOSI     | EPD (SDD1680) SPI MOSI (GPIO output)                     |
| B11           | P0.28 AIN4   | Digital I/O Analog input | LORA_BUSY    | LoRa (SX1262) busy (GPIO input)                          |
| A10           | P0.29 AIN5   | Digital I/O Analog input | LORA_DIO1    | LoRa (SX1262) DIO1 IRQ (GPIO input)                      |
| B9            | P0.30 AIN6   | Digital I/O Analog input | LORA_RST     | LoRa (SX1262) reset (GPIO output)                        |
| A8            | P0.31 AIN7   | Digital I/O Analog input | VBAT_V       | Battery voltage sense (ADC input)                        |
| AD22          | P1.00        | SWD                      | P1.00_SWO    | SWO pin SWD NRF52840                                     |
| Y23           | P1.01        | Digital I/O              | JOY_RIGHT    | Joystick: right (active low, GPIO input)                 |
| W24           | P1.02        | Digital I/O              | JOY_FIRE     | Joystick: fire (active low, GPIO input)                  |
| V24           | P1.03        | Digital I/O              | JOY_DOWN     | Joystick: down (active low, GPIO input)                  |
| U24           | P1.04        | Digital I/O              | JOY_UP       | Joystick: up (active low, GPIO input)                    |
| T23           | P1.05        | Digital I/O              | JOY_LEFT     | Joystick: left (active low, GPIO input)                  |
| P23           | P1.07        | Digital I/O              | LED_RED      | LED red (active low, GPIO output)                        |
| P2            | P1.08        | Digital I/O              | GPIO_4       | General purpose I/O 4                                    |
| R1            | P1.09        | Digital I/O              | EPD_CSN      | EPD (SDD1680) SPI CSN (active low, GPIO output)          |
| A20           | P1.10        | Digital I/O              | QWIIC_SDA    | Qwiic I²C SDA (open-drain)                               |
| B19           | P1.11        | Digital I/O              | QWIIC_SCL    | Qwiic I²C SCL (open-drain)                               |
| B17           | P1.12        | Digital I/O              | LORA_NSS     | LoRa (SX1262) SPI NSS/CS (active low, GPIO output)       |
| A16           | P1.13        | Digital I/O              | LORA_SCK     | LoRa (SX1262) SPI SCK (GPIO output)                      |
| B15           | P1.14        | Digital I/O              | LORA_MOSI    | LoRa (SX1262) SPI MOSI (GPIO output)                     |
| A14           | P1.15        | Digital I/O              | LED_GREEN    | LED green (active low, GPIO output)                      |
| AD6           | D+           | USB                      | USB_D+       | USB data +                                               |
| AD4           | D-           | USB                      | USB_D-       | USB data -                                               |
