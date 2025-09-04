; Columnas: C1 a C6 = PD2 a PD7, C7 = PB0, C8 = PB1
; Filas:    F1 a F4 = PB2 a PB5, F5 a F8 = PC0 a PC3
; MCU: ATmega328P @ 16 MHz

.include "m328pdef.inc"

.org 0x0000
    rjmp INICIO

.equ FILASB_OFF       = 0x3C   ; PB2..PB5 en '1' = filas apagadas
.equ FILASC_OFF       = 0x0F   ; PC0..PC3 en '1' = filas apagadas
.equ FRAMES_POR_PASO  = 30     ; ~8 ms por frame => 80 ms por paso (scroll)
.equ NUMFIG           = 5

; ===== Letras para "HELLO" usando tus etiquetas =====
; Cada .db es una fila (8 filas), bit=1 enciende LED de esa columna.
; (MSB ≈ columna izquierda). Si se ve espejado, avisá y te paso los bytes invertidos.

SONRISA:    ; H
    .db 0x42,0x42,0x42,0x7E,0x42,0x42,0x42,0x00

TRISTE:     ; E
    .db 0x7E,0x02,0x02,0x7C,0x02,0x02,0x7E,0x00

CORAZON:    ; L
    .db 0x02,0x02,0x02,0x02,0x02,0x02,0x7E,0x00

ROMBO:      ; L
    .db 0x02,0x02,0x02,0x02,0x02,0x02,0x7E,0x00

ALIEN:      ; O
    .db 0x3C,0x42,0x42,0x42,0x42,0x42,0x3C,0x00

; Punteros a figuras (byte-address en flash)
FIGTAB:
    .dw (SONRISA<<1),(TRISTE<<1),(CORAZON<<1),(ROMBO<<1),(ALIEN<<1)

; ===== Registros =====
; r20 = patrón de columnas para la fila actual
; r21 = índice de fila activa (0..7)
; r22 = contador de fila dentro del frame (0..7)
.def SHIFTX   = r23   ; corrimiento 0..7 (derecha)
.def FRMCNT   = r24   ; frames restantes para el próximo paso
.def FIGIDX   = r19   ; índice de figura actual (0..NUMFIG-1)
.def SHCNT    = r25   ; ***contador temporal de shifts (no pisar FIGIDX)***

; X = r26:r27 -> base figura actual (byte addr en flash)
; Y = r28:r29 -> base figura siguiente (byte addr en flash)
; Z = r30:r31 -> puntero temporal de lectura LPM

; -------------------------------------------------------
INICIO:
    ; Stack
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16
    clr  r1                      ; r1 = 0 por convención

    ; GPIO: columnas y filas como salida
    in   r16, DDRD
    ori  r16, 0b11111100         ; PD2..PD7 salida (C1..C6)
    out  DDRD, r16
    ldi  r16, 0b00111111         ; PB0..PB5 salida (C7,C8 y F1..F4)
    out  DDRB, r16
    in   r16, DDRC
    ori  r16, 0b00001111         ; PC0..PC3 salida (F5..F8)
    out  DDRC, r16

    ; Columnas LOW (apagadas), Filas HIGH (apagadas)
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

    ; Timer0 CTC a 1 ms (16 MHz, prescaler 64, OCR0A=249)
    ldi  r16, (1<<WGM01)
    out  TCCR0A, r16
    ldi  r16, 249
    out  OCR0A, r16
    ldi  r16, (1<<CS01)|(1<<CS00)
    out  TCCR0B, r16

    ; Scroll: cargar figuras y comenzar
    clr  FIGIDX
    rcall CARGAR_FIGURA_Y_SIGUIENTE   ; X=actual, Y=siguiente
    ldi  SHIFTX, 0
    ldi  FRMCNT, FRAMES_POR_PASO
    clr  r22

; -------------------------------------------------------
; MAIN_LOOP estable: scroll a la derecha con solapado (A >> s) | (B << (8 - s))
MAIN_LOOP:
    rcall APAGAR_FILAS

    ; --- A: byte de la figura actual (fila r22) ---
    movw r30, r26
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r20, Z              ; r20 = A

    ; --- B: byte de la figura siguiente (misma fila) ---
    movw r30, r28
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z               ; r0 = B

    ; ---- Componer: pat = (A >> s) | (B << (8 - s)), s = SHIFTX (0..7) ----
    mov  r18, SHIFTX         ; r18 = s

    ; r20 = A >> s
    tst  r18
    breq A_done
A_sr:
    lsr  r20
    dec  r18
    brne A_sr
