/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Auto-Detecting Digital IC Tester - STM32 Nucleo-F446RE
  ******************************************************************************
  */

#include "main.h"
/* USER CODE BEGIN Includes */
#include "tester.h"
#include "i2c1_reg.h"
/* USER CODE END Includes */

static void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_I2C1_Init(void);

int main(void)
{
    SystemClock_Config();
    SystemCoreClockUpdate();
    SysTick_Config(SystemCoreClock / 1000U);

    MX_GPIO_Init();
    MX_I2C1_Init();

    /* USER CODE BEGIN 2 */
    Tester_Run();
    /* USER CODE END 2 */

    while (1)
    {
        /* USER CODE BEGIN WHILE */
        /* USER CODE END WHILE */
    }
}

/**
  * @brief System Clock Configuration
  *        HSI -> PLL: PLLM=16, PLLN=180, PLLP=/2, PLLQ=2
  *        SYSCLK=90MHz, HCLK=90MHz, APB1=45MHz, APB2=90MHz, Flash latency=2
  */
static void SystemClock_Config(void)
{
    RCC->APB1ENR |= RCC_APB1ENR_PWREN;
    PWR->CR = (PWR->CR & ~PWR_CR_VOS) | PWR_CR_VOS;
    RCC->CR |= RCC_CR_HSION;
    while ((RCC->CR & RCC_CR_HSIRDY) == 0U)
    {
    }

    /* Disable the PLL before reconfiguring it. */
    RCC->CR &= ~RCC_CR_PLLON;
    while ((RCC->CR & RCC_CR_PLLRDY) != 0U)
    {
    }

    /* PLLSRC = HSI, PLLM = 16, PLLN = 180, PLLP = /2, PLLQ = 2 */
    RCC->PLLCFGR = RCC_PLLCFGR_PLLSRC_HSI
                  | (16U  << RCC_PLLCFGR_PLLM_Pos)
                  | (180U << RCC_PLLCFGR_PLLN_Pos)
                  | (0U   << RCC_PLLCFGR_PLLP_Pos)   /* 00 = PLLP /2 */
                  | (2U   << RCC_PLLCFGR_PLLQ_Pos);

    RCC->CR |= RCC_CR_PLLON;
    while ((RCC->CR & RCC_CR_PLLRDY) == 0U)
    {
    }

    /* Flash latency = 2 wait states, required for 90MHz HCLK at VOS1. */
    FLASH->ACR = (FLASH->ACR & ~FLASH_ACR_LATENCY) | FLASH_ACR_LATENCY_2WS;
    while ((FLASH->ACR & FLASH_ACR_LATENCY) != FLASH_ACR_LATENCY_2WS)
    {
    }

    /* AHB = SYSCLK/1, APB1 = HCLK/2, APB2 = HCLK/1 - set the prescalers
     * BEFORE switching SYSCLK to the PLL. */
    RCC->CFGR = (RCC->CFGR & ~(RCC_CFGR_HPRE | RCC_CFGR_PPRE1 | RCC_CFGR_PPRE2))
              | RCC_CFGR_HPRE_DIV1 | RCC_CFGR_PPRE1_DIV2 | RCC_CFGR_PPRE2_DIV1;

    /* Switch SYSCLK source to the PLL and wait for the switch to complete. */
    RCC->CFGR = (RCC->CFGR & ~RCC_CFGR_SW) | RCC_CFGR_SW_PLL;
    while ((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_PLL)
    {
        /* Original code called Error_Handler() on a HAL_RCC_ClockConfig()
         * failure/timeout. */
    }
}

/**
  * @brief I2C1 Init - PB8=SCL, PB9=SDA, Fast mode 400kHz, duty cycle 2
  */
static void MX_I2C1_Init(void)
{
    I2C1_Init();
}

/**
  * @brief GPIO Init - matches DigitalIC_Tester.ioc exactly:
  *        PA0-PA11 : GPIO output, push-pull, no pull, initially LOW  (ZIF interface)
  *        PC0/1/2  : GPIO input, pull-up                             (UP/DOWN/OK buttons)
  *        PC3      : GPIO output, initially LOW                      (PASS LED)
  *        PC4      : GPIO output, initially LOW                      (FAIL LED)
  *        PC5      : GPIO output, initially LOW                      (BUZZER)
  */
static void MX_GPIO_Init(void)
{
    const uint16_t zif_pins  = GPIO_PIN_0 | GPIO_PIN_1 | GPIO_PIN_2 | GPIO_PIN_3
                              | GPIO_PIN_4 | GPIO_PIN_5 | GPIO_PIN_6 | GPIO_PIN_7
                              | GPIO_PIN_8 | GPIO_PIN_9 | GPIO_PIN_10 | GPIO_PIN_11;
    const uint16_t ind_pins  = LED_PASS_Pin | LED_FAIL_Pin | BUZZER_Pin;
    const uint16_t btn_pins  = BTN_UP_Pin | BTN_DOWN_Pin | BTN_OK_Pin;

    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOCEN | RCC_AHB1ENR_GPIOAEN;

    /* Ensure all outputs start LOW before configuring as outputs (BSRR
     * upper half-word = "reset" bits, same effect as
     * HAL_GPIO_WritePin(..., GPIO_PIN_RESET)). */
    GPIOA->BSRR = ((uint32_t)zif_pins) << 16;
    GPIOC->BSRR = ((uint32_t)ind_pins) << 16;

    /* --- PA0-PA11 : ZIF socket interface, output push-pull, no pull, high speed --- */
    for (uint32_t pin = 0U; pin <= 11U; pin++)
    {
        GPIOA->MODER   = (GPIOA->MODER   & ~(3U << (pin * 2U))) | (1U << (pin * 2U)); /* output */
        GPIOA->OTYPER  &= ~(1U << pin);                                               /* push-pull */
        GPIOA->OSPEEDR = (GPIOA->OSPEEDR & ~(3U << (pin * 2U))) | (2U << (pin * 2U)); /* high speed */
        GPIOA->PUPDR   &= ~(3U << (pin * 2U));                                        /* no pull */
    }

    /* --- PC0/1/2 : buttons, input, pull-up --- */
    for (uint32_t pin = 0U; pin <= 2U; pin++)
    {
        GPIOC->MODER &= ~(3U << (pin * 2U));                                      /* input */
        GPIOC->PUPDR  = (GPIOC->PUPDR & ~(3U << (pin * 2U))) | (1U << (pin * 2U)); /* pull-up */
    }
    (void)btn_pins; /* pin numbers used directly above; kept for readability */

    /* --- PC3/4/5 : PASS LED, FAIL LED, buzzer - output push-pull, low speed --- */
    for (uint32_t pin = 3U; pin <= 5U; pin++)
    {
        GPIOC->MODER   = (GPIOC->MODER   & ~(3U << (pin * 2U))) | (1U << (pin * 2U)); /* output */
        GPIOC->OTYPER  &= ~(1U << pin);                                               /* push-pull */
        GPIOC->OSPEEDR &= ~(3U << (pin * 2U));                                        /* low speed */
        GPIOC->PUPDR   &= ~(3U << (pin * 2U));                                        /* no pull */
    }
}

void Error_Handler(void)
{
    __disable_irq();
    while (1)
    {
    }
}
