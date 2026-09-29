# Auto-Detecting Digital IC Tester Using STM32F446RE

An STM32F446RE-based digital IC tester that automatically identifies common 74HC-series logic ICs by applying their truth-table input combinations and checking the resulting outputs.

## Supported ICs

| IC | Logic |
|---|---|
| 74HC00 | NAND |
| 74HC02 | NOR |
| 74HC04 | NOT |
| 74HC08 | AND |
| 74HC32 | OR |
| 74HC86 | XOR |

## Features

- Automatic IC detection
- 14-pin ZIF socket
- Truth-table based testing
- STM32F446RE Nucleo-64
- Register-level GPIO control
- ARM Assembly routines for core testing
- 0.96" SSD1306 I²C OLED
- Push-button menu
- PASS/FAIL LEDs
- Buzzer indication
- Floating-output handling using GPIO pull-downs
- Repeated output sampling for improved reliability

## Hardware

- STM32F446RE Nucleo-64
- 14-pin ZIF socket
- 0.96" SSD1306 OLED
- Push buttons
- PASS LED
- FAIL LED
- Buzzer
- 1 kΩ series resistors
- 100 nF decoupling capacitor

## Pin Configuration

### ZIF Socket

| ZIF Pin | STM32 Pin |
|---:|---|
| 1 | PA0 |
| 2 | PA1 |
| 3 | PA2 |
| 4 | PA3 |
| 5 | PA4 |
| 6 | PA5 |
| 7 | GND |
| 8 | PA6 |
| 9 | PA7 |
| 10 | PA8 |
| 11 | PA9 |
| 12 | PA10 |
| 13 | PA11 |
| 14 | 3.3V |

### Controls

| Function | STM32 Pin |
|---|---|
| UP | PC0 |
| DOWN | PC1 |
| OK | PC2 |
| PASS LED | PC3 |
| FAIL LED | PC4 |
| Buzzer | PC5 |

### OLED

| OLED | STM32 |
|---|---|
| SCL | PB8 |
| SDA | PB9 |

## How It Works

The tester places the ZIF socket pins into safe states and then tests each supported IC candidate.

For two-input gates, all four combinations are applied:

```text
00
01
10
11
```

The output is sampled and compared with the expected truth table. For the NOT gate, both input states are tested.

The automatic detection routine compares the observed behavior against the supported ICs and selects the candidate with the highest valid match score. A strict majority of the expected test combinations is required before a result is accepted.

The output being tested is given a weak pull-down while sampling. This helps prevent an empty socket or floating output from producing a false detection. Outputs are also sampled more than once to detect unstable readings.

## Truth Table Signatures

| Logic | Signature |
|---|---|
| NAND | `1110` |
| NOR | `1000` |
| AND | `0001` |
| OR | `0111` |
| XOR | `0110` |
| NOT | `10` |

## Software

The firmware is written using C and ARM Assembly.

### C

Used for:

- System initialization
- Clock configuration
- SysTick
- OLED interface
- I²C configuration
- Application startup

### ARM Assembly

Used for core tester operations including:

- GPIO configuration
- GPIO read/write
- Safe GPIO states
- Gate testing
- IC detection
- Button handling
- LED and buzzer control

The project uses direct STM32 register access for GPIO and I²C rather than relying on the STM32 HAL peripheral drivers.

## Project Structure

```text
Digital_ic_Tester/
├── Core/
│   ├── Inc/
│   ├── Src/
│   └── Startup/
├── Drivers/
│   └── CMSIS/
├── Hardware/
├── Documentation/
├── README.md
└── .gitignore
```

## Development Environment

- STM32CubeIDE
- STM32F446RE
- ARM GNU Toolchain
- C
- ARM Assembly
- CMSIS
- SSD1306 OLED

## Build and Flash

1. Open the project in STM32CubeIDE.
2. Build the project.
3. Connect the STM32 Nucleo board.
4. Flash the firmware.
5. Insert a supported IC into the ZIF socket.
6. Select **AUTO DETECT** from the menu.

## Hardware Notes

- The supported ICs are operated at 3.3V.
- Check IC orientation before inserting it into the ZIF socket.
- Ensure the supply and ground connections are correct.
- Use the recommended series resistors between the STM32 GPIO pins and the ZIF socket.

## Future Improvements

- Support for additional logic ICs
- Faulty-gate identification
- Per-gate diagnostic results
- USB/PC result logging
- Larger IC database
- Dedicated PCB
- Improved hardware protection


## Demo

▶️ Watch the Digital IC Tester Demo : https://github.com/HerinMandora/Digital-ic-tester/blob/main/Digital_IC_Tester.mp4


## License

This project is intended for educational and experimental use.
