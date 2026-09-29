/**
  ******************************************************************************
  * @file    i2c1_reg.c
  * @brief   Register-level I2C1 master driver.
  ******************************************************************************
  */

#include "i2c1_reg.h"
#include "stm32f4xx.h"

#define I2C1_WAIT_LIMIT   100000U

/* PCLK1 (APB1) is 45 MHz with this project's clock tree
 * (SYSCLK=90MHz, APB1 prescaler = /2). See SystemClock_Config() in main.c. */
#define I2C1_PCLK1_MHZ    45U

void I2C1_Init(void)
{
    /* --- GPIO: PB8 = I2C1_SCL, PB9 = I2C1_SDA, AF4, open-drain, pull-up --- */
    RCC->AHB1ENR |= RCC_AHB1ENR_GPIOBEN;

    /* MODER: '10' = alternate function, for pins 8 and 9 */
    GPIOB->MODER &= ~((3U << (8U * 2U)) | (3U << (9U * 2U)));
    GPIOB->MODER |=  ((2U << (8U * 2U)) | (2U << (9U * 2U)));

    /* OTYPER: '1' = open-drain, for pins 8 and 9 (required for I2C) */
    GPIOB->OTYPER |= (1U << 8U) | (1U << 9U);

    /* OSPEEDR: '10' = high speed, for pins 8 and 9 */
    GPIOB->OSPEEDR &= ~((3U << (8U * 2U)) | (3U << (9U * 2U)));
    GPIOB->OSPEEDR |=  ((2U << (8U * 2U)) | (2U << (9U * 2U)));

    /* PUPDR: '01' = pull-up, for pins 8 and 9 */
    GPIOB->PUPDR &= ~((3U << (8U * 2U)) | (3U << (9U * 2U)));
    GPIOB->PUPDR |=  ((1U << (8U * 2U)) | (1U << (9U * 2U)));

    /* AFR[1] = AFRH covers pins 8-15; AF4 = I2C1 on both PB8 and PB9 */
    GPIOB->AFR[1] &= ~((0xFU << ((8U - 8U) * 4U)) | (0xFU << ((9U - 8U) * 4U)));
    GPIOB->AFR[1] |=  ((4U   << ((8U - 8U) * 4U)) | (4U   << ((9U - 8U) * 4U)));

    /* --- I2C1 peripheral: 400 kHz Fast mode, duty cycle 2, 7-bit addr --- */
    RCC->APB1ENR |= RCC_APB1ENR_I2C1EN;

    I2C1->CR1 |= I2C_CR1_SWRST;
    I2C1->CR1 &= ~I2C_CR1_SWRST;

    I2C1->CR2 = (I2C1->CR2 & ~I2C_CR2_FREQ) | (I2C1_PCLK1_MHZ & 0x3FU);

    /* Fast mode (F/S=1), duty cycle 2 (DUTY=0):
     *   CCR = Fpclk1 / (3 * Fscl)  =  45,000,000 / (3 * 400,000)  = 37.5 -> 38
     * TRISE = (300ns * Fpclk1[MHz] / 1000) + 1 = (300*45)/1000 + 1 = 14 */
    I2C1->CCR   = I2C_CCR_FS | (38U & I2C_CCR_CCR);
    I2C1->TRISE = 14U;

    I2C1->CR1 = I2C_CR1_PE; /* NoStretch = 0 (stretching enabled, HAL default) */
}

static int I2C1_WaitFlag(volatile uint32_t *reg, uint32_t mask, uint32_t want)
{
    uint32_t timeout = I2C1_WAIT_LIMIT;
    while (((*reg) & mask) != want)
    {
        if (--timeout == 0U)
        {
            return -1;
        }
    }
    return 0;
}

int I2C1_MasterTransmit(uint8_t addr7, const uint8_t *data, uint16_t len)
{
    uint32_t timeout;

    /* Wait for bus free */
    timeout = I2C1_WAIT_LIMIT;
    while ((I2C1->SR2 & I2C_SR2_BUSY) != 0U)
    {
        if (--timeout == 0U) return -1;
    }

    /* START */
    I2C1->CR1 |= I2C_CR1_START;
    if (I2C1_WaitFlag(&I2C1->SR1, I2C_SR1_SB, I2C_SR1_SB) != 0)
    {
        return -1;
    }

    /* Send 7-bit address, write direction (bit0 = 0) */
    I2C1->DR = (uint8_t)(addr7 << 1) & 0xFEU;

    /* Wait for ADDR (address ack'd) or AF (NACK) */
    timeout = I2C1_WAIT_LIMIT;
    while ((I2C1->SR1 & I2C_SR1_ADDR) == 0U)
    {
        if ((I2C1->SR1 & I2C_SR1_AF) != 0U)
        {
            I2C1->SR1 &= ~I2C_SR1_AF; /* clear NACK flag */
            I2C1->CR1 |= I2C_CR1_STOP;
            return -1;
        }
        if (--timeout == 0U)
        {
            I2C1->CR1 |= I2C_CR1_STOP;
            return -1;
        }
    }
    /* Clear ADDR: read SR1 then SR2 (SR1 already read above) */
    (void)I2C1->SR2;

    for (uint16_t i = 0; i < len; i++)
    {
        if (I2C1_WaitFlag(&I2C1->SR1, I2C_SR1_TXE, I2C_SR1_TXE) != 0)
        {
            I2C1->CR1 |= I2C_CR1_STOP;
            return -1;
        }
        I2C1->DR = data[i];
    }

    /* Wait for the last byte to be fully clocked out before STOP */
    if (I2C1_WaitFlag(&I2C1->SR1, I2C_SR1_BTF, I2C_SR1_BTF) != 0)
    {
        I2C1->CR1 |= I2C_CR1_STOP;
        return -1;
    }

    I2C1->CR1 |= I2C_CR1_STOP;
    return 0;
}
