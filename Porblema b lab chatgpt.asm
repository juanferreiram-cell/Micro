; Columnas: C1 a C6 = PD2 a PD7, C7 = PB0, C8 = PB1
; Filas:    F1 a F4 = PB2 a PB5, F5 a F8 = PC0 a PC3

.include "m328pdef.inc"

.org 0x0000
    rjmp INICIO

.equ FILASB_OFF       = 0x3C   ; PB2 a PB5 (apagadas en '1')
.equ FILASC_OFF       = 0x0F   ; PC0 a PC3 (apagadas en '1')
.equ FRAMES_POR_PASO  = 10     ; velocidad: ~40 frames (8 ms c/u) por paso
.equ NUMFIG           = 5

; ===== Figuras (8x8) =====
SONRISA:
    .db 0x3C,0x42,0xA5,0x81,0xA5,0x99,0x42,0x3C
TRISTE:
    .db 0x3C,0x42,0xA5,0x81,0x99,0xA5,0x42,0x3C
CORAZON:
    .db 0x00,0x66,0xFF,0xFF,0xFF,0x7E,0x3C,0x18
ROMBO:
    .db 0x18,0x3C,0x7E,0xFF,0xFF,0x7E,0x3C,0x18
ALIEN:
    .db 0x3C,0x7E,0xDB,0xFF,0xFF,0x24,0x5A,0x81

; Punteros a figuras (byte-address en flash)
FIGTAB:
    .dw (SONRISA<<1),(TRISTE<<1),(CORAZON<<1),(ROMBO<<1),(ALIEN<<1)

; ===== Registros de trabajo =====
; r20 = patrón de columnas a mostrar
; r21 = índice de fila activa (0..7)
; r22 = contador de fila dentro del frame (0..7)
.def SHIFTX   = r23   ; 0..7: corrimiento actual
.def FRMCNT   = r24   ; frames hasta el próximo paso
.def FIGIDX   = r19   ; índice figura actual (0..NUMFIG-1)

; X = r26:r27 -> base figura actual (byte addr)
; Y = r28:r29 -> base figura siguiente (byte addr)
; Z = r30:r31 -> puntero temporal de lectura LPM

; -------------------------------------------------------
INICIO:
    ; Stack
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16
    clr  r1

    ; GPIO columnas y filas
    in   r16, DDRD
    ori  r16, 0b11111100      ; PD2..PD7 salida (C1..C6)
    out  DDRD, r16
    ldi  r16, 0b00111111      ; PB0..PB5 salida (C7,C8 y F1..F4)
    out  DDRB, r16
    in   r16, DDRC
    ori  r16, 0b00001111      ; PC0..PC3 salida (F5..F8)
    out  DDRC, r16

    ; Columnas LOW, Filas HIGH (apagado)
    in   r16, PORTD
    andi r16, 0b00000011
    out  PORTD, r16
    in   r16, PORTB
    andi r16, 0b11000000
    ori  r16, FILASB_OFF
    out  PORTB, r16
    in   r16, PORTC
    andi r16, 0b11110000
    ori  r16, FILASC_OFF
    out  PORTC, r16

    ; Timer0 CTC a 1 ms
    ldi  r16, (1<<WGM01)
    out  TCCR0A, r16
    ldi  r16, 249
    out  OCR0A, r16
    ldi  r16, (1<<CS01)|(1<<CS00)
    out  TCCR0B, r16

    ; Scroll
    clr  FIGIDX
    rcall CARGAR_FIGURA_Y_SIGUIENTE   ; X=actual, Y=siguiente
    ldi  SHIFTX, 0          ; Empezamos sin desplazamiento
    ldi  FRMCNT, FRAMES_POR_PASO
    clr  r22

; -------------------------------------------------------
; Barrido + scroll suave (combina actual y siguiente)
MAIN_LOOP:
    ; --- Desactivar filas antes de cargar patrón ---
    rcall APAGAR_FILAS

    ; r22 = fila 0..7
    ; A: Z = X + r22
    movw r30, r26
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r20, Z              ; r20 = byte de figura actual (A)

    ; B: Z = Y + r22
    movw r30, r28
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z               ; r0 = byte de figura siguiente (B)

    ; --- Componer desplazamiento a IZQUIERDA: (A<<s) | (B>>(8-s)) ---
    mov  r18, SHIFTX
    tst  r18
    breq NoShift             ; s=0 => r20 = A tal cual

    ; r20 <<= s
    mov  r19, r20            ; Copia de A para desplazar
    ldi  r17, 8
    sub  r17, r18            ; r17 = 8 - s
