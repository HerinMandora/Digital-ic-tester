/*
 ******************************************************************************
 * ic_tester.s
 *
 * Auto-Detecting Digital IC Tester - core engine (ARM Thumb, Cortex-M4)
 ******************************************************************************
 */

    .syntax unified
    .thumb
    .cpu cortex-m4

    .equ GPIOA_BASE, 0x40020000
    .equ GPIOC_BASE, 0x40020800
    .equ MODER_OFF,  0x00
    .equ PUPDR_OFF,  0x0C
    .equ IDR_OFF,    0x10
    .equ BSRR_OFF,   0x18

    /* ------------------------------------------------------------ */
    .section .bss
    .align 2
g_any_high_seen:
    .word 0

g_high_match_count:
    .word 0

g_best_high_matches:
    .word 0

/* --- Best-match scoring used to decide PASS/FAIL ---
 * Every candidate is tested and scored (how many of its A/B->Y combos
 * matched, out of 16 for the five 2-input families or 12 for NOT).
 * Whichever candidate scores highest is the reported IC, but only if
 * that score is a strict majority (score*2 > total) of its own combos -
 * otherwise the result is UNKNOWN IC / FAIL. No score is shown on the
 * display; it is only used internally to pick and validate the winner.
 *
 * g_match_count : combos matched by the candidate currently under test
 *                 (zeroed by Run_AutoDetect before each Test_X call,
 *                 incremented by Gate_TestPin2/1 on every match).
 * g_best_score  : highest g_match_count seen across all 6 candidates so
 *                 far this sweep. Starts at -1 so the first candidate
 *                 always "wins" and g_best_name is never left blank.
 * g_best_total  : total possible combos for whichever candidate currently
 *                 holds g_best_score - used for the majority check.
 * g_best_name   : pointer to the name string of the current best guess.
 * g_high_match_count : correctly detected HIGH outputs for current candidate.
 * g_best_high_matches: HIGH matches belonging to the current best candidate.
 */
g_match_count:
    .word 0
g_best_score:
    .word 0
g_best_total:
    .word 0
g_best_name:
    .word 0

    /* ------------------------------------------------------------ */
    .section .text

    .extern HAL_Delay
    .extern OLED_Init
    .extern OLED_Clear
    .extern OLED_Update
    .extern OLED_PrintAt

    .extern Test_NAND
    .extern Test_NOR
    .extern Test_NOT
    .extern Test_AND
    .extern Test_OR
    .extern Test_XOR

    .global Tester_Run
    .global GPIO_ConfigPin
    .global GPIO_Write
    .global GPIO_Read
    .global GPIO_AllSafe
    .global Gate_TestPin2
    .global Gate_TestPin1
    .global LED_Write

/* =============================================================
 * void GPIO_ConfigPin(uint32_t pin, uint32_t mode, uint32_t pupd)
 *   pin  : 0-11 (PA0-PA11)
 *   mode : 0 = input, 1 = output
 *   pupd : 0 = no pull, 1 = pull-up, 2 = pull-down
 * Clobbers r0-r3. Preserves r4+.
 * ============================================================= */
    .thumb_func
