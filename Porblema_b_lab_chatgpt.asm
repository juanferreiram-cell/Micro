; Columnas: C1 a C6 = PD2 a PD7, C7 = PB0, C8 = PB1
; Filas:    F1 a F4 = PB2 a PB5, F5 a F8 = PC0 a PC3

.include "m328pdef.inc"

.org 0x0000
    rjmp INICIO

.equ FILASB_OFF       = 0x3C   ; PB2 a PB5 (apagadas en '1')
.equ FILASC_OFF       = 0x0F   ; PC0 a PC3 (apagadas en '1')
.equ FRAMES_POR_PASO  = 40     ; velocidad: frames (?8 ms c/u) por paso de 1 bit
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

; Tabla de punteros (byte-address) a las figuras
FIGTAB:
    .dw (SONRISA<<1),(TRISTE<<1),(CORAZON<<1),(ROMBO<<1),(ALIEN<<1)

; ===== Variables en registros =====
; r20 = patr?n de columnas
; r21 = ?ndice de fila activa (0..7)
; r22 = contador de fila dentro del frame (0..7)
.def SHIFTX   = r23   ; 0..7: corrimiento actual
.def FRMCNT   = r24   ; frames restantes hasta el pr?ximo paso
.def FIGIDX   = r19   ; 0..NUMFIG-1 ?ndice de figura actual

; -------------------------------------------------------
INICIO:
    ; Stack
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16
    ldi  r16, LOW(RAMEND)
    out  SPL, r16
    clr  r1

    ; GPIO: columnas salida
    in   r16, DDRD
    ori  r16, 0b11111100      ; PD2..PD7 salida
    out  DDRD, r16
    ldi  r16, 0b00111111      ; PB0..PB5 salida (C7,C8 y F1..F4)
    out  DDRB, r16
    in   r16, DDRC
    ori  r16, 0b00001111      ; PC0..PC3 salida (F5..F8)
    out  DDRC, r16

    ; Columnas LOW, filas HIGH (apagadas)
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

    ; Timer0 en CTC para 1 ms
    ldi  r16, (1<<WGM01)
    out  TCCR0A, r16
    ldi  r16, 249             ; 16 MHz / 64 = 250 kHz -> 1 ms
    out  OCR0A, r16
    ldi  r16, (1<<CS01)|(1<<CS00)
    out  TCCR0B, r16

    ; ---- Inicializaci?n de scroll continuo ----
    clr  FIGIDX               ; empezamos en la primera figura
    rcall CARGAR_FIGURA       ; X = base de figura actual (r26:r27)
    clr  SHIFTX               ; sin corrimiento
    ldi  FRMCNT, FRAMES_POR_PASO
    clr  r22                  ; fila = 0

; -------------------------------------------------------
; Bucle continuo: barrido + scroll + cambio inmediato de figura al completar 8 pasos
MAIN_LOOP:
    ; Si es la primera fila del frame, Z := base de figura (X)
    tst  r22
    brne NoSetZ
    movw r30, r26
NoSetZ:

    ; --- Barrer una fila ---
    rcall APAGAR_FILAS
    lpm  r20, Z+              ; patr?n de la fila actual
    mov  r18, SHIFTX
    rcall SHIFT_DER           ; desplazamiento hacia la DERECHA (l?gico)
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; --- Avanzar fila ---
    inc  r22
    cpi  r22, 8
    brlo MAIN_LOOP            ; quedan filas por barrer

    ; --- Fin de frame: gestionar scroll y posible cambio de figura ---
    clr  r22                  ; reiniciar fila para el pr?ximo frame

    dec  FRMCNT
    brne MAIN_LOOP            ; todav?a no toca mover 1 bit

    ; mover 1 bit
    ldi  FRMCNT, FRAMES_POR_PASO
    inc  SHIFTX
    andi SHIFTX, 0x07         ; 0..7

    brne MAIN_LOOP            ; si no se gdio la vueltah, seguimos con la misma figura

    ; SHIFTX volvi? a 0 => pasar a la siguiente figura inmediatamente
    inc  FIGIDX
    cpi  FIGIDX, NUMFIG
    brlo NextIdxOK
    clr  FIGIDX               
NextIdxOK:
    rcall CARGAR_FIGURA       
    rjmp MAIN_LOOP


CARGAR_FIGURA:
    ; Z := FIGTAB + (FIGIDX*2)
    ldi  ZL, low(FIGTAB<<1)
    ldi  ZH, high(FIGTAB<<1)
    mov  r18, FIGIDX
    lsl  r18                  
    add  ZL, r18
    adc  ZH, r1               

    
    lpm  r0, Z+               
    mov  r26, r0              
    lpm  r0, Z                
    mov  r27, r0              
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
    
    mov  r16, r20
    andi r16, 0x3F
    lsl  r16
    lsl  r16
    in   r17, PORTD
    andi r17, 0x03
    or   r17, r16
    out  PORTD, r17
    
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
    ldi  r19, 0x04            ; PB2
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


SHIFT_DER:
    tst  r18
    breq SD_fin
SD_loop:
    lsr  r20
    dec  r18
    brne SD_loop
SD_fin:
    ret


ESPERAR_1MS:
    ldi  r16, (1<<OCF0A)
    out  TIFR0, r16
W1:
    in   r17, TIFR0
    sbrs r17, OCF0A
    rjmp W1
    ret
