; -------------------------------------------------------------------------
; Task 1B: Pure Assembly I2C OLED Driver (STM32F401RE/F411RE)
; Displays "<Programming My>" and "<<STM32F4XX Board>>"
; -------------------------------------------------------------------------

; --- Memory Mapped Registers ---
RCC_AHB1ENR  EQU 0x40023830
RCC_APB1ENR  EQU 0x40023840

; ---Modification ---
GPIOA_MODER  EQU 0x40020000     ; Port A Mode Register
GPIOA_PUPDR  EQU 0x4002000C     ; Port A Pull-Up/Pull-Down Register
GPIOA_IDR    EQU 0x40020010     ; Port A Input Data Register
; -------------------

GPIOB_MODER  EQU 0x40020400
GPIOB_OTYPER EQU 0x40020404
GPIOB_PUPDR  EQU 0x4002040C
GPIOB_AFRH   EQU 0x40020424

I2C1_CR1     EQU 0x40005400
I2C1_CR2     EQU 0x40005404
I2C1_DR      EQU 0x40005410
I2C1_SR1     EQU 0x40005414
I2C1_SR2     EQU 0x40005418
I2C1_CCR     EQU 0x4000541C
I2C1_TRISE   EQU 0x40005420

OLED_ADDR    EQU 0x78            ; 0x3C shifted left by 1 for Write

    AREA    |.text|, CODE, READONLY
    EXPORT  start
    ENTRY

start PROC
    ; 1. Enable Clocks (GPIOA, GPIOB, and I2C1)
    LDR R0, =RCC_AHB1ENR
    LDR R1, [R0]
    ORR R1, R1, #(1 << 0)       ; GPIOA Enable (Bit 0)
    ORR R1, R1, #(1 << 1)       ; GPIOB Enable (Bit 1)
    STR R1, [R0]

    LDR R0, =RCC_APB1ENR
    LDR R1, [R0]
    ORR R1, R1, #(1 << 21)      ; I2C1 Enable
    STR R1, [R0]

    ; 2. Configure PA0 as Input with Pull-Down
    LDR R0, =GPIOA_MODER
    LDR R1, [R0]
    BIC R1, R1, #(0x3 << 0)     ; Clear bits 0,1 (Input Mode = 00)
    STR R1, [R0]

    LDR R0, =GPIOA_PUPDR
    LDR R1, [R0]
    BIC R1, R1, #(0x3 << 0)     ; Clear bits 0,1
    ORR R1, R1, #(0x2 << 0)     ; Set Pull-Down (10) for PA0
    STR R1, [R0]

    ; 3. Configure PB8/PB9 for I2C (Same as before)
    LDR R0, =GPIOB_MODER
    LDR R1, [R0]
    BIC R1, R1, #(0xF << 16)    
    ORR R1, R1, #(0xA << 16)    
    STR R1, [R0]
    LDR R0, =GPIOB_OTYPER
    LDR R1, [R0]
    ORR R1, R1, #(0x3 << 8)     
    STR R1, [R0]
    LDR R0, =GPIOB_PUPDR
    LDR R1, [R0]
    BIC R1, R1, #(0xF << 16)    
    ORR R1, R1, #(0x5 << 16)    
    STR R1, [R0]
    LDR R0, =GPIOB_AFRH
    LDR R1, [R0]
    BIC R1, R1, #(0xFF << 0)    
    ORR R1, R1, #(0x44 << 0)    
    STR R1, [R0]

    ; 4. Initialize I2C1 & OLED (Same as before)
    LDR R0, =I2C1_CR2
    MOV R1, #16                 
    STR R1, [R0]
    LDR R0, =I2C1_CCR
    MOV R1, #80                 
    STR R1, [R0]
    LDR R0, =I2C1_TRISE
    MOV R1, #17                 
    STR R1, [R0]
    LDR R0, =I2C1_CR1
    LDR R1, [R0]
    ORR R1, R1, #(1 << 0)       
    STR R1, [R0]

    LDR R4, =OLED_Init_Data
    MOV R5, #25                 
init_loop
    LDRB R1, [R4], #1           
    BL OLED_Write_Cmd           
    SUBS R5, R5, #1             
    BNE init_loop               
    BL OLED_Clear

