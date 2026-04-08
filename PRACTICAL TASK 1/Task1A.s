; -------------------------------------------------------------------------
; Task 1A: GPIO Manipulation for NUCLEO-F401RE
; -------------------------------------------------------------------------

; --- Memory Mapped Registers ---
RCC_AHB1ENR EQU 0x40023830      ; Clock Control Register
GPIOA_MODER EQU 0x40020000      ; Port A Mode Register
GPIOA_ODR   EQU 0x40020014      ; Port A Output Data Register
GPIOA_BSRR  EQU 0x40020018      ; Port A Bit Set/Reset Register

GPIOB_MODER EQU 0x40020400      ; Port B Mode Register
GPIOB_ODR   EQU 0x40020414      ; Port B Output Data Register
GPIOB_BSRR  EQU 0x40020418      ; Port B Bit Set/Reset Register

    AREA    |.text|, CODE, READONLY
    EXPORT  start               ; Match the IMPORT in the startup file
    ENTRY

start PROC                      ; Begin the main procedure
    ; 1. Enable Clocks for GPIOA and GPIOB
    LDR R0, =RCC_AHB1ENR
    LDR R1, [R0]
    ORR R1, R1, #0x03           ; Set bit 0 (GPIOA) and bit 1 (GPIOB)
    STR R1, [R0]

    ; 2. Configure PA5 (LD2) as General Purpose Output
    LDR R0, =GPIOA_MODER
    LDR R1, [R0]
    BIC R1, R1, #(0x3 << 10)    ; Clear bits 10 and 11
    ORR R1, R1, #(0x1 << 10)    ; Set bit 10 to 1 (Output mode)
    STR R1, [R0]

    ; 3. Configure PB0 (External LED2) as General Purpose Output
    LDR R0, =GPIOB_MODER
    LDR R1, [R0]
    BIC R1, R1, #(0x3 << 0)     ; Clear bits 0 and 1
    ORR R1, R1, #(0x1 << 0)     ; Set bit 0 to 1 (Output mode)
    STR R1, [R0]

    ; =====================================================================
    ; SELECT WHICH TASK TO RUN BY UNCOMMENTING ONE OF THE BRANCHES BELOW:
    ; =====================================================================
    ;B task_1a_i     ; Run Task 1A (i)
    ;B task_1a_ii    ; Run Task 1A (ii)
    ;B task_1a_iii   ; Run Task 1A (iii)
    ;B task_1a_iv    ; Run Task 1A (iv)
    B task_1a_v     ; Run Task 1A (v)


; -------------------------------------------------------------------------
; Task 1A (i): Blink LD2 (PA5) using GPIOA_ODR
; -------------------------------------------------------------------------
task_1a_i
    LDR R0, =GPIOA_ODR
loop_i
    LDR R1, [R0]
    EOR R1, R1, #(1 << 5)       ; Toggle bit 5
    STR R1, [R0]
    BL delay                    
    B loop_i

; -------------------------------------------------------------------------
; Task 1A (ii): Blink LD2 (PA5) using GPIOA_BSRR
; -------------------------------------------------------------------------
task_1a_ii
    LDR R0, =GPIOA_BSRR
loop_ii
    MOV R1, #(1 << 5)           ; Set bit 5 (Turn ON)
    STR R1, [R0]
    BL delay
    MOV R1, #(1 << 21)          ; Reset bit 5 (Turn OFF)
    STR R1, [R0]
    BL delay
    B loop_ii

; -------------------------------------------------------------------------
; Task 1A (iii): Continuously illuminate external LED2 (PB0) using GPIOB_BSRR
; -------------------------------------------------------------------------
task_1a_iii
    LDR R0, =GPIOB_BSRR
    MOV R1, #(1 << 0)           ; Set bit 0 (Turn ON)
    STR R1, [R0]
loop_iii
    B loop_iii                  ; Infinite loop, stays on

; -------------------------------------------------------------------------
; Task 1A (iv): Continuously illuminate external LED2 (PB0) using GPIOB_ODR
; -------------------------------------------------------------------------
task_1a_iv
    LDR R0, =GPIOB_ODR
    LDR R1, [R0]
    ORR R1, R1, #(1 << 0)       ; Set bit 0 to 1 (Turn ON)
    STR R1, [R0]
loop_iv
    B loop_iv                   ; Infinite loop, stays on

; -------------------------------------------------------------------------
; Task 1A (v): Blink LED2 (PB0) using GPIOB_ODR with delay
; -------------------------------------------------------------------------
task_1a_v
    LDR R0, =GPIOB_ODR
loop_v
    LDR R1, [R0]
    EOR R1, R1, #(1 << 0)       ; Toggle bit 0
    STR R1, [R0]
    BL delay
    B loop_v

    ENDP                        ; MUST close the 'start' procedure here!

; -------------------------------------------------------------------------
; Delay Subroutine
; -------------------------------------------------------------------------
delay PROC                      ; Begin the delay procedure
    LDR R2, =0x000FFFFF         
delay_loop
    SUBS R2, R2, #1             
    BNE delay_loop              
    BX LR                       
    ENDP                        ; MUST close the 'delay' procedure here!

    ALIGN                       ; Fixes the padding warning
    END                         ; End of file