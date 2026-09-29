/*
 * and.s - Test_AND : 74HC08 (2-input AND, 4 gates)
 * Truth table required on every gate: 00->0 01->0 10->0 11->1
 */
    .syntax unified
    .thumb
    .cpu cortex-m4

    .section .text
    .extern Gate_TestPin2
    .extern GPIO_AllSafe
    .global Test_AND

    .thumb_func
Test_AND:
    push    {r4-r7, lr}
    bl      GPIO_AllSafe
    ldr     r4, =gateTable_AND
    ldr     r5, =expected_AND
    movs    r6, #0
    movs    r7, #1

.La_loop:
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
    bne     .La_ok
    movs    r7, #0
.La_ok:
    adds    r6, r6, #1
    cmp     r6, #4
    blt     .La_loop

    bl      GPIO_AllSafe
    mov     r0, r7
    pop     {r4-r7, pc}
    .ltorg

/* Same gate pin map as 74HC00/32/86 */
    .section .rodata
gateTable_AND:
    .byte 0, 1, 2
    .byte 3, 4, 5
    .byte 7, 8, 6
    .byte 10, 11, 9
expected_AND:
    .byte 0, 0, 0, 1