GPIO_ConfigPin:
    push    {r4, r5, r6, lr}
    mov     r4, r0              @ pin
    mov     r5, r1              @ mode
    mov     r6, r2              @ pupd
    ldr     r3, =GPIOA_BASE

    lsls    r1, r4, #1          @ r1 = field shift = pin*2

    ldr     r0, [r3, #MODER_OFF]
    movs    r2, #3
    lsls    r2, r2, r1          @ mask = 3 << shift
    bics    r0, r2              @ clear field
    lsls    r2, r5, r1          @ mode << shift
    orrs    r0, r2
    str     r0, [r3, #MODER_OFF]

    ldr     r0, [r3, #PUPDR_OFF]
    movs    r2, #3
    lsls    r2, r2, r1
    bics    r0, r2
    lsls    r2, r6, r1
    orrs    r0, r2
    str     r0, [r3, #PUPDR_OFF]

    pop     {r4, r5, r6, pc}
    .ltorg

/* =============================================================
 * void GPIO_Write(uint32_t pin, uint32_t val)   PA0-PA11 only
 * Atomic set/reset via BSRR. Clobbers r0-r3.
 * ============================================================= */
    .thumb_func
GPIO_Write:
    ldr     r2, =GPIOA_BASE
    cmp     r1, #0
    beq     .Lgw_reset
    movs    r3, #1
    lsls    r3, r3, r0
    str     r3, [r2, #BSRR_OFF]
    bx      lr
.Lgw_reset:
    movs    r3, #1
    lsls    r3, r3, r0
    lsls    r3, r3, #16
    str     r3, [r2, #BSRR_OFF]
    bx      lr
    .ltorg

/* =============================================================
 * uint32_t GPIO_Read(uint32_t pin)   PA0-PA11 only, returns 0/1
 * ============================================================= */
    .thumb_func
GPIO_Read:
    ldr     r1, =GPIOA_BASE
    ldr     r2, [r1, #IDR_OFF]
    lsrs    r0, r2, r0
    movs    r1, #1
    ands    r0, r1
    bx      lr
    .ltorg

/* =============================================================
 * void GPIO_AllSafe(void)
 * Forces PA0-PA11 to INPUT + PULL-DOWN. Called before/after every
 * candidate test so a role reversal between candidates (a pin that
 * was an output A in one mapping and an output Y in the next) can
 * never contend with whatever the IC is driving.
 * ============================================================= */
    .thumb_func
GPIO_AllSafe:
    push    {r4, lr}
    movs    r4, #0
.Las_loop:
    mov     r0, r4
    movs    r1, #0
    movs    r2, #2
    bl      GPIO_ConfigPin
    adds    r4, r4, #1
    cmp     r4, #12
    blt     .Las_loop
    pop     {r4, pc}
    .ltorg

/* =============================================================
 * uint32_t Gate_TestPin2(uint32_t A, uint32_t B, uint32_t Y,
 *                         const uint8_t *expected4)
 * Drives A,B through 00,01,10,11 and checks Y (pull-down biased,
 * double-sampled for stability) against expected4[0..3].
 * Returns 1 if ALL 4 combinations match, else 0.
 * Sweeps all 4 combinations regardless of an early mismatch, so
 * g_any_high_seen stays accurate.
 * ============================================================= */
    .thumb_func
Gate_TestPin2:
    push    {r4-r10, lr}
    mov     r4, r0          @ A pin
    mov     r5, r1          @ B pin
    mov     r6, r2          @ Y pin
    mov     r7, r3          @ expected ptr
    movs    r8, #0          @ combo index 0..3
    movs    r9, #1          @ pass accumulator

    mov     r0, r6
    movs    r1, #0
    movs    r2, #2          @ Y = input, pull-down
    bl      GPIO_ConfigPin
    mov     r0, r4
    movs    r1, #1
    movs    r2, #0          @ A = output, no pull
    bl      GPIO_ConfigPin
    mov     r0, r5
    movs    r1, #1
    movs    r2, #0          @ B = output, no pull
    bl      GPIO_ConfigPin

.Lg2_loop:
    @ a_val = bit1 of combo, b_val = bit0 of combo
    mov     r0, r8
    lsrs    r0, r0, #1
    movs    r1, #1
    ands    r0, r1          @ a_val
    mov     r10, r0
    mov     r0, r4
    mov     r1, r10
    bl      GPIO_Write       @ drive A

    mov     r0, r8
    movs    r1, #1
    ands    r0, r1          @ b_val
    mov     r10, r0
    mov     r0, r5
    mov     r1, r10
    bl      GPIO_Write       @ drive B

    movs    r0, #2
    bl      HAL_Delay        @ settle
    mov     r0, r6
    bl      GPIO_Read
    mov     r10, r0          @ first sample

    movs    r0, #1
    bl      HAL_Delay
    mov     r0, r6
    bl      GPIO_Read        @ second sample

    cmp     r0, r10
    bne     .Lg2_mismatch    @ unstable read -> reject this combo

    cmp     r0, #0
    beq     .Lg2_cmp
    ldr     r1, =g_any_high_seen
    movs    r2, #1
    str     r2, [r1]

.Lg2_cmp:
    ldrb    r1, [r7, r8]     @ expected[combo]

    @ Count HIGH outputs that were actually expected HIGH.
    @ This is kept per candidate and copied into g_best_high_matches
    @ when that candidate becomes the best-scoring candidate.
    cmp     r0, #1
    bne     .Lg2_check_match
    cmp     r1, #1
    bne     .Lg2_check_match
    ldr     r2, =g_high_match_count
    ldr     r3, [r2]
    adds    r3, r3, #1
    str     r3, [r2]

.Lg2_check_match:
    cmp     r0, r1
    bne     .Lg2_mismatch
    ldr     r2, =g_match_count
    ldr     r3, [r2]
    adds    r3, r3, #1
    str     r3, [r2]
    b       .Lg2_next

.Lg2_mismatch:
    movs    r9, #0

.Lg2_next:
    adds    r8, r8, #1
    cmp     r8, #4
    blt     .Lg2_loop

    mov     r0, r9
    pop     {r4-r10, pc}
    .ltorg

/* =============================================================
 * uint32_t Gate_TestPin1(uint32_t A, uint32_t Y,
 *                         const uint8_t *expected2)
 * Same idea as Gate_TestPin2 but for a single-input gate (NOT),
 * A driven 0 then 1, Y checked against expected2[0..1].
 * ============================================================= */
    .thumb_func
Gate_TestPin1:
    push    {r4-r9, lr}
    mov     r4, r0          @ A pin
    mov     r5, r1          @ Y pin
    mov     r6, r2          @ expected ptr
    movs    r7, #0          @ combo 0..1
    movs    r8, #1          @ pass accumulator

    mov     r0, r5
    movs    r1, #0
    movs    r2, #2          @ Y = input, pull-down
    bl      GPIO_ConfigPin
    mov     r0, r4
    movs    r1, #1
    movs    r2, #0          @ A = output
    bl      GPIO_ConfigPin

.Lg1_loop:
    mov     r0, r4
    mov     r1, r7
    bl      GPIO_Write

    movs    r0, #2
    bl      HAL_Delay
    mov     r0, r5
    bl      GPIO_Read
    mov     r9, r0

    movs    r0, #1
    bl      HAL_Delay
    mov     r0, r5
    bl      GPIO_Read

    cmp     r0, r9
    bne     .Lg1_mismatch

    cmp     r0, #0
    beq     .Lg1_cmp
    ldr     r1, =g_any_high_seen
    movs    r2, #1
    str     r2, [r1]

.Lg1_cmp:
    ldrb    r1, [r6, r7]

    @ Count HIGH outputs that were actually expected HIGH.
    cmp     r0, #1
    bne     .Lg1_check_match
    cmp     r1, #1
    bne     .Lg1_check_match
    ldr     r2, =g_high_match_count
    ldr     r3, [r2]
    adds    r3, r3, #1
    str     r3, [r2]

.Lg1_check_match:
    cmp     r0, r1
    bne     .Lg1_mismatch
    ldr     r2, =g_match_count
    ldr     r3, [r2]
    adds    r3, r3, #1
    str     r3, [r2]
    b       .Lg1_next

.Lg1_mismatch:
    movs    r8, #0

.Lg1_next:
    adds    r7, r7, #1
    cmp     r7, #2
    blt     .Lg1_loop

    mov     r0, r8
    pop     {r4-r9, pc}
    .ltorg

/* =============================================================
 * void LED_Write(uint32_t which, uint32_t val)
 *   which: 0 = PASS LED (PC3), 1 = FAIL LED (PC4), 2 = BUZZER (PC5)
 * ============================================================= */
    .thumb_func
LED_Write:
    adds    r0, r0, #3       @ bit index 3,4,5
    ldr     r2, =GPIOC_BASE
    cmp     r1, #0
    beq     .Lled_reset
    movs    r3, #1
    lsls    r3, r3, r0
    str     r3, [r2, #BSRR_OFF]
    bx      lr
.Lled_reset:
    movs    r3, #1
    lsls    r3, r3, r0
    lsls    r3, r3, #16
    str     r3, [r2, #BSRR_OFF]
    bx      lr
    .ltorg

/* =============================================================
 * uint32_t Button_Read(uint32_t which)
 *   which: 0 = UP (PC0), 1 = DOWN (PC1), 2 = OK (PC2)
 * Returns 1 if PRESSED (buttons are active-low w/ internal pull-up).
 * ============================================================= */
    .thumb_func
Button_Read:
    ldr     r1, =GPIOC_BASE
    ldr     r2, [r1, #IDR_OFF]
    lsrs    r2, r2, r0
    movs    r3, #1
    ands    r2, r3
    eors    r2, r3           @ invert: pressed(0) -> 1, released(1) -> 0
    mov     r0, r2
    bx      lr
    .ltorg

/* =============================================================
 * void Button_WaitRelease(uint32_t which)
 * Simple blocking debounce: waits until the button reads released.
 * ============================================================= */
    .thumb_func
Button_WaitRelease:
    push    {r4, lr}
    mov     r4, r0
.Lwr_loop:
    movs    r0, #15
    bl      HAL_Delay
    mov     r0, r4
    bl      Button_Read
    cmp     r0, #1
    beq     .Lwr_loop
    pop     {r4, pc}
    .ltorg

/* =============================================================
 * void Draw_Menu(uint32_t cursor)   cursor: 0,1,2
 * ============================================================= */
    .thumb_func
Draw_Menu:
    push    {r4, lr}
    mov     r4, r0
    bl      OLED_Clear

    movs    r0, #44
    movs    r1, #0
    ldr     r2, =str_title
    bl      OLED_PrintAt

    cmp     r4, #0
    bne     .Ldm_o0n
    ldr     r2, =str_opt0_sel
    b       .Ldm_o0
.Ldm_o0n:
    ldr     r2, =str_opt0
.Ldm_o0:
    movs    r0, #0
    movs    r1, #2
    bl      OLED_PrintAt

    cmp     r4, #1
    bne     .Ldm_o1n
    ldr     r2, =str_opt1_sel
    b       .Ldm_o1
.Ldm_o1n:
    ldr     r2, =str_opt1
.Ldm_o1:
    movs    r0, #0
    movs    r1, #4
    bl      OLED_PrintAt

    cmp     r4, #2
    bne     .Ldm_o2n
    ldr     r2, =str_opt2_sel
    b       .Ldm_o2
.Ldm_o2n:
    ldr     r2, =str_opt2
.Ldm_o2:
    movs    r0, #0
    movs    r1, #6
    bl      OLED_PrintAt

    bl      OLED_Update
    pop     {r4, pc}
    .ltorg

/* =============================================================
 * void Score_Track(uint32_t total, const char *name)
 * Called after a candidate fails full verification. If g_match_count
 * (combos that matched for the candidate just tested) beats the best
 * score seen so far this sweep, remembers it as the closest guess.
 * ============================================================= */
    .thumb_func
Score_Track:
    push    {r4, r5, lr}
    mov     r4, r0          @ total for this candidate
    mov     r5, r1          @ name ptr for this candidate
    ldr     r0, =g_match_count
    ldr     r0, [r0]
    ldr     r1, =g_best_score
    ldr     r2, [r1]
    cmp     r0, r2
    ble     .Lst_done
    str     r0, [r1]        @ g_best_score = g_match_count
    ldr     r1, =g_best_total
    str     r4, [r1]
    ldr     r1, =g_best_name
    str     r5, [r1]
    ldr     r1, =g_high_match_count
    ldr     r2, [r1]
    ldr     r1, =g_best_high_matches
    str     r2, [r1]
.Lst_done:
    pop     {r4, r5, pc}
    .ltorg

/* =============================================================
 * void Run_AutoDetect(void)
 * Scores EVERY candidate (how many of its A/B->Y combos matched,
 * out of 16 for the five 2-input families or 12 for NOT), then
 * picks whichever candidate scored highest. If that best score is
 * a clear majority (more than half its combos matched) it is
 * reported as the identified IC + PASS (green LED). Otherwise, if
 * nothing was ever driven at all (g_any_high_seen == 0) it is
 * reported as NO IC / EMPTY; if something was driven but no
 * candidate reached a majority, it is UNKNOWN IC / FAIL (red LED).
 * Only the IC name and PASS/FAIL are shown - no score is displayed.
 * ============================================================= */
    .thumb_func
Run_AutoDetect:
    push    {r4, lr}

    bl      OLED_Clear
    movs    r0, #4
    movs    r1, #3
    ldr     r2, =str_testing
    bl      OLED_PrintAt
    bl      OLED_Update

    ldr     r0, =g_any_high_seen
    movs    r1, #0
    str     r1, [r0]

    ldr     r0, =g_best_score
    movs    r1, #0
    mvns    r1, r1          @ r1 = -1, so the first candidate always wins
    str     r1, [r0]
    ldr     r0, =g_best_total
    str     r1, [r0]        @ dummy until first Score_Track call
    ldr     r0, =g_best_name
    ldr     r1, =str_ic_nand
    str     r1, [r0]        @ safe default, overwritten by first Score_Track
    ldr     r0, =g_best_high_matches
    movs    r1, #0
    str     r1, [r0]

    bl      GPIO_AllSafe

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_NAND
    movs    r0, #16
    ldr     r1, =str_ic_nand
    bl      Score_Track

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_NOR
    movs    r0, #16
    ldr     r1, =str_ic_nor
    bl      Score_Track

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_NOT
    movs    r0, #12
    ldr     r1, =str_ic_not
    bl      Score_Track

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_AND
    movs    r0, #16
    ldr     r1, =str_ic_and
    bl      Score_Track

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_OR
    movs    r0, #16
    ldr     r1, =str_ic_or
    bl      Score_Track

    ldr     r0, =g_match_count
    movs    r1, #0
    str     r1, [r0]
    ldr     r0, =g_high_match_count
    str     r1, [r0]
    bl      Test_XOR
    movs    r0, #16
    ldr     r1, =str_ic_xor
    bl      Score_Track

    ldr     r0, =g_any_high_seen
    ldr     r0, [r0]
    cmp     r0, #0
    beq     .Lad_empty

    @ Best candidate must clear a strict majority of its own combos
    @ (score*2 > total) to be accepted as a PASS.
    ldr     r0, =g_best_score
    ldr     r0, [r0]
    lsls    r0, r0, #1      @ r0 = 2 * best score
    ldr     r1, =g_best_total
    ldr     r1, [r1]
    cmp     r0, r1
    ble     .Lad_unknown

    @ The winning candidate must also have at least one correctly
    @ detected HIGH output. This rejects an empty socket whose pull-down
    @ makes most floating outputs look LOW. The count belongs to the
    @ winning candidate because Score_Track saved it with the best score.
    ldr     r0, =g_best_high_matches
    ldr     r0, [r0]
    cmp     r0, #0
    beq     .Lad_unknown

    ldr     r4, =g_best_name
    ldr     r4, [r4]

.Lad_pass:
    bl      GPIO_AllSafe
    movs    r0, #0
    movs    r1, #1
    bl      LED_Write        @ PASS LED on
    movs    r0, #1
    movs    r1, #0
    bl      LED_Write        @ FAIL LED off
    movs    r0, #2
    movs    r1, #1
    bl      LED_Write        @ short beep
    movs    r0, #60
    bl      HAL_Delay
    movs    r0, #2
    movs    r1, #0
    bl      LED_Write

    bl      OLED_Clear
    movs    r0, #16
    movs    r1, #2
    mov     r2, r4
    bl      OLED_PrintAt
    movs    r0, #34
    movs    r1, #4
    ldr     r2, =str_pass
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #6
    ldr     r2, =str_okreturn
    bl      OLED_PrintAt
    bl      OLED_Update
    b       .Lad_waitok

.Lad_empty:
    bl      GPIO_AllSafe
    movs    r0, #0
    movs    r1, #0
    bl      LED_Write
    movs    r0, #1
    movs    r1, #0
    bl      LED_Write
    bl      OLED_Clear
    movs    r0, #22
    movs    r1, #2
    ldr     r2, =str_noic
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #6
    ldr     r2, =str_okreturn
    bl      OLED_PrintAt
    bl      OLED_Update
    b       .Lad_waitok

.Lad_unknown:
    bl      GPIO_AllSafe
    movs    r0, #0
    movs    r1, #0
    bl      LED_Write
    movs    r0, #1
    movs    r1, #1
    bl      LED_Write        @ FAIL LED on
    movs    r0, #2
    movs    r1, #1
    bl      LED_Write
    movs    r0, #150
    bl      HAL_Delay
    movs    r0, #2
    movs    r1, #0
    bl      LED_Write
    bl      OLED_Clear
    movs    r0, #10
    movs    r1, #2
    ldr     r2, =str_unknown
    bl      OLED_PrintAt
    movs    r0, #34
    movs    r1, #4
    ldr     r2, =str_fail
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #6
    ldr     r2, =str_okreturn
    bl      OLED_PrintAt
    bl      OLED_Update

.Lad_waitok:
    movs    r0, #2
    bl      Button_Read
    cmp     r0, #1
    bne     .Lad_waitok
    movs    r0, #2
    bl      Button_WaitRelease

    movs    r0, #0
    movs    r1, #0
    bl      LED_Write
    movs    r0, #1
    movs    r1, #0
    bl      LED_Write

    pop     {r4, pc}
    .ltorg

/* =============================================================
 * void Show_Supported(void)
 * ============================================================= */
    .thumb_func
Show_Supported:
    push    {lr}
    bl      OLED_Clear
    movs    r0, #0
    movs    r1, #0
    ldr     r2, =str_sup_nand
    bl      OLED_PrintAt
    movs    r0, #0
    movs    r1, #1
    ldr     r2, =str_sup_nor
    bl      OLED_PrintAt
    movs    r0, #0
    movs    r1, #2
    ldr     r2, =str_sup_not
    bl      OLED_PrintAt
    movs    r0, #0
    movs    r1, #3
    ldr     r2, =str_sup_and
    bl      OLED_PrintAt
    movs    r0, #0
    movs    r1, #4
    ldr     r2, =str_sup_or
    bl      OLED_PrintAt
    movs    r0, #0
    movs    r1, #5
    ldr     r2, =str_sup_xor
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #7
    ldr     r2, =str_okreturn
    bl      OLED_PrintAt
    bl      OLED_Update
.Lss_wait:
    movs    r0, #2
    bl      Button_Read
    cmp     r0, #1
    bne     .Lss_wait
    movs    r0, #2
    bl      Button_WaitRelease
    pop     {pc}
    .ltorg

/* =============================================================
 * void Show_About(void)
 * ============================================================= */
    .thumb_func
Show_About:
    push    {lr}
    bl      OLED_Clear
    movs    r0, #4
    movs    r1, #1
    ldr     r2, =str_about1
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #3
    ldr     r2, =str_about2
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #5
    ldr     r2, =str_about3
    bl      OLED_PrintAt
    movs    r0, #4
    movs    r1, #7
    ldr     r2, =str_okreturn
    bl      OLED_PrintAt
    bl      OLED_Update
.Lsa_wait:
    movs    r0, #2
    bl      Button_Read
    cmp     r0, #1
    bne     .Lsa_wait
    movs    r0, #2
    bl      Button_WaitRelease
    pop     {pc}
    .ltorg

/* =============================================================
 * void Tester_Run(void)   -  never returns
 * ============================================================= */
    .thumb_func
Tester_Run:
    push    {r4, lr}
    bl      OLED_Init
    bl      GPIO_AllSafe
    movs    r0, #0
    movs    r1, #0
    bl      LED_Write
    movs    r0, #1
    movs    r1, #0
    bl      LED_Write
    movs    r0, #2
    movs    r1, #0
    bl      LED_Write

    movs    r4, #0          @ cursor

.Ltr_menu:
    mov     r0, r4
    bl      Draw_Menu

.Ltr_poll:
    movs    r0, #0
    bl      Button_Read
    cmp     r0, #1
    beq     .Ltr_up
    movs    r0, #1
    bl      Button_Read
    cmp     r0, #1
    beq     .Ltr_down
    movs    r0, #2
    bl      Button_Read
    cmp     r0, #1
    beq     .Ltr_ok
    movs    r0, #5
    bl      HAL_Delay
    b       .Ltr_poll

.Ltr_up:
    movs    r0, #0
    bl      Button_WaitRelease
    cmp     r4, #0
    beq     .Ltr_menu
    subs    r4, r4, #1
    b       .Ltr_menu

.Ltr_down:
    movs    r0, #1
    bl      Button_WaitRelease
    cmp     r4, #2
    beq     .Ltr_menu
    adds    r4, r4, #1
    b       .Ltr_menu

.Ltr_ok:
    movs    r0, #2
    bl      Button_WaitRelease
    cmp     r4, #0
    beq     .Ltr_auto
    cmp     r4, #1
    beq     .Ltr_sup
    bl      Show_About
    b       .Ltr_menu
.Ltr_auto:
    bl      Run_AutoDetect
    b       .Ltr_menu
.Ltr_sup:
    bl      Show_Supported
    b       .Ltr_menu
    .ltorg

/* =============================================================
 * Strings (all uppercase / punctuation covered by the OLED font)
 * ============================================================= */
    .section .rodata
str_title:      .asciz "MENU"
str_opt0:       .asciz "  AUTO DETECT"
str_opt0_sel:   .asciz "> AUTO DETECT"
str_opt1:       .asciz "  SUPPORTED ICS"
str_opt1_sel:   .asciz "> SUPPORTED ICS"
str_opt2:       .asciz "  ABOUT"
str_opt2_sel:   .asciz "> ABOUT"
str_testing:    .asciz "TESTING..."
str_pass:       .asciz "PASS"
str_fail:       .asciz "FAIL"
str_noic:       .asciz "NO IC / EMPTY"
str_unknown:    .asciz "UNKNOWN IC"
str_okreturn:   .asciz "OK: BACK"
str_ic_nand:    .asciz "74HC00 NAND"
str_ic_nor:     .asciz "74HC02 NOR"
str_ic_not:     .asciz "74HC04 NOT"
str_ic_and:     .asciz "74HC08 AND"
str_ic_or:      .asciz "74HC32 OR"
str_ic_xor:     .asciz "74HC86 XOR"
str_sup_nand:   .asciz "74HC00 - NAND"
str_sup_nor:    .asciz "74HC02 - NOR"
str_sup_not:    .asciz "74HC04 - NOT"
str_sup_and:    .asciz "74HC08 - AND"
str_sup_or:     .asciz "74HC32 - OR"
str_sup_xor:    .asciz "74HC86 - XOR"
str_about1:     .asciz "IC TESTER"
str_about2:     .asciz "STM32F446RE"
str_about3:     .asciz "MCI SA"

