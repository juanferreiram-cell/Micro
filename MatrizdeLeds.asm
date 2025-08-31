; ATmega328P + MAX7219 (8x8)
; INT0 (PD2): siguiente letra
; INT1 (PD3): letra anterior
; PB3 MOSI, PB5 SCK, PB2 SS/LOAD

.INCLUDE "m328pdef.inc"

; ---------- Vectores ----------
.ORG 0x0000
RJMP RESET
.ORG 0x0002
RJMP INT0_ISR
.ORG 0x0004
RJMP INT1_ISR

; ---------- RAM ----------
.DSEG
.ORG 0x0100
cur_idx: .BYTE 1          ; 0..12

; ---------- CODE ----------
.CSEG

; Registros MAX7219
.EQU REG_DECODE   = 0x09
.EQU REG_INTENS   = 0x0A
.EQU REG_SCANLIM  = 0x0B
.EQU REG_SHUTDWN  = 0x0C
.EQU REG_DISPTEST = 0x0F

RESET:
    ; Stack
    LDI  R16, HIGH(RAMEND)
    OUT  SPH, R16
    LDI  R16, LOW(RAMEND)
    OUT  SPL, R16
    CLR  R1

    ; PORTB salida (usamos PB2 PB3 PB5)
    LDI  R16, 0xFF
    OUT  DDRB, R16
    SBI  PORTB, 2              ; LOAD alto

    ; Pull-ups INT0/INT1
    SBI  PORTD, 2
    SBI  PORTD, 3

    ; SPI maestro fosc/16
    LDI  R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT  SPCR, R16
    LDI  R16, 0x00
    OUT  SPSR, R16

    ; MAX7219 init
    LDI  R16, REG_DECODE    ; decode off
    LDI  R17, 0x00
    RCALL MaxWrite
    LDI  R16, REG_INTENS    ; brillo
    LDI  R17, 0x04
    RCALL MaxWrite
    LDI  R16, REG_SCANLIM   ; 8 filas
    LDI  R17, 0x07
    RCALL MaxWrite
    LDI  R16, REG_DISPTEST  ; test off
    LDI  R17, 0x00
    RCALL MaxWrite
    LDI  R16, REG_SHUTDWN   ; normal
    LDI  R17, 0x01
    RCALL MaxWrite
    RCALL ClearDisplay

    ; indice inicial
    LDI  R16, 0
    STS  cur_idx, R16
    RCALL ShowCurrent

    ; INT0/INT1 (flanco ascendente)
    LDI  R16, 0x03
    OUT  EIMSK, R16
    LDI  R16, 0x0F
    STS  EICRA, R16

    SEI

MAIN:
    RJMP MAIN

; ---------- ISR INT0: siguiente ----------
INT0_ISR:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R20
    PUSH R21
    PUSH R24
    PUSH R25
    PUSH R30
    PUSH R31
    IN   R16, SREG
    PUSH R16

    LDS  R16, cur_idx
    INC  R16
    CPI  R16, 13
    BRLO INT0_keep
    LDI  R16, 0
INT0_keep:
    STS  cur_idx, R16
    RCALL ShowCurrent
    RCALL Mseg            ; antirrebote simple

    POP  R16
    OUT  SREG, R16
    POP  R31
    POP  R30
    POP  R25
    POP  R24
    POP  R21
    POP  R20
    POP  R18
    POP  R17
    POP  R16
    RETI

; ---------- ISR INT1: anterior ----------
INT1_ISR:
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R20
    PUSH R21
    PUSH R24
    PUSH R25
    PUSH R30
    PUSH R31
    IN   R16, SREG
    PUSH R16

    LDS  R16, cur_idx
    TST  R16
    BRNE INT1_dec
    LDI  R16, 12
    RJMP INT1_store
INT1_dec:
    DEC  R16
INT1_store:
    STS  cur_idx, R16
    RCALL ShowCurrent
    RCALL Mseg

    POP  R16
    OUT  SREG, R16
    POP  R31
    POP  R30
    POP  R25
    POP  R24
    POP  R21
    POP  R20
    POP  R18
    POP  R17
    POP  R16
    RETI

