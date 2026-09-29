/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   Auto-Detecting Digital IC Tester - STM32 Nucleo-F446RE
  ******************************************************************************
  */
/* USER CODE END Header */

#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

#include "stm32f4xx.h"

#define GPIO_PIN_0   ((uint16_t)0x0001U)
#define GPIO_PIN_1   ((uint16_t)0x0002U)
#define GPIO_PIN_2   ((uint16_t)0x0004U)
#define GPIO_PIN_3   ((uint16_t)0x0008U)
#define GPIO_PIN_4   ((uint16_t)0x0010U)
#define GPIO_PIN_5   ((uint16_t)0x0020U)
#define GPIO_PIN_6   ((uint16_t)0x0040U)
#define GPIO_PIN_7   ((uint16_t)0x0080U)
#define GPIO_PIN_8   ((uint16_t)0x0100U)
#define GPIO_PIN_9   ((uint16_t)0x0200U)
#define GPIO_PIN_10  ((uint16_t)0x0400U)
#define GPIO_PIN_11  ((uint16_t)0x0800U)

void Error_Handler(void);
void HAL_Delay(uint32_t ms);

/* Button pins (input, pull-up, active LOW) */
#define BTN_UP_Pin        GPIO_PIN_0
#define BTN_UP_GPIO_Port  GPIOC
#define BTN_DOWN_Pin      GPIO_PIN_1
#define BTN_DOWN_GPIO_Port GPIOC
#define BTN_OK_Pin        GPIO_PIN_2
#define BTN_OK_GPIO_Port  GPIOC

/* Indicator pins */
#define LED_PASS_Pin       GPIO_PIN_3
#define LED_PASS_GPIO_Port GPIOC
#define LED_FAIL_Pin       GPIO_PIN_4
#define LED_FAIL_GPIO_Port GPIOC
#define BUZZER_Pin         GPIO_PIN_5
#define BUZZER_GPIO_Port   GPIOC

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