; 5. (Removed the static title initialization)
    ; We jump straight into the polling loop now.

    ; 6. The Main Polling Loop
main_loop
    LDR R0, =GPIOA_IDR          ; Load Input Data Register address
    LDR R1, [R0]                ; Read current state of all Port A pins
    TST R1, #(1 << 0)           ; Test bit 0 (PA0)
    BNE is_pressed              ; If bit is 1, branch to pressed

is_unpressed
    ; --- Draw Unpressed State ---
    ; Row 1
    MOV R1, #0                  ; Page 0
    MOV R2, #0                  ; Column 0
    BL OLED_SetCursor
    LDR R4, =String_0_R1        ; "Logic 0: 0 V"
    BL OLED_PrintString
    
    ; Row 2
    MOV R1, #2                  ; Page 2
    MOV R2, #0                  ; Column 0
    BL OLED_SetCursor
    LDR R4, =String_0_R2        ; "SW1 Unpressed"
    BL OLED_PrintString
    
    B main_loop                 ; Repeat

is_pressed
    ; --- Draw Pressed State ---
    ; Row 1
    MOV R1, #0                  ; Page 0
    MOV R2, #0                  ; Column 0
    BL OLED_SetCursor
    LDR R4, =String_1_R1        ; "Logic 1: 3.3 V"
    BL OLED_PrintString
    
    ; Row 2
    MOV R1, #2                  ; Page 2
    MOV R2, #0                  ; Column 0
    BL OLED_SetCursor
    LDR R4, =String_1_R2        ; "SW1 Pressed"
    BL OLED_PrintString
    
    B main_loop                 ; Repeat

    ENDP

; =========================================================================
; SUBROUTINES
; =========================================================================

; -------------------------------------------------------------------------
; Set OLED Cursor (R1 = Page 0-3, R2 = Column 0-127)
; -------------------------------------------------------------------------
OLED_SetCursor PROC
    PUSH {LR, R0, R1, R2}
    
    ; Send Page Address (0xB0 + Page)
    ADD R0, R1, #0xB0
    MOV R1, R0
    BL OLED_Write_Cmd
    
    ; Send Lower Col Address (0x00 + Lower Nibble)
    AND R0, R2, #0x0F
    MOV R1, R0
    BL OLED_Write_Cmd
    
    ; Send Higher Col Address (0x10 + Upper Nibble)
    LSR R0, R2, #4
    AND R0, R0, #0x0F
    ADD R0, R0, #0x10
    MOV R1, R0
    BL OLED_Write_Cmd
    
    POP {LR, R0, R1, R2}
    BX LR
    ENDP

; -------------------------------------------------------------------------
; Clear OLED Screen
; -------------------------------------------------------------------------
OLED_Clear PROC
    PUSH {LR, R1, R2, R4, R5}
    MOV R4, #0                  ; Page Counter
clear_page_loop
    CMP R4, #4                  ; 4 Pages total
    BEQ clear_done
    MOV R1, R4
    MOV R2, #0
    BL OLED_SetCursor           ; Set cursor to start of page
    
    MOV R5, #128                ; 128 Columns per page
clear_col_loop
    MOV R1, #0x00               ; Blank pixel data
    BL OLED_Write_Data
    SUBS R5, R5, #1
    BNE clear_col_loop
    
    ADD R4, R4, #1              ; Next Page
    B clear_page_loop
clear_done
    POP {LR, R1, R2, R4, R5}
    BX LR
    ENDP

; -------------------------------------------------------------------------
; Print String (R4 = Address of null-terminated string)
; -------------------------------------------------------------------------
OLED_PrintString PROC
    PUSH {LR, R1, R4, R5, R6, R7}
print_loop
    LDRB R5, [R4], #1           ; Load character
    CMP R5, #0                  ; Is it null terminator?
    BEQ print_done
    
    SUBS R5, R5, #32            ; Subtract 32 to match font array index
    MOV R6, #5                  
    MUL R5, R5, R6              ; Multiply by 5 bytes per char
    
    LDR R6, =Font5x7            ; Load font base address
    ADD R6, R6, R5              ; Add offset for specific character
    
    MOV R7, #5                  ; 5 columns of data per character