ShiftLoop:
    lsl  r19                 ; Desplazar A a la izquierda
    lsr  r0                  ; Desplazar B a la derecha
    dec  r18
    brne ShiftLoop

    mov  r20, r19            ; Combinar resultados
    or   r20, r0
NoShift:

    ; --- Salida ---
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; --- Próxima fila ---
    inc  r22
    cpi  r22, 8
    brlo MAIN_LOOP

    ; ===== Fin de frame =====
    clr  r22
    dec  FRMCNT
    brne MAIN_LOOP

    ; Avanzar el desplazamiento
    ldi  FRMCNT, FRAMES_POR_PASO
    inc  SHIFTX
    cpi  SHIFTX, 8
    brlo MAIN_LOOP           ; Continuar si aún no llegamos a 8

    ; Cambiar a la siguiente figura cuando SHIFTX llega a 8
    inc  FIGIDX
    cpi  FIGIDX, NUMFIG
    brlo NextOk
    clr  FIGIDX
NextOk:
    rcall CARGAR_FIGURA_Y_SIGUIENTE
    ldi  SHIFTX, 0           ; Reiniciar desplazamiento
    rjmp MAIN_LOOP

; ===== Rutinas =====

; X = base de FIGIDX, Y = base de (FIGIDX+1) mod NUMFIG
CARGAR_FIGURA_Y_SIGUIENTE:
    ; X <- FIGIDX
    ldi  ZL, low(FIGTAB<<1)
    ldi  ZH, high(FIGTAB<<1)
    mov  r18, FIGIDX
    lsl  r18                      ; *2
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z+
    mov  r26, r0
    lpm  r0, Z
    mov  r27, r0

    ; Y <- FIGIDX+1 (wrap)
    mov  r18, FIGIDX
    inc  r18
    cpi  r18, NUMFIG
    brlo idx_ok
    clr  r18
idx_ok:
    ldi  ZL, low(FIGTAB<<1)
    ldi  ZH, high(FIGTAB<<1)
    lsl  r18
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z+
    mov  r28, r0
    lpm  r0, Z
    mov  r29, r0
    ret

APAGAR_FILAS:
    in   r16, PORTB
    ori  r16, FILASB_OFF
    out  PORTB, r16
    in   r16, PORTC
    ori  r16, FILASC_OFF
    out  PORTC, r16
    ret

PONER_COLUMNAS:
    ; Bits 0..5 -> PD2..PD7
    mov  r16, r20
    andi r16, 0x3F
    lsl  r16
    lsl  r16
    in   r17, PORTD
    andi r17, 0x03
    or   r17, r16
    out  PORTD, r17

    ; Bits 6..7 -> PB0..PB1
    mov  r16, r20
    andi r16, 0xC0
    lsr  r16
    lsr  r16
    lsr  r16
    lsr  r16
    lsr  r16
    lsr  r16
    in   r17, PORTB
    andi r17, 0b11111100
    or   r17, r16
    out  PORTB, r17
    ret

ACTIVAR_FILA:
    push r18
    push r19
    push r20
    cpi  r21, 4
    brlt FilaB

    ; F5..F8 en PORTC (PC0..PC3)
    subi r21, 4
    ldi  r18, FILASC_OFF
    ldi  r19, 0x01
    mov  r20, r21
DESPLAZAR_PC:
    tst  r20
    breq FIN_DESPLAZAR_PC
    lsl  r19
    dec  r20
    rjmp DESPLAZAR_PC
FIN_DESPLAZAR_PC:
    com  r19
    and  r18, r19
    in   r17, PORTC
    andi r17, 0b11110000
    or   r17, r18
    out  PORTC, r17
    rjmp FilaEnd

FilaB:
    ; F1..F4 en PORTB (PB2..PB5)
    ldi  r18, FILASB_OFF
    ldi  r19, 0x04
    mov  r20, r21
DESPLAZAR_PB:
    tst  r20
    breq FIN_DESPLAZAR_PB
    lsl  r19
    dec  r20
    rjmp DESPLAZAR_PB
FIN_DESPLAZAR_PB:
    com  r19
    and  r18, r19
    in   r17, PORTB
    andi r17, 0b11000011
    or   r17, r18
    out  PORTB, r17

FilaEnd:
    pop  r20
    pop  r19
    pop  r18
    ret

ESPERAR_1MS:
    ldi  r16, (1<<OCF0A)
    out  TIFR0, r16
W1:
    in   r17, TIFR0
    sbrs r17, OCF0A
    rjmp W1
    ret