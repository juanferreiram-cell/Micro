;
; Contador 0-9 con LUT y botones START/STOP
; ATmega328P (Arduino Uno)
; Conexiones:
;   a->D12=PB4, b->D11=PB3, c->D6=PD6, d->D5=PD5, e->D4=PD4, f->D3=PD3, g->D2=PD2
; (dp no usado)
;

.include "m328pdef.inc"

; 0 = c?todo com?n (1 enciende) | 1 = ?nodo com?n (0 enciende)
.equ DISPLAY_ANODO = 0

.org 0x0000
    rjmp start

;-----------------------------------------
; LUT en SRAM (separada por puertos)
;-----------------------------------------
.equ LUTB_ADDR  = 0x0100      ; PORTB: a,b (PB4,PB3)
.equ LUTD_ADDR  = 0x0110      ; PORTD: c..g (PD6..PD2)

; Botones
.equ BTN_START  = 0           ; PC0 (A0)
.equ BTN_STOP   = 1           ; PC1 (A1)

; M?scaras de pines usados
.equ MASKB     = 0b00011000   ; PB4 (a), PB3 (b)
.equ MASKD     = 0b01111100   ; PD6..PD2 (c..g)
.equ INV_MASKB = 0b11100111   ; ~MASKB
.equ INV_MASKD = 0b10000011   ; ~MASKD

; Registros
; r1  : SIEMPRE 0
; r16 : contador
; r18 : m?scara bot?n (debounce)
; r19 : lectura PINC
; r20 : trabajo general
; r21 : d?gito 0..9
; r22 : patr?n PORTB
; r23 : patr?n PORTD
; r24 : delay (200ms)
; r25 : tmp para RMW de puertos
; r28:r29 (Y): puntero

;-----------------------------------------
; Configuraci?n
;-----------------------------------------
configurar:
    ; DDRB: PB4, PB3 como salida
    in      r20, DDRB
    ori     r20, MASKB
    out     DDRB, r20

    ; DDRD: PD6..PD2 como salida
    in      r20, DDRD
    ori     r20, MASKD
    out     DDRD, r20

    ; Botones con pull-up en PC0 y PC1
    clr     r20
    out     DDRC, r20
    ldi     r20, (1<<BTN_START) | (1<<BTN_STOP)
    out     PORTC, r20

    rcall   guardar_codigos
    ret

;-----------------------------------------
; Antirrebote
;-----------------------------------------
debounce_esperar_press:
espera_press_0:
    in      r19, PINC
    and     r19, r18
    brne    espera_press_0
    rcall   delay_5ms
    in      r19, PINC
    and     r19, r18
    brne    espera_press_0
    ret

debounce_esperar_release:
espera_release_1:
    in      r19, PINC
    and     r19, r18
    breq    espera_release_1
    rcall   delay_5ms
    in      r19, PINC
    and     r19, r18
    breq    espera_release_1
    ret

;-----------------------------------------
; Delays (?16 MHz)
;-----------------------------------------
delay_5ms:
    ldi     r22, 65
d5ms_outer:
    ldi     r23, 255
d5ms_inner:
    dec     r23
    brne    d5ms_inner
    dec     r22
    brne    d5ms_outer
    ret

delay_200ms:
    ldi     r24, 255
d200ms_loop:
    rcall   delay_5ms
    dec     r24
    brne    d200ms_loop
    ret

;-----------------------------------------
; 7 segmentos
;-----------------------------------------
get_u:
    mov     r20, r16
    andi    r20, 0x0F
    mov     r21, r20
    ret

; Escribe d?gito r21 en PORTB/PORTD (solo bits usados)
set_7seg_u:
    ; --- LUT PORTB (a,b) ---
    ldi     r28, LOW(LUTB_ADDR)
    ldi     r29, HIGH(LUTB_ADDR)
    add     r28, r21
    adc     r29, r1
    ld      r22, Y             ; PB4..PB3

    ; --- LUT PORTD (c..g) ---
    ldi     r28, LOW(LUTD_ADDR)
    ldi     r29, HIGH(LUTD_ADDR)
    add     r28, r21
    adc     r29, r1
    ld      r23, Y             ; PD6..PD2

