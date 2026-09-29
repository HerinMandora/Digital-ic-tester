/**
 ******************************************************************************
 * @file    i2c1_reg.h
 * @brief   Register-level I2C1 master driver.
 *
 *          PB8 = SCL, PB9 = SDA, Fast mode 400 kHz, duty cycle 2.
 *          GPIO for PB8/PB9 is configured by I2C1_Init();
 *          RCC clock for I2C1/GPIOB is enabled by I2C1_Init() as well.
 ******************************************************************************
 */

#ifndef __I2C1_REG_H
#define __I2C1_REG_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* Configure PB8/PB9 as I2C1 AF, enable RCC clocks, and configure I2C1
 * for 400 kHz Fast mode / duty cycle 2 / 7-bit addressing. */
void I2C1_Init(void);

/* Blocking master transmit: START, 7-bit address (write), `len` data
 * bytes, STOP. `addr7` is the 7-bit slave address (e.g. 0x3C for the
 * SSD1306), NOT pre-shifted. Returns 0 on success, non-zero on error
 * (e.g. NACK). */
int I2C1_MasterTransmit(uint8_t addr7, const uint8_t *data, uint16_t len);

#ifdef __cplusplus
}
#endif

#endif /* __I2C1_REG_H */
