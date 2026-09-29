/**
  ******************************************************************************
  * @file    oled.h
  * @brief   SSD1306 0.96" I2C OLED driver interface.
  *          PB8 = SCL, PB9 = SDA (I2C1, 400kHz Fast Mode, Duty 2)
  ******************************************************************************
  */

#ifndef __OLED_H
#define __OLED_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

void OLED_Init(void);
void OLED_Clear(void);
void OLED_Update(void);
void OLED_PrintAt(uint8_t x, uint8_t page, const char *text);
void OLED_PrintNumberAt(uint8_t x, uint8_t page, uint32_t number);

#ifdef __cplusplus
}
#endif

#endif /* __OLED_H */
