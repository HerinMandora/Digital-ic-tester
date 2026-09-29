/*
 * nand.s - Test_NAND : 74HC00 (2-input NAND, 4 gates)
 * Truth table required on every gate: 00->1 01->1 10->1 11->0
 */
    .syntax unified
    .thumb
    .cpu cortex-m4

    .section .text
    .extern Gate_TestPin2
    .extern GPIO_AllSafe
    .global Test_NAND

    .thumb_func
Test_NAND:
    push    {r4-r7, lr}
    bl      GPIO_AllSafe
    ldr     r4, =gateTable_NAND
    ldr     r5, =expected_NAND
    movs    r6, #0          @ gate index
    movs    r7, #1          @ pass accumulator

.Ln_loop:
    lsls    r0, r6, #1
    adds    r0, r0, r6      @ r0 = gate_index * 3
    add     r0, r4          @ r0 = &gateTable[idx]
    ldrb    r1, [r0, #0]    @ A
    ldrb    r2, [r0, #1]    @ B
    ldrb    r3, [r0, #2]    @ Y
    mov     r0, r1
    mov     r1, r2
    mov     r2, r3
    mov     r3, r5
    bl      Gate_TestPin2
    cmp     r0, #0
    bne     .Ln_ok
    movs    r7, #0
.Ln_ok:
    adds    r6, r6, #1
    cmp     r6, #4
    blt     .Ln_loop

    bl      GPIO_AllSafe
    mov     r0, r7
    pop     {r4-r7, pc}
    .ltorg

/* Gate pin map (A,B,Y) - identical mapping for 74HC00/08/32/86 */
    .section .rodata
gateTable_NAND:
    .byte 0, 1, 2         @ G1: A=PA0 B=PA1 Y=PA2`
    .byte 3, 4, 5         @ G2: A=PA3 B=PA4 Y=PA5
    .byte 7, 8, 6         @ G3: A=PA7 B=PA8 Y=PA6
    .byte 10, 11, 9        @ G4: A=PA10 B=PA11 Y=PA9
expected_NAND:
    .byte 1, 1, 1, 0
