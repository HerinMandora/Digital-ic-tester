################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
S_SRCS += \
../Core/Src/and.s \
../Core/Src/ic_tester.s \
../Core/Src/nand.s \
../Core/Src/nor.s \
../Core/Src/not.s \
../Core/Src/or.s \
../Core/Src/xor.s 

C_SRCS += \
../Core/Src/i2c1_reg.c \
../Core/Src/main.c \
../Core/Src/oled.c \
../Core/Src/stm32f4xx_it.c \
../Core/Src/system_stm32f4xx.c 

OBJS += \
./Core/Src/and.o \
./Core/Src/i2c1_reg.o \
./Core/Src/ic_tester.o \
./Core/Src/main.o \
./Core/Src/nand.o \
./Core/Src/nor.o \
./Core/Src/not.o \
./Core/Src/oled.o \
./Core/Src/or.o \
./Core/Src/stm32f4xx_it.o \
./Core/Src/system_stm32f4xx.o \
./Core/Src/xor.o 

S_DEPS += \
./Core/Src/and.d \
./Core/Src/ic_tester.d \
./Core/Src/nand.d \
./Core/Src/nor.d \
./Core/Src/not.d \
./Core/Src/or.d \
./Core/Src/xor.d 

C_DEPS += \
./Core/Src/i2c1_reg.d \
./Core/Src/main.d \
./Core/Src/oled.d \
./Core/Src/stm32f4xx_it.d \
./Core/Src/system_stm32f4xx.d 


# Each subdirectory must supply rules for building sources it contributes
Core/Src/%.o: ../Core/Src/%.s Core/Src/subdir.mk
	arm-none-eabi-gcc -mcpu=cortex-m4 -g3 -DDEBUG -c -x assembler-with-cpp -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"
Core/Src/%.o Core/Src/%.su Core/Src/%.cyclo: ../Core/Src/%.c Core/Src/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m4 -std=gnu11 -g3 -DDEBUG -DSTM32F446xx -c -I../Core/Inc -I../Drivers/CMSIS/Device/ST/STM32F4xx/Include -I../Drivers/CMSIS/Include -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-Core-2f-Src

clean-Core-2f-Src:
	-$(RM) ./Core/Src/and.d ./Core/Src/and.o ./Core/Src/i2c1_reg.cyclo ./Core/Src/i2c1_reg.d ./Core/Src/i2c1_reg.o ./Core/Src/i2c1_reg.su ./Core/Src/ic_tester.d ./Core/Src/ic_tester.o ./Core/Src/main.cyclo ./Core/Src/main.d ./Core/Src/main.o ./Core/Src/main.su ./Core/Src/nand.d ./Core/Src/nand.o ./Core/Src/nor.d ./Core/Src/nor.o ./Core/Src/not.d ./Core/Src/not.o ./Core/Src/oled.cyclo ./Core/Src/oled.d ./Core/Src/oled.o ./Core/Src/oled.su ./Core/Src/or.d ./Core/Src/or.o ./Core/Src/stm32f4xx_it.cyclo ./Core/Src/stm32f4xx_it.d ./Core/Src/stm32f4xx_it.o ./Core/Src/stm32f4xx_it.su ./Core/Src/system_stm32f4xx.cyclo ./Core/Src/system_stm32f4xx.d ./Core/Src/system_stm32f4xx.o ./Core/Src/system_stm32f4xx.su ./Core/Src/xor.d ./Core/Src/xor.o

.PHONY: clean-Core-2f-Src