char_col_loop
    LDRB R1, [R6], #1           ; Load pixel byte
    BL OLED_Write_Data          ; Send to screen
    SUBS R7, R7, #1
    BNE char_col_loop
    
    MOV R1, #0x00               ; Send 1 blank column for spacing
    BL OLED_Write_Data          
    
    B print_loop                ; Next character
print_done
    POP {LR, R1, R4, R5, R6, R7}
    BX LR
    ENDP

; -------------------------------------------------------------------------
; I2C Write Command (R1 = Command Byte)
; -------------------------------------------------------------------------
OLED_Write_Cmd PROC
    PUSH {LR, R0, R1, R2, R3}
    MOV R0, #0x00               ; 0x00 Control Byte = Command Mode
    BL I2C_Send_Byte
    POP {LR, R0, R1, R2, R3}
    BX LR
    ENDP

; -------------------------------------------------------------------------
; I2C Write Data (R1 = Data Byte)
; -------------------------------------------------------------------------
OLED_Write_Data PROC
    PUSH {LR, R0, R1, R2, R3}
    MOV R0, #0x40               ; 0x40 Control Byte = Data Mode
    BL I2C_Send_Byte
    POP {LR, R0, R1, R2, R3}
    BX LR
    ENDP

; -------------------------------------------------------------------------
; Core I2C Hardware Transmission (R0 = Control Byte, R1 = Payload Byte)
; -------------------------------------------------------------------------
I2C_Send_Byte PROC
    ; 1. Generate START
    LDR R2, =I2C1_CR1
    LDR R3, [R2]
    ORR R3, R3, #(1 << 8)
    STR R3, [R2]
wait_start
    LDR R2, =I2C1_SR1
    LDR R3, [R2]
    TST R3, #(1 << 0)           ; Wait for SB
    BEQ wait_start

    ; 2. Send OLED Address
    LDR R2, =I2C1_DR
    MOV R3, #OLED_ADDR
    STR R3, [R2]
wait_addr
    LDR R2, =I2C1_SR1
    LDR R3, [R2]
    TST R3, #(1 << 1)           ; Wait for ADDR
    BEQ wait_addr
    LDR R2, =I2C1_SR2           ; Read SR2 to clear ADDR flag
    LDR R3, [R2]

    ; 3. Send Control Byte (Command or Data mode)
    LDR R2, =I2C1_DR
    STR R0, [R2]
wait_txe1
    LDR R2, =I2C1_SR1
    LDR R3, [R2]
    TST R3, #(1 << 7)           ; Wait for TXE
    BEQ wait_txe1

    ; 4. Send Payload Byte
    LDR R2, =I2C1_DR
    STR R1, [R2]
wait_txe2
    LDR R2, =I2C1_SR1
    LDR R3, [R2]
    TST R3, #(1 << 7)
    BEQ wait_txe2
    
wait_btf
    LDR R2, =I2C1_SR1
    LDR R3, [R2]
    TST R3, #(1 << 2)           ; Wait for BTF (Byte Transfer Finished)
    BEQ wait_btf

    ; 5. Generate STOP
    LDR R2, =I2C1_CR1
    LDR R3, [R2]
    ORR R3, R3, #(1 << 9)
    STR R3, [R2]
    
    BX LR
    ENDP

; =========================================================================
; DATA SECTION
; =========================================================================
    AREA    |.data|, DATA, READONLY
    ALIGN

String_0_R1 DCB "Logic 0: 0 V   ", 0
String_0_R2 DCB "SW1 Unpressed  ", 0  

String_1_R1 DCB "Logic 1: 3.3 V ", 0
String_1_R2 DCB "SW1 Pressed    ", 0
    ALIGN

OLED_Init_Data
    DCB 0xAE, 0xD5, 0x80, 0xA8, 0x1F, 0xD3, 0x00, 0x40  
    DCB 0x8D, 0x14, 0x20, 0x00, 0xA1, 0xC8, 0xDA, 0x02  
    DCB 0x81, 0x8F, 0xD9, 0xF1, 0xDB, 0x40, 0xA4, 0xA6, 0xAF 
    ALIGN

