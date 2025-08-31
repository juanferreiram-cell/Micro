        .include "m328pdef.inc"

        .cseg
        .org    0x0000
        rjmp    INICIO

INICIO:
        ; --- Stack ---
        ldi     r16, high(RAMEND)
        out     SPH, r16
        ldi     r16, low(RAMEND)
        out     SPL, r16

        ; --- LED en PB5 como salida ---
        ldi     r16, (1<<DDB5)
        out     DDRB, r16

        ; --- Botones PD2 y PD4 entrada con pull-up (activo en bajo) ---
        cbi     DDRD, DDD2
        sbi     PORTD, PORTD2
        cbi     DDRD, DDD4
        sbi     PORTD, PORTD4

        ; --- Timer1: modo normal, prescaler = 1024 ---
        ldi     r16, 0
        sts     TCCR1A, r16
        ldi     r16, (1<<CS12)|(1<<CS10)   ; CS12=1, CS10=1 => /1024
        sts     TCCR1B, r16
        ldi     r16, 0
        sts     TCCR1C, r16
        ldi     r16, 0
        sts     TIMSK1, r16                 ; sin interrupciones

MAIN:
        ; Si PD2 = 0 -> 1 s
        sbic    PIND, PIND2      ; salta la pr?xima si PD2 est? en 0 (presionado)
        rjmp    VERIFICA_PD4        ; si PD2=1 (suelto), ir a revisar PD4
        rcall   RETARDOMEDIOS
        rjmp    BLINK

VERIFICA_PD4:
        ; Si PD4 = 0 -> 2 s
        sbic    PIND, PIND4
        rjmp    DEFAULT_DELAY    ; si PD4=1 (suelto), usar default
        rcall   RETARDO2S
        rjmp    BLINK

DEFAULT_DELAY:
        ; Ning?n bot?n presionado: 1 s
        rcall   RETARDO_DEFAULT1S

BLINK:
        sbi     PINB, PINB5      ; toggle LED en PB5
        rjmp    MAIN

; --------- Retardos con Timer1 ---------
; Orden correcto: limpiar TOV1 -> precargar TCNT1 -> esperar overflow -> ret

; ~1 s: cuentas = 15625 => precarga = 65536 - 15625 = 49911 (0xC2F7)

RETARDO_DEFAULT1S:
        ldi     r16, (1<<TOV1)
        out     TIFR1, r16               ; limpiar bandera overflow
        ldi     r16, high(49911)
        sts     TCNT1H, r16
        ldi     r16, low(49911)
        sts     TCNT1L, r16
WAIT1:
        in      r17, TIFR1
        sbrs    r17, TOV1
        rjmp    WAIT1
        ret

RETARDOMEDIOS:
        ldi     r16, (1<<TOV1)
        out     TIFR1, r16               ; limpiar bandera overflow
        ldi     r16, high(57725)
        sts     TCNT1H, r16
        ldi     r16, low(57725)
        sts     TCNT1L, r16
WAIT2:
        in      r17, TIFR1
        sbrs    r17, TOV1
        rjmp    WAIT1
        ret

; ~2 s: cuentas = 31250 => precarga = 34286 (0x85EE)
RETARDO2S:
        ldi     r16, (1<<TOV1)
        out     TIFR1, r16
        ldi     r16, high(34286)
        sts     TCNT1H, r16
        ldi     r16, low(34286)
        sts     TCNT1L, r16
WAIT3:
        in      r17, TIFR1
        sbrs    r17, TOV1
        rjmp    WAIT2
        ret