; ---------- Mostrar letra seg?n cur_idx (0..12) ----------
; Mensaje fijo: "YO AMO DORMIR"
; 0:Y 1:O 2:SP 3:A 4:M 5:O 6:SP 7:D 8:O 9:R 10:M 11:I 12:R
; ---------- Mostrar letra seg?n cur_idx (0..12) ----------
; Mensaje fijo: "YO AMO DORMIR"
; 0:Y 1:O 2:SP 3:A 4:M 5:O 6:SP 7:D 8:O 9:R 10:M 11:I 12:R
ShowCurrent:
    LDS  R16, cur_idx

    CPI  R16, 0
    BRNE sc1
    RJMP Draw_Y
sc1:
    CPI  R16, 1
    BRNE sc2
    RJMP Draw_O
sc2:
    CPI  R16, 2
    BRNE sc3
    RJMP Draw_SP
sc3:
    CPI  R16, 3
    BRNE sc4
    RJMP Draw_A
sc4:
    CPI  R16, 4
    BRNE sc5
    RJMP Draw_M
sc5:
    CPI  R16, 5
    BRNE sc6
    RJMP Draw_O
sc6:
    CPI  R16, 6
    BRNE sc7
    RJMP Draw_SP
sc7:
    CPI  R16, 7
    BRNE sc8
    RJMP Draw_D
sc8:
    CPI  R16, 8
    BRNE sc9
    RJMP Draw_O
sc9:
    CPI  R16, 9
    BRNE sc10
    RJMP Draw_R
sc10:
    CPI  R16, 10
    BRNE sc11
    RJMP Draw_M
sc11:
    CPI  R16, 11
    BRNE sc12
    RJMP Draw_I
sc12:
    ; default = 12
    RJMP Draw_R
    RET        ; (nunca se ejecuta; OK dejarlo)


; ---------- Rutinas de dibujo (8 filas) ----------
; Helper: escribe r17 en fila r21, incrementa r21
WriteRow:
    MOV  R16, R21
    RCALL MaxWrite
    INC  R21
    RET

Draw_SP:
    LDI  R21, 1
    LDI  R17, 0x00  ; fila1
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    LDI  R17, 0x00  ; fila8
    RCALL WriteRow
    RET

Draw_A:
    LDI  R21, 1
    LDI  R17, 0x38
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x7C
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_D:
    LDI  R21, 1
    LDI  R17, 0x78
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x42
    RCALL WriteRow
    LDI  R17, 0x42
    RCALL WriteRow
    LDI  R17, 0x42
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x78
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_I:
    LDI  R21, 1
    LDI  R17, 0x7C
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x7C
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_M:
    LDI  R21, 1
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x6C
    RCALL WriteRow
    LDI  R17, 0x54
    RCALL WriteRow
    LDI  R17, 0x54
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_O:
    LDI  R21, 1
    LDI  R17, 0x38
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x38
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_R:
    LDI  R21, 1
    LDI  R17, 0x78
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x78
    RCALL WriteRow
    LDI  R17, 0x48
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

Draw_Y:
    LDI  R21, 1
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x44
    RCALL WriteRow
    LDI  R17, 0x28
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x10
    RCALL WriteRow
    LDI  R17, 0x00
    RCALL WriteRow
    RET

; ---------- Utilidades ----------
MaxWrite:                 ; R16=registro(1..8/ctrl), R17=dato
    CBI  PORTB, 2         ; LOAD bajo
    MOV  R24, R16
    RCALL SPI_Send
    MOV  R24, R17
    RCALL SPI_Send
    SBI  PORTB, 2         ; LOAD alto
    RET

SPI_Send:                 ; envia R24
    OUT  SPDR, R24
wait:
    IN   R25, SPSR
    SBRS R25, SPIF
    RJMP wait
    RET

ClearDisplay:
    LDI  R21, 1
cl:
    LDI  R16, 0
    MOV  R17, R16
    MOV  R16, R21
    RCALL MaxWrite
    INC  R21
    CPI  R21, 9
    BRNE cl
    RET

; Retardo breve (antirrebote/pausa)
Mseg:
    LDI  R21, 21
    LDI  R22, 75
    LDI  R23, 189
L1:
    DEC  R23
    BRNE L1
    DEC  R22
    BRNE L1
    DEC  R21
    BRNE L1
    NOP
    RET