; Contiguous 5x7 ASCII Font Array (ASCII 32 to 122)
Font5x7
    DCB 0x00,0x00,0x00,0x00,0x00 ; 32: ' '
    DCB 0x00,0x00,0x5F,0x00,0x00 ; 33: '!'
    DCB 0x00,0x07,0x00,0x07,0x00 ; 34: '"'
    DCB 0x14,0x7F,0x14,0x7F,0x14 ; 35: '#'
    DCB 0x24,0x2A,0x7F,0x2A,0x12 ; 36: '$'
    DCB 0x23,0x13,0x08,0x64,0x62 ; 37: '%'
    DCB 0x36,0x49,0x55,0x22,0x50 ; 38: '&'
    DCB 0x00,0x05,0x03,0x00,0x00 ; 39: '''
    DCB 0x00,0x1C,0x22,0x41,0x00 ; 40: '('
    DCB 0x00,0x41,0x22,0x1C,0x00 ; 41: ')'
    DCB 0x14,0x08,0x3E,0x08,0x14 ; 42: '*'
    DCB 0x08,0x08,0x3E,0x08,0x08 ; 43: '+'
    DCB 0x00,0x50,0x30,0x00,0x00 ; 44: ','
    DCB 0x08,0x08,0x08,0x08,0x08 ; 45: '-'
    DCB 0x00,0x60,0x60,0x00,0x00 ; 46: '.'
    DCB 0x20,0x10,0x08,0x04,0x02 ; 47: '/'
    DCB 0x3E,0x51,0x49,0x45,0x3E ; 48: '0'
    DCB 0x00,0x42,0x7F,0x40,0x00 ; 49: '1'
    DCB 0x42,0x61,0x51,0x49,0x46 ; 50: '2'
    DCB 0x21,0x41,0x45,0x4B,0x31 ; 51: '3'
    DCB 0x18,0x14,0x12,0x7F,0x10 ; 52: '4'
    DCB 0x27,0x45,0x45,0x45,0x39 ; 53: '5'
    DCB 0x3C,0x4A,0x49,0x49,0x30 ; 54: '6'
    DCB 0x01,0x71,0x09,0x05,0x03 ; 55: '7'
    DCB 0x36,0x49,0x49,0x49,0x36 ; 56: '8'
    DCB 0x06,0x49,0x49,0x29,0x1E ; 57: '9'
    DCB 0x00,0x36,0x36,0x00,0x00 ; 58: ':'
    DCB 0x00,0x56,0x36,0x00,0x00 ; 59: ';'
    DCB 0x08,0x14,0x22,0x41,0x00 ; 60: '<'
    DCB 0x14,0x14,0x14,0x14,0x14 ; 61: '='
    DCB 0x00,0x41,0x22,0x14,0x08 ; 62: '>'
    DCB 0x02,0x01,0x51,0x09,0x06 ; 63: '?'
    DCB 0x32,0x49,0x79,0x41,0x3E ; 64: '@'
    DCB 0x7E,0x11,0x11,0x11,0x7E ; 65: 'A'
    DCB 0x7F,0x49,0x49,0x49,0x36 ; 66: 'B'
    DCB 0x3E,0x41,0x41,0x41,0x22 ; 67: 'C'
    DCB 0x7F,0x41,0x41,0x22,0x1C ; 68: 'D'
    DCB 0x7F,0x49,0x49,0x49,0x41 ; 69: 'E'
    DCB 0x7F,0x09,0x09,0x09,0x01 ; 70: 'F'
    DCB 0x3E,0x41,0x49,0x49,0x7A ; 71: 'G'
    DCB 0x7F,0x08,0x08,0x08,0x7F ; 72: 'H'
    DCB 0x00,0x41,0x7F,0x41,0x00 ; 73: 'I'
    DCB 0x20,0x40,0x41,0x3F,0x01 ; 74: 'J'
    DCB 0x7F,0x08,0x14,0x22,0x41 ; 75: 'K'
    DCB 0x7F,0x40,0x40,0x40,0x40 ; 76: 'L'
    DCB 0x7F,0x02,0x0C,0x02,0x7F ; 77: 'M'
    DCB 0x7F,0x04,0x08,0x10,0x7F ; 78: 'N'
    DCB 0x3E,0x41,0x41,0x41,0x3E ; 79: 'O'
    DCB 0x7F,0x09,0x09,0x09,0x06 ; 80: 'P'
    DCB 0x3E,0x41,0x51,0x21,0x5E ; 81: 'Q'
    DCB 0x7F,0x09,0x19,0x29,0x46 ; 82: 'R'
    DCB 0x46,0x49,0x49,0x49,0x31 ; 83: 'S'
    DCB 0x01,0x01,0x7F,0x01,0x01 ; 84: 'T'
    DCB 0x3F,0x40,0x40,0x40,0x3F ; 85: 'U'
    DCB 0x1F,0x20,0x40,0x20,0x1F ; 86: 'V'
    DCB 0x3F,0x40,0x38,0x40,0x3F ; 87: 'W'
    DCB 0x63,0x14,0x08,0x14,0x63 ; 88: 'X'
    DCB 0x07,0x08,0x70,0x08,0x07 ; 89: 'Y'
    DCB 0x61,0x51,0x49,0x45,0x43 ; 90: 'Z'
    DCB 0x00,0x7F,0x41,0x41,0x00 ; 91: '['
    DCB 0x02,0x04,0x08,0x10,0x20 ; 92: '\'
    DCB 0x00,0x41,0x41,0x7F,0x00 ; 93: ']'
    DCB 0x04,0x02,0x01,0x02,0x04 ; 94: '^'
    DCB 0x40,0x40,0x40,0x40,0x40 ; 95: '_'
    DCB 0x00,0x01,0x02,0x04,0x00 ; 96: '`'
    DCB 0x20,0x54,0x54,0x54,0x78 ; 97: 'a'
    DCB 0x7F,0x48,0x44,0x44,0x38 ; 98: 'b'
    DCB 0x38,0x44,0x44,0x44,0x20 ; 99: 'c'
    DCB 0x38,0x44,0x44,0x48,0x7F ; 100: 'd'
    DCB 0x38,0x54,0x54,0x54,0x18 ; 101: 'e'
    DCB 0x08,0x7E,0x09,0x01,0x02 ; 102: 'f'
    DCB 0x0C,0x52,0x52,0x52,0x3E ; 103: 'g'
    DCB 0x7F,0x08,0x04,0x04,0x78 ; 104: 'h'
    DCB 0x00,0x44,0x7D,0x40,0x00 ; 105: 'i'
    DCB 0x20,0x40,0x44,0x3D,0x00 ; 106: 'j'
    DCB 0x7F,0x10,0x28,0x44,0x00 ; 107: 'k'
    DCB 0x00,0x41,0x7F,0x40,0x00 ; 108: 'l'
    DCB 0x7C,0x04,0x78,0x04,0x78 ; 109: 'm'
    DCB 0x7C,0x08,0x04,0x04,0x78 ; 110: 'n'
    DCB 0x38,0x44,0x44,0x44,0x38 ; 111: 'o'
    DCB 0x7C,0x14,0x14,0x14,0x08 ; 112: 'p'
    DCB 0x08,0x14,0x14,0x18,0x7C ; 113: 'q'
    DCB 0x7C,0x08,0x04,0x04,0x08 ; 114: 'r'
    DCB 0x48,0x54,0x54,0x54,0x20 ; 115: 's'
    DCB 0x04,0x3F,0x44,0x40,0x20 ; 116: 't'
    DCB 0x3C,0x40,0x40,0x20,0x7C ; 117: 'u'
    DCB 0x1C,0x20,0x40,0x20,0x1C ; 118: 'v'
    DCB 0x3C,0x40,0x30,0x40,0x3C ; 119: 'w'
    DCB 0x44,0x28,0x10,0x28,0x44 ; 120: 'x'
    DCB 0x0C,0x50,0x50,0x50,0x3C ; 121: 'y'
    DCB 0x44,0x64,0x54,0x4C,0x44 ; 122: 'z'
    ALIGN

    END