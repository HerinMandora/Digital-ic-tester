DIGITAL IC TESTER - COMBINED PROJECT (REGISTER-LEVEL / HAL-FREE BUILD)

This project keeps the Claude modular ARM-Assembly tester engine, with the
original CubeIDE workspace settings. The C peripheral layer (GPIO, I2C1,
SysTick/delay, clock config) no longer uses STM32 HAL: it has been converted
to direct STM32F446RE register programming (RCC/GPIO/I2C1/SysTick), using
only the CMSIS/device headers under Drivers/CMSIS. The
Drivers/STM32F4xx_HAL_Driver folder has been removed - it is no longer part
of this project and is not linked into the firmware.

All Assembly (.s) files, IC detection/test logic, truth tables, gate
mappings, pin mappings, ZIF socket mappings, menu logic, OLED
display/behavior, button logic, PASS/FAIL logic, and buzzer/LED logic are
unchanged from the original project.

STM32CubeIDE:
1. Extract this ZIP.
2. File -> Import -> General -> Existing Projects into Workspace.
3. Select the extracted DigitalIC_Tester folder (the folder containing .project).
4. Finish.
5. Do NOT regenerate code from the .ioc yet (doing so would restore HAL code).
6. Project -> Clean Project.
7. Project -> Build Project.
8. Connect Nucleo-F446RE via ST-LINK USB.
9. Run/Debug the project.

Command line (no IDE required):
1. Install the arm-none-eabi-gcc toolchain (e.g. `apt install gcc-arm-none-eabi`).
2. From this folder (the one containing this README and the Makefile), run:
       make
   This builds build/DigitalIC_Tester.elf/.hex/.bin using only CMSIS headers
   - no HAL sources are compiled or linked.
3. Flash with your tool of choice, e.g.:
       st-flash write build/DigitalIC_Tester.bin 0x8000000
   or `make flash` if you have st-flash (stlink-tools) installed.

Hardware mapping is the existing project mapping:
PA0-PA11 -> ZIF signal pins 1-6,8-13; ZIF7 GND; ZIF14 3.3V.
PB8/PB9 -> OLED I2C1 SCL/SDA.
PC0/PC1/PC2 -> UP/DOWN/OK.
PC3/PC4/PC5 -> PASS/FAIL/BUZZER.

Important: do not manually delete or rename the separate .s files. The project source path includes Core, so ic_tester.s plus nand/nor/not/and/or/xor.s are part of the build.
