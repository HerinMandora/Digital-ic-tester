/*
 * not.s - Test_NOT : 74HC04 (1-input NOT/inverter, 6 gates)
 * Truth table required on every gate: 0->1  1->0
 */
    .syntax unified
    .thumb
    .cpu cortex-m4

    .section .text
    .extern Gate_TestPin1
    .extern GPIO_AllSafe
    .global Test_NOT

    .thumb_func
Test_NOT:
    push    {r4-r7, lr}
    bl      GPIO_AllSafe
    ldr     r4, =gateTable_NOT
    ldr     r5, =expected_NOT
    movs    r6, #0
    movs    r7, #1

.Lnt_loop:
    lsls    r0, r6, #1      @ r0 = gate_index * 2
    add     r0, r4
    ldrb    r1, [r0, #0]    @ A
    ldrb    r2, [r0, #1]    @ Y
    mov     r0, r1
    mov     r1, r2
    mov     r2, r5
    bl      Gate_TestPin1
    cmp     r0, #0
    bne     .Lnt_ok
    movs    r7, #0
.Lnt_ok:
    adds    r6, r6, #1
    cmp     r6, #6
    blt     .Lnt_loop

    bl      GPIO_AllSafe
    mov     r0, r7
    pop     {r4-r7, pc}
    .ltorg

/* 74HC04 gate pin map (A,Y) */
    .section .rodata
gateTable_NOT:
    .byte 0, 1             @ G1: A=PA0 -> Y=PA1
    .byte 2, 3             @ G2: A=PA2 -> Y=PA3
    .byte 4, 5             @ G3: A=PA4 -> Y=PA5
    .byte 7, 6             @ G4: A=PA7 -> Y=PA6
    .byte 9, 8             @ G5: A=PA9 -> Y=PA8
    .byte 11, 10            @ G6: A=PA11 -> Y=PA10
expected_NOT:
    .byte 1, 0
