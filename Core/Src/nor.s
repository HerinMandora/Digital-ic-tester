/*
 * nor.s - Test_NOR : 74HC02 (2-input NOR, 4 gates)
 * Truth table required on every gate: 00->1 01->0 10->0 11->0
 */
    .syntax unified
    .thumb
    .cpu cortex-m4

    .section .text
    .extern Gate_TestPin2
    .extern GPIO_AllSafe
    .global Test_NOR

    .thumb_func
Test_NOR:
    push    {r4-r7, lr}
    bl      GPIO_AllSafe
    ldr     r4, =gateTable_NOR
    ldr     r5, =expected_NOR
    movs    r6, #0
    movs    r7, #1

.Lnr_loop:
    lsls    r0, r6, #1
    adds    r0, r0, r6
    add     r0, r4
    ldrb    r1, [r0, #0]
    ldrb    r2, [r0, #1]
    ldrb    r3, [r0, #2]
    mov     r0, r1
    mov     r1, r2
    mov     r2, r3
    mov     r3, r5
    bl      Gate_TestPin2
    cmp     r0, #0
    bne     .Lnr_ok
    movs    r7, #0
.Lnr_ok:
    adds    r6, r6, #1
    cmp     r6, #4
    blt     .Lnr_loop

    bl      GPIO_AllSafe
    mov     r0, r7
    pop     {r4-r7, pc}
    .ltorg

/* 74HC02 gate pin map (A,B,Y) - note the reversed A/B/Y roles vs NAND */
    .section .rodata
gateTable_NOR:
    .byte 1, 2, 0          @ G1: A=PA1 B=PA2 Y=PA0
    .byte 4, 5, 3          @ G2: A=PA4 B=PA5 Y=PA3
    .byte 6, 7, 8          @ G3: A=PA6 B=PA7 Y=PA8
    .byte 9, 10, 11        @ G4: A=PA9 B=PA10 Y=PA11
expected_NOR:
    .byte 1, 0, 0, 0
