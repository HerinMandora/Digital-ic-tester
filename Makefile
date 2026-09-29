################################################################################
# Digital IC Tester - STM32F446RE
# Plain command-line Makefile (arm-none-eabi-gcc), HAL-free.
#
# This is provided in addition to the STM32CubeIDE project files
# (.project/.cproject), which have also been updated to build without HAL.
# Use whichever workflow you prefer:
#
#   make            # build build/DigitalIC_Tester.elf (+ .hex/.bin)
#   make flash      # build then flash via st-flash (stlink-tools)
#   make clean
################################################################################

TARGET   := DigitalIC_Tester
BUILDDIR := build

PREFIX   := arm-none-eabi-
CC       := $(PREFIX)gcc
AS       := $(PREFIX)gcc
OBJCOPY  := $(PREFIX)objcopy
SIZE     := $(PREFIX)size

CORE_INC := Core/Inc
CMSIS_DEV_INC := Drivers/CMSIS/Device/ST/STM32F4xx/Include
CMSIS_INC := Drivers/CMSIS/Include

INCLUDES := -I$(CORE_INC) -I$(CMSIS_DEV_INC) -I$(CMSIS_INC)

DEFINES := -DSTM32F446xx

MCU_FLAGS := -mcpu=cortex-m4 -mthumb -mfpu=fpv4-sp-d16 -mfloat-abi=hard

CFLAGS  := $(MCU_FLAGS) -std=gnu11 -O0 -g3 $(DEFINES) $(INCLUDES) \
           -ffunction-sections -fdata-sections -Wall \
           --specs=nano.specs -MMD -MP

ASFLAGS := $(MCU_FLAGS) -g3 -x assembler-with-cpp --specs=nano.specs -MMD -MP

LDSCRIPT := STM32F446RETX_FLASH.ld
LDFLAGS  := $(MCU_FLAGS) -T$(LDSCRIPT) --specs=nosys.specs \
            -Wl,-Map=$(BUILDDIR)/$(TARGET).map -Wl,--gc-sections -static \
            --specs=nano.specs -Wl,--start-group -lc -lm -Wl,--end-group

# Note: no HAL sources here - only CMSIS device/startup, the C peripheral
# glue (main/oled/i2c1_reg/it/system) and the ARM Thumb assembly tester.
C_SRCS := Core/Src/main.c \
          Core/Src/oled.c \
          Core/Src/i2c1_reg.c \
          Core/Src/stm32f4xx_it.c \
          Core/Src/system_stm32f4xx.c

S_SRCS := Core/Startup/startup_stm32f446xx.s \
          Core/Src/ic_tester.s \
          Core/Src/and.s \
          Core/Src/nand.s \
          Core/Src/nor.s \
          Core/Src/not.s \
          Core/Src/or.s \
          Core/Src/xor.s

C_OBJS := $(patsubst %.c,$(BUILDDIR)/%.o,$(C_SRCS))
S_OBJS := $(patsubst %.s,$(BUILDDIR)/%.o,$(S_SRCS))
OBJS   := $(C_OBJS) $(S_OBJS)
DEPS   := $(OBJS:.o=.d)

.PHONY: all clean flash size

all: $(BUILDDIR)/$(TARGET).elf $(BUILDDIR)/$(TARGET).hex $(BUILDDIR)/$(TARGET).bin size

$(BUILDDIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILDDIR)/%.o: %.s
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -c $< -o $@

$(BUILDDIR)/$(TARGET).elf: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@

$(BUILDDIR)/$(TARGET).hex: $(BUILDDIR)/$(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

$(BUILDDIR)/$(TARGET).bin: $(BUILDDIR)/$(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(BUILDDIR)/$(TARGET).elf
	$(SIZE) $<

flash: $(BUILDDIR)/$(TARGET).bin
	st-flash write $< 0x8000000

clean:
	rm -rf $(BUILDDIR)

-include $(DEPS)
