        .ORG 0X0000
        JMP INICIO

INICIO:
        LDI R16,HIGH(RAMEND)
        OUT SPH,R16
        LDI R16,LOW(RAMEND)
        OUT SPL,R16

        LDI R16,(1<<DDB5)
        OUT DDRB,R16

;Inicio configuraci?n timer 1
        LDI R16,0
        STS TCCR1A,R16
        LDI R16,(1<<CS12)|(1<<CS10)
        STS TCCR1B,R16
        LDI R16,0
        STS TCCR1C,R16
        LDI R16,0
        STS TIMSK1,R16
        LDI R16,HIGH(34286)
        STS TCNT1H,R16
        LDI R16,LOW(34286)
        STS TCNT1L,R16
;Fin configuraci?n timer 1
        SEI

VOLVER:
        SBI PORTB,PORTB5
        CALL RETARDO2S
        CBI PORTB,PORTB5
        CALL RETARDO2S
        RJMP VOLVER

RETARDO2S:
        SBIS TIFR1,TOV1
        RJMP RETARDO2S
        SBI TIFR1,TOV1
        LDI R16,HIGH(34286)
        STS TCNT1H,R16
        LDI R16,LOW(34286)
        STS TCNT1L,R16
        RET
