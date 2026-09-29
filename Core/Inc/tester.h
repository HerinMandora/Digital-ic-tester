/**
  ******************************************************************************
  * @file    tester.h
  * @brief   Shared interface between main.c (C/CubeMX init) and the
  *          ARM Thumb assembly IC detection/test engine.
  ******************************************************************************
  */

#ifndef __TESTER_H
#define __TESTER_H

#ifdef __cplusplus
extern "C" {
#endif

/* Entry point of the assembly-implemented tester application.
 * Called once from main() after HAL/GPIO/I2C init. Does not return. */
void Tester_Run(void);

#ifdef __cplusplus
}
#endif

#endif /* __TESTER_H */