.if DISPLAY_ANODO
    ; invertir SOLO los bits usados (para ?nodo com?n)
    ldi     r25, MASKB
    eor     r22, r25
    ldi     r25, MASKD
    eor     r23, r25
.endif

    ; --- PORTB: RMW solo PB4,PB3 ---
    in      r25, PORTB
    andi    r25, INV_MASKB
    or      r25, r22
    out     PORTB, r25

    ; --- PORTD: RMW solo PD6..PD2 ---
    in      r25, PORTD
    andi    r25, INV_MASKD
    or      r25, r23
    out     PORTD, r25
    ret

;-----------------------------------------
; Cargar LUTs (c?todo com?n: 1 = encendido)
; LUTB: PB4(a), PB3(b)
; LUTD: PD6(c), PD5(d), PD4(e), PD3(f), PD2(g)
;-----------------------------------------
guardar_codigos:
    ; --- LUT PORTB (a,b) ---
    ldi     r28, LOW(LUTB_ADDR)
    ldi     r29, HIGH(LUTB_ADDR)
    ldi     r20, 0b00011000    ; 0: a b
    st      Y+, r20
    ldi     r20, 0b00001000    ; 1:   b
    st      Y+, r20
    ldi     r20, 0b00011000    ; 2: a b
    st      Y+, r20
    ldi     r20, 0b00011000    ; 3: a b
    st      Y+, r20
    ldi     r20, 0b00001000    ; 4:   b
    st      Y+, r20
    ldi     r20, 0b00010000    ; 5: a
    st      Y+, r20
    ldi     r20, 0b00010000    ; 6: a
    st      Y+, r20
    ldi     r20, 0b00011000    ; 7: a b
    st      Y+, r20
    ldi     r20, 0b00011000    ; 8: a b
    st      Y+, r20
    ldi     r20, 0b00011000    ; 9: a b
    st      Y+, r20

    ; --- LUT PORTD (c..g) ---
    ldi     r28, LOW(LUTD_ADDR)
    ldi     r29, HIGH(LUTD_ADDR)
    ldi     r20, 0b01111000    ; 0: c d e f
    st      Y+, r20
    ldi     r20, 0b01000000    ; 1: c
    st      Y+, r20
    ldi     r20, 0b00110100    ; 2:   d e   g
    st      Y+, r20
    ldi     r20, 0b01100100    ; 3: c d     g
    st      Y+, r20
    ldi     r20, 0b01001100    ; 4: c     f g
    st      Y+, r20
    ldi     r20, 0b01101100    ; 5: c d   f g
    st      Y+, r20
    ldi     r20, 0b01111100    ; 6: c d e f g
    st      Y+, r20
    ldi     r20, 0b01000000    ; 7: c
    st      Y+, r20
    ldi     r20, 0b01111100    ; 8: c d e f g
    st      Y+, r20
    ldi     r20, 0b01101100    ; 9: c d   f g
    st      Y+, r20
    ret

;-----------------------------------------
; Programa principal
;-----------------------------------------
start:
    ; Stack
    ldi     r16, HIGH(RAMEND)
    out     SPH, r16
    ldi     r16, LOW(RAMEND)
    out     SPL, r16

    ; r1 = 0 siempre
    clr     r1

    rcall   configurar

principal:
    ; Esperar START (PC0) con debounce
    ldi     r18, (1<<BTN_START)
    rcall   debounce_esperar_press
    rcall   debounce_esperar_release

    ; Contador a 0
    clr     r16

contando:
    rcall   get_u
    rcall   set_7seg_u

    ; STOP? (activo en 0)
    in      r20, PINC
    sbrc    r20, BTN_STOP
    rjmp    no_stop
    ldi     r18, (1<<BTN_STOP)
    rcall   debounce_esperar_press
    rcall   debounce_esperar_release
    rjmp    principal

no_stop:
    rcall   delay_200ms
    inc     r16
    cpi     r16, 10
    brlo    contando
    clr     r16
    rjmp    contando