A_done:

    ; r0 = B << (8 - s)   ; usar SHCNT=r25 para NO pisar FIGIDX=r19
    ldi  SHCNT, 8
    sub  SHCNT, SHIFTX       ; SHCNT = 8 - s  (8..1)
    tst  SHCNT
    breq B_done              ; si s=8 (no ocurre aquí), nada
B_sl:
    lsl  r0
    dec  SHCNT
    brne B_sl
B_done:

    or   r20, r0             ; combinar

    ; ---- Salida de esta fila ----
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; ---- Siguiente fila ----
    inc  r22
    cpi  r22, 8
    brlo MAIN_LOOP

    ; ===== Fin de frame =====
    clr  r22
    dec  FRMCNT
    brne MAIN_LOOP

    ; ---- Avance de scroll (s: 0..7) ----
    ldi  FRMCNT, FRAMES_POR_PASO
    inc  SHIFTX
    cpi  SHIFTX, 8
    brlo MAIN_LOOP           ; s=0..7 -> seguir

    ; s==8 -> pasar a la siguiente figura y reiniciar s=0 (sin pausa/repetición)
    clr  SHIFTX
    inc  FIGIDX
    cpi  FIGIDX, NUMFIG
    brlo NextOk
    clr  FIGIDX
NextOk:
    rcall CARGAR_FIGURA_Y_SIGUIENTE
    rjmp MAIN_LOOP

; ===== Rutinas =====

; X = base de FIGIDX, Y = base de (FIGIDX+1) mod NUMFIG (byte addresses en flash)
CARGAR_FIGURA_Y_SIGUIENTE:
    ; X <- FIGIDX
    ldi  ZL, low(FIGTAB<<1)
    ldi  ZH, high(FIGTAB<<1)
    mov  r18, FIGIDX
    lsl  r18                      ; *2 (cada .dw son 2 bytes)
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z+                   ; low
    mov  r26, r0
    lpm  r0, Z                    ; high
    mov  r27, r0

    ; Y <- FIGIDX+1 (con wrap)
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
    lpm  r0, Z+                   ; low
    mov  r28, r0
    lpm  r0, Z                    ; high
    mov  r29, r0
    ret

; Apaga todas las filas (pone F1..F8 en '1')
APAGAR_FILAS:
    in   r16, PORTB
    ori  r16, FILASB_OFF
    out  PORTB, r16
    in   r16, PORTC
    ori  r16, FILASC_OFF
    out  PORTC, r16
    ret

; Salida de columnas según r20: bits0..5 -> PD2..PD7, bits6..7 -> PB0..PB1
PONER_COLUMNAS:
    ; Bits 0..5 -> PD2..PD7
    mov  r16, r20
    andi r16, 0x3F              ; b5..b0
    lsl  r16                    ; alinear a PD2..PD7
    lsl  r16
    in   r17, PORTD
    andi r17, 0x03              ; preservar PD0..PD1
    or   r17, r16
    out  PORTD, r17

    ; Bits 6..7 -> PB0..PB1
    mov  r16, r20
    andi r16, 0xC0              ; b7..b6
    lsr  r16                    ; llevarlos a b1..b0
    lsr  r16
    lsr  r16
    lsr  r16
    lsr  r16
    lsr  r16
    in   r17, PORTB
    andi r17, 0b11111100        ; preservar PB2..PB5 y PB6..PB7
    or   r17, r16
    out  PORTB, r17
    ret

; Activa una única fila (r21 = 0..7). Filas activas en LOW.
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
    com  r19                   ; bit activo en 0
    and  r18, r19
    in   r17, PORTC
    andi r17, 0b11110000
    or   r17, r18
    out  PORTC, r17
    rjmp FilaEnd

FilaB:
    ; F1..F4 en PORTB (PB2..PB5)
    ldi  r18, FILASB_OFF
    ldi  r19, 0x04             ; PB2
    mov  r20, r21
DESPLAZAR_PB:
    tst  r20
    breq FIN_DESPLAZAR_PB
    lsl  r19
    dec  r20
    rjmp DESPLAZAR_PB
FIN_DESPLAZAR_PB:
    com  r19                   ; bit activo en 0
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

; Espera bloqueante de 1 ms usando Timer0 CTC
ESPERAR_1MS:
    ldi  r16, (1<<OCF0A)
    out  TIFR0, r16            ; limpiar OCF0A
W1:
    in   r17, TIFR0
    sbrs r17, OCF0A
    rjmp W1
    ret
