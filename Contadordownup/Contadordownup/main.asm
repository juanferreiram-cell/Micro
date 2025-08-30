;
; Contadordownup.asm
;
; Created: 30/8/2025 16:06:31
; Author : Juan Manuel Ferreira
; CI: 5.488.807-8

; En este codigo se define un contador up/down para un display de 7 segmentos 
;Donde se estable los pines del 1 al 7 para el display para que sea mucho mas facil declarar un registro como salida
; Sin necedidad de acceder a los pines PB
; El 8 para el DP que parpadeara cada 1 s
; Y por ultimo los pines 9 y 10 para los pulsadores donde tambien se toma en cuenta para que no haya Deboucing


.include "m328pdef.inc"

.org 0x0000
    rjmp Inicio
.org 0x0002
    rjmp INT0_dummy
.org 0x0004
    rjmp INT1_dummy
.org 0x0006                 
    rjmp PCINT0_ISR
.org 0x001A                 
    rjmp TIMER1_OVF_ISR


Inicio:
    
    ldi  r16, LOW(RAMEND)
    out  SPL, r16
    ldi  r16, HIGH(RAMEND)
    out  SPH, r16

    
    ldi  r16, 0x7F          
    out  DDRD, r16
    ldi  r21, 0x00
    out  PORTD, r21        

    
    sbi  DDRB, DDB0
    cbi  PORTB, PORTB0

    
    cbi  DDRB, DDB1
    cbi  DDRB, DDB2
    sbi  PORTB, PORTB1
    sbi  PORTB, PORTB2

    
    ldi  r16, (1<<PCIE0)
    sts  PCICR, r16
    ldi  r16, (1<<PCINT1) | (1<<PCINT2)
    sts  PCMSK0, r16
    ldi  r16, (1<<PCIF0)          
    sts  PCIFR, r16

    
    ldi  r16, 0
    sts  TCCR1A, r16
    ldi  r16, (1<<CS12)           
    sts  TCCR1B, r16
    ldi  r16, 0
    sts  TCCR1C, r16
    ldi  r16, HIGH(3036)
    sts  TCNT1H, r16
    ldi  r16, LOW(3036)
    sts  TCNT1L, r16
    ldi  r16, (1<<TOIE1)          
    sts  TIMSK1, r16

    
    ldi  r16, 0x00
    out  GPIOR0, r16

    sei

Main:
    
    in   r16, GPIOR0
    sbrs r16, 0               
    rjmp  CheckDown
    cbi  GPIOR0, 0            
    rcall ContarUp

CheckDown:
    in   r16, GPIOR0
    sbrs r16, 1               
    rjmp  Main
    cbi  GPIOR0, 1
    rcall ContarDown
    rjmp  Main

PCINT0_ISR:
    in   r17, PINB
    sbrs r17, 1              
    sbi  GPIOR0, 0            
    sbrs r17, 2               
    sbi  GPIOR0, 1            
    reti

TIMER1_OVF_ISR:
    
    ldi  r16, HIGH(3036)
    sts  TCNT1H, r16
    ldi  r16, LOW(3036)
    sts  TCNT1L, r16
    sbi  PINB, PINB0
    reti

INT0_dummy: reti
INT1_dummy: reti


DP:
    andi r21, 0x7F           
    out  PORTD, r21
    ret


ContarUp:
    ldi r21, 0x3F ;0 
    rcall DP
    rcall Delay
    ldi r21, 0x06 ;1
    rcall DP
    rcall Delay
    ldi r21, 0x5B ;2
    rcall DP
    rcall Delay
    ldi r21, 0x4F ;3
    rcall DP
    rcall Delay
    ldi r21, 0x66 ;4
    rcall DP
    rcall Delay
    ldi r21, 0x6D ;5
    rcall DP
    rcall Delay
    ldi r21, 0x7D ;6
    rcall DP
    rcall Delay
    ldi r21, 0x07 ;7
    rcall DP
    rcall Delay
    ldi r21, 0x7F ;8  
    rcall DP
    rcall Delay
    ldi r21, 0x6F ;9
    rcall DP
    rcall Delay
    ret

; Conteo 9¨0
ContarDown:
    ldi r21, 0x6F ;9
    rcall DP
    rcall Delay
    ldi r21, 0x7F ;8
    rcall DP
    rcall Delay
    ldi r21, 0x07 ;7
    rcall DP
    rcall Delay
    ldi r21, 0x7D ;6
    rcall DP
    rcall Delay
    ldi r21, 0x6D ;5
    rcall DP
    rcall Delay
    ldi r21, 0x66 ;4
    rcall DP
    rcall Delay
    ldi r21, 0x4F ;3
    rcall DP
    rcall Delay
    ldi r21, 0x5B ;2
    rcall DP
    rcall Delay
    ldi r21, 0x06 ;1
    rcall DP
    rcall Delay
    ldi r21, 0x3F ;0
    rcall DP
    rcall Delay
    ret


Delay:
    ldi r22, 100
    ldi r23, 255
Delay_L1:
    ldi r24, 255
Delay_L0:
    dec r24
    brne Delay_L0
    dec r23
    brne Delay_L1
    dec r22
    brne Delay_L1
    ret
