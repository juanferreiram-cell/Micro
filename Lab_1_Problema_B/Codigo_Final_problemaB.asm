; ================== PROYECTO ?NICO: MONITOR SERIAL + MATRIZ 8x8 ==================
; ATmega328P @16 MHz, UART 9600 8N1
; Caso 1: Scroll de "MEGUSTA COMER ASADO" (con espacios) en matriz 8x8
; Caso 2..6: Figuras fijas ~para siempre (con salida por tecla)
; Caso 7: Secuencia de 5 figuras ~3 s c/u en bucle (con salida por tecla)

.include "m328pdef.inc"

.org 0x0000
    rjmp Inicio

; ------------------ UART ------------------
.equ F_CPU = 16000000
.equ baud  = 9600
.equ bps   = (F_CPU/16/baud) - 1

; ------------------ MATRIZ 8x8 (pines) ------------------
; Columnas: C1..C6 = PD2..PD7, C7=PB0, C8=PB1
; Filas:    F1..F4 = PB2..PB5, F5..F8 = PC0..PC3
.equ FILASB_OFF       = 0x3C   ; PB2..PB5 en '1' para apagar
.equ FILASC_OFF       = 0x0F   ; PC0..PC3 en '1' para apagar

; ------------------ Scroll (Caso 1) ------------------
.equ FRAMES_POR_PASO  = 10     ; a menor n?mero, m?s r?pido
.equ NUMFIG           = 21     ; cantidad de caracteres (incluye espacios)

M:         .db 0x81, 0xC3, 0xA5, 0x99, 0x81, 0x81, 0x81, 0x81
E:         .db 0x7F, 0x01, 0x01, 0x01, 0x1F, 0x01, 0x01, 0x7F
ESPACIO:   .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
G:         .db 0x7F, 0x01, 0x01, 0x01, 0x79, 0x41, 0x41, 0x7F
U:         .db 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x7F
S:         .db 0x7F, 0x01, 0x01, 0x01, 0x7F, 0x40, 0x40, 0x7F
T:         .db 0x7F, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08
A:         .db 0x7E, 0x81, 0x81, 0xFF, 0x81, 0x81, 0x81, 0x81
ESPACIO1:  .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
C:         .db 0x7F, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x7F
O:         .db 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF
M1:        .db 0x81, 0xC3, 0xA5, 0x99, 0x81, 0x81, 0x81, 0x81
E2:        .db 0x7F, 0x01, 0x01, 0x01, 0x1F, 0x01, 0x01, 0x7F
R:         .db 0x7F, 0x41, 0x41, 0x41, 0x7F, 0x11, 0x21, 0x41
ESPACIO2:  .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
A1:        .db 0x7E, 0x81, 0x81, 0xFF, 0x81, 0x81, 0x81, 0x81
S1:        .db 0x7F, 0x01, 0x01, 0x01, 0x7F, 0x40, 0x40, 0x7F
A2:        .db 0x7E, 0x81, 0x81, 0xFF, 0x81, 0x81, 0x81, 0x81
D:         .db 0x1F, 0x21, 0x41, 0x41, 0x41, 0x41, 0x21, 0x1F
O1:        .db 0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF
ESPACIO3:  .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

; Tabla de punteros de las 21 ÅgfigurasÅh (caracteres)
FIGTAB:
    .dw (M<<1),(E<<1),(ESPACIO<<1),(G<<1),(U<<1),(S<<1),(T<<1),(A<<1),(ESPACIO1<<1), \
        (C<<1),(O<<1),(M1<<1),(E2<<1),(R<<1),(ESPACIO2<<1),(A1<<1),(S1<<1),(A2<<1), \
        (D<<1),(O1<<1),(ESPACIO3<<1)
; ============================================================================== 
;                                   INICIO
; ==============================================================================
Inicio:
    ; Stack
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16
    clr r1                   ; convenci?n ABI de AVR

    ; UART 9600@16MHz
    ldi r16, LOW(bps)
    ldi r17, HIGH(bps)
    rcall initUART

    ; Inicializar matriz (GPIO + Timer0 para 1ms)
    rcall initMatriz

    ; Mensaje de bienvenida
    ldi ZH, high(msgInicio<<1)
    ldi ZL, low(msgInicio<<1)
    rcall puts

; ============================================================================== 
;                               LOOP PRINCIPAL
; ==============================================================================
main_loop:
    rcall getc               ; espera un car?cter en r16

    cpi  r16, '1'
    breq caso_1
    cpi  r16, '2'
    breq caso_2
    cpi  r16, '3'
    breq caso_3
    cpi  r16, '4'
    breq caso_4
    cpi  r16, '5'
    breq caso_5
    cpi  r16, '6'
    breq caso_6
    cpi  r16, '7'
    breq caso_7
    rjmp caso_default

; ------------------ Casos ------------------
caso_1:
    ; Texto por Serial
    ldi ZH, high(txtUno<<1)
    ldi ZL, low(txtUno<<1)
    rcall puts
    ; Scroll del mensaje "MEGUSTA COMER ASADO" (una pasada completa)
    rcall MostrarScrollMensaje
    rjmp fin_switch

caso_2:
    ldi ZH, high(txtDos<<1)
    ldi ZL, low(txtDos<<1)
    rcall puts
    ; Cara feliz para SIEMPRE (sale si llega una tecla)
    ldi  ZL, low(SONRISA<<1)
    ldi  ZH, high(SONRISA<<1)
    rjmp MOSTRAR_SIEMPRE     ; no vuelve

caso_3:
    ldi ZH, high(txtTres<<1)
    ldi ZL, low(txtTres<<1)
    rcall puts
    ; Cara triste para SIEMPRE
    ldi  ZL, low(TRISTE<<1)
    ldi  ZH, high(TRISTE<<1)
    rjmp MOSTRAR_SIEMPRE

caso_4:
    ldi ZH, high(txtCuatro<<1)
    ldi ZL, low(txtCuatro<<1)
    rcall puts
    ; Rombo para SIEMPRE
    ldi  ZL, low(ROMBO<<1)
    ldi  ZH, high(ROMBO<<1)
    rjmp MOSTRAR_SIEMPRE

caso_5:
    ldi ZH, high(txtCinco<<1)
    ldi ZL, low(txtCinco<<1)
    rcall puts
    ; Coraz?n para SIEMPRE
    ldi  ZL, low(CORAZON<<1)
    ldi  ZH, high(CORAZON<<1)
    rjmp MOSTRAR_SIEMPRE

caso_6:
    ldi ZH, high(txtSeis<<1)
    ldi ZL, low(txtSeis<<1)
    rcall puts
    ; Alien para SIEMPRE
    ldi  ZL, low(ALIEN<<1)
    ldi  ZH, high(ALIEN<<1)
    rjmp MOSTRAR_SIEMPRE

caso_7:
    ldi ZH, high(txtSiete<<1)
    ldi ZL, low(txtSiete<<1)
    rcall puts
    ; Secuencia infinita (sale si llega una tecla durante el muestreo)
    rjmp MostrarSecuenciaCincoFigForever

caso_default:
    ; Eco del car?cter y nueva l?nea
    rcall putc         ; env?a r16 tal cual
    ldi  r16, 13
    rcall putc
    ldi  r16, 10
    rcall putc

fin_switch:
    rjmp main_loop

; ============================================================================== 
;                               RUTINAS UART
; ==============================================================================
initUART:
    sts UBRR0L, r16
    sts UBRR0H, r17
    ldi r16, (1<<RXEN0)|(1<<TXEN0)
    sts UCSR0B, r16
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)     ; 8N1
    sts UCSR0C, r16
    ret

putc:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp putc
    sts UDR0, r16
    ret

getc:
    lds r17, UCSR0A
    sbrs r17, RXC0
    rjmp getc
    lds r16, UDR0
    ret

puts:
    lpm r16, Z+
    cpi r16, 0
    breq fin_puts
    rcall putc
    rjmp puts
fin_puts:
    ret

; ============================================================================== 
;                           MENSAJES MONITOR SERIAL
; ==============================================================================
.cseg
msgInicio:
    .db "Bienvenido! Ingrese el numero para la accion que quiere realizar", 13, 10, \
        "1 - Mostrar el Mensaje", 13, 10, \
        "2 - Mostrar Cara Feliz", 13, 10, \
        "3 - Mostrar Cara Triste", 13, 10, \
        "4 - Mostrar Rombo", 13, 10, \
        "5 - Mostrar Corazon", 13, 10, \
        "6 - Mostrar Alien de Space Invaders", 13, 10, \
        "7 - Mostrar las 5 figuras cada 1 segundo", 13, 10, 0, 0   

txtUno:    .db "Has elegido MENSAJE",      13, 10, 0          
txtDos:    .db "Has elegido CARA FELIZ",      13, 10, 0, 0        
txtTres:   .db "Has elegido CARA TRISTE",     13, 10, 0, 0, 0       
txtCuatro: .db "Has elegido ROMBO",   13, 10, 0, 0, 0       
txtCinco:  .db "Has elegido CORAZON",    13, 10, 0          
txtSeis:   .db "Has elegido ALIEN DE SPACE INVADERS",     13, 10, 0, 0, 0       
txtSiete:  .db "Has elegido VER LAS 5 FIGURAS",    13, 10, 0

; ============================================================================== 
;                         MATRIZ 8x8 ? FIGURAS Y RUTINAS
; ==============================================================================

; ======= Figuras en flash =======
SONRISA: .db 0x3C,0x42,0xA5,0x81,0xA5,0x99,0x42,0x3C
TRISTE:  .db 0x3C,0x42,0xA5,0x81,0x99,0xA5,0x42,0x3C
CORAZON: .db 0x00,0x66,0xFF,0xFF,0xFF,0x7E,0x3C,0x18
ROMBO:   .db 0x18,0x3C,0x7E,0xFF,0xFF,0x7E,0x3C,0x18
ALIEN:   .db 0x3C,0x7E,0xDB,0xFF,0xFF,0x24,0x5A,0x81

; ======= Inicializaci?n matriz (GPIO + Timer0 a 1ms) =======
initMatriz:
    ; DDR: columnas y filas a salida (sin tocar PD0/PD1)
    in   r16, DDRD
    ori  r16, 0b11111100      ; PD2..PD7 out
    out  DDRD, r16
    ldi  r16, 0b00111111      ; PB0..PB5 out
    out  DDRB, r16
    in   r16, DDRC
    ori  r16, 0b00001111      ; PC0..PC3 out
    out  DDRC, r16

    ; Columnas LOW, Filas HIGH (apagadas)
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

    ; Timer0 CTC: ~1 ms @16 MHz (presc 64, OCR0A=249)
    ldi  r16, (1<<WGM01)
    out  TCCR0A, r16
    ldi  r16, 249
    out  OCR0A, r16
    ldi  r16, (1<<CS01)|(1<<CS00)
    out  TCCR0B, r16
    ret

; ======= Secuencia original (una pasada) ? se mantiene por si la quer?s =======
MostrarSecuenciaCincoFig:
    push r0
    push r16
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22
    push r24
    push r25
    push r26
    push r27
    push r28
    push r29
    push r30
    push r31

    ; 5 figuras ~3s c/u
    ldi  ZL, low(SONRISA<<1)
    ldi  ZH, high(SONRISA<<1)
    rcall MOSTRAR_3S

    ldi  ZL, low(TRISTE<<1)
    ldi  ZH, high(TRISTE<<1)
    rcall MOSTRAR_3S

    ldi  ZL, low(CORAZON<<1)
    ldi  ZH, high(CORAZON<<1)
    rcall MOSTRAR_3S

    ldi  ZL, low(ROMBO<<1)
    ldi  ZH, high(ROMBO<<1)
    rcall MOSTRAR_3S

    ldi  ZL, low(ALIEN<<1)
    ldi  ZH, high(ALIEN<<1)
    rcall MOSTRAR_3S

    pop  r31
    pop  r30
    pop  r29
    pop  r28
    pop  r27
    pop  r26
    pop  r25
    pop  r24
    pop  r22
    pop  r21
    pop  r20
    pop  r19
    pop  r18
    pop  r17
    pop  r16
    pop  r0
    ret

; ======= Opci?n 7 para SIEMPRE: 5 figuras ~3 s c/u en bucle =======
; Sale inmediatamente a main_loop si llega una tecla por UART.
MostrarSecuenciaCincoFigForever:
SecLoop:
    ; Chequeo r?pido de UART para permitir salir entre figuras
    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey7a
    rjmp main_loop
NoKey7a:
    ldi  ZL, low(SONRISA<<1)
    ldi  ZH, high(SONRISA<<1)
    rcall MOSTRAR_3S

    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey7b
    rjmp main_loop
NoKey7b:
    ldi  ZL, low(TRISTE<<1)
    ldi  ZH, high(TRISTE<<1)
    rcall MOSTRAR_3S

    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey7c
    rjmp main_loop
NoKey7c:
    ldi  ZL, low(CORAZON<<1)
    ldi  ZH, high(CORAZON<<1)
    rcall MOSTRAR_3S

    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey7d
    rjmp main_loop
NoKey7d:
    ldi  ZL, low(ROMBO<<1)
    ldi  ZH, high(ROMBO<<1)
    rcall MOSTRAR_3S

    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey7e
    rjmp main_loop
NoKey7e:
    ldi  ZL, low(ALIEN<<1)
    ldi  ZH, high(ALIEN<<1)
    rcall MOSTRAR_3S

    rjmp SecLoop              ; repetir para siempre

; ======= Muestra la figura apuntada por Z durante ~3 s =======
; Usa Timer0 en CTC para generar 1 ms
; (Con opcional: chequeo de UART para salir de inmediato)
MOSTRAR_3S:
    ; r20 = patr?n columnas, r21 = ?ndice fila, r22 = contador fila
    ; r24:r25 = contador 3000
   movw r26, r30
    ldi  r25, 0x03        ; <-- HIGH(1000)
    ldi  r24, 0xE8        ; <-- LOW(1000)
    clr  r22
MOSTRAR_L:
    rcall APAGAR_FILAS
    lpm  r20, Z+              ; byte de la fila actual
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; -------- OPCIONAL: salida no bloqueante si llega un byte por UART --------
    lds  r17, UCSR0A
    sbrs r17, RXC0            ; ?lleg? algo?
    rjmp NoKey_M3S
    rjmp main_loop            ; salir a leerlo (bloque principal)
NoKey_M3S:
    ; -------------------------------------------------------------------------

    inc  r22
    cpi  r22, 8
    brlo FilaOK_M3S
    clr  r22
    movw r30, r26             ; reiniciar Z a la figura
FilaOK_M3S:
    sbiw r24, 1
    brne MOSTRAR_L
    ret

; ======= Muestra la figura apuntada por Z para SIEMPRE =======
; Escanea la matriz de forma continua (1 ms por fila) y permite salir por tecla.
MOSTRAR_SIEMPRE:
    ; Guardar inicio de la figura en X=r26:r27 para reiniciar Z cada frame
    movw r26, r30             ; X <- Z (puntero a la figura)
    clr  r22                  ; r22 = indice de fila (0..7)
MS_L:
    rcall APAGAR_FILAS

    ; Leer byte de la fila actual y dibujarlo
    movw r30, r26             ; Z <- inicio figura
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r20, Z               ; r20 = patr?n columnas de la fila r22
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; -------- OPCIONAL: salida no bloqueante si llega un byte por UART --------
    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey_MS
    rjmp main_loop
NoKey_MS:
    ; -------------------------------------------------------------------------

    ; Siguiente fila
    inc  r22
    cpi  r22, 8
    brlo MS_L

    ; Fin de frame: volver a fila 0 y repetir para siempre
    clr  r22
    rjmp MS_L

; ----- Helpers de matriz -----
APAGAR_FILAS:
    in   r16, PORTB
    ori  r16, FILASB_OFF
    out  PORTB, r16
    in   r16, PORTC
    ori  r16, FILASC_OFF
    out  PORTC, r16
    ret

PONER_COLUMNAS:
    ; PD2..PD7 (C1..C6)
    mov  r16, r20
    andi r16, 0x3F
    lsl  r16
    lsl  r16
    in   r17, PORTD
    andi r17, 0x03
    or   r17, r16
    out  PORTD, r17
    ; PB0..PB1 (C7..C8)
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
    com  r19                  ; poner 0 solo en la fila seleccionada
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

ESPERAR_1MS:
    ldi  r16, (1<<OCF0A)
    out  TIFR0, r16
W1:
    in   r17, TIFR0
    sbrs r17, OCF0A
    rjmp W1
    ret

; ============================================================================== 
;                     CASO 1: SCROLL "MEGUSTA COMER ASADO"
; ==============================================================================

; --- Fuentes de 8x8 para cada caracter (columnas por fila) ---


; --- Subrutina de scroll: muestra TODO el mensaje completo una vez ---
; Implementa el algoritmo original, preservando registros usados por el monitor.
; --- Subrutina de scroll: muestra TODO el mensaje completo (interrumpible por UART) ---
; Si llega un byte por UART (RXC0=1), sale inmediatamente a FinScroll,
; restaura registros y retorna al llamador (caso_1), que vuelve al main_loop.
MostrarScrollMensaje:
    ; Preservar todos los registros que usa el algoritmo
    push r0
    push r16
    push r17
    push r18
    push r19        ; FIGIDX
    push r20
    push r21
    push r22
    push r23        ; SHIFTX
    push r24        ; FRMCNT
    push r25        ; SHCNT
    push r26        ; X (figura actual)
    push r27
    push r28        ; Y (siguiente figura)
    push r29
    push r30        ; Z (temporal)
    push r31

    ; ====== Estado inicial del scroll ======
    clr  r19             ; FIGIDX = 0
    rcall CARGAR_FIGURA_Y_SIGUIENTE
    ldi  r23, 0          ; SHIFTX = 0
    ldi  r24, FRAMES_POR_PASO
    clr  r22             ; fila = 0

Scroll_MAIN_LOOP:
    ; --- apaga filas y toma byte actual de la figura A (X=r26:r27) ---
    rcall APAGAR_FILAS
    movw r30, r26        ; Z <- X
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r20, Z          ; r20 = fila de A

    ; --- toma byte correspondiente de la figura B (Y=r28:r29) ---
    movw r30, r28        ; Z <- Y
    mov  r18, r22
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z           ; r0 = fila de B

    ; --- desplazar A a derecha SHIFTX bits ---
    mov  r18, r23
    cpi  r18, 8
    breq SOLO_B_CON_ESPACIO

    tst  r18
    breq A_LISTO
A_SHIFT:
    lsr  r20
    dec  r18
    brne A_SHIFT
A_LISTO:

    ; --- desplazar B a izquierda (8 - SHIFTX) bits ---
    ldi  r25, 8
    sub  r25, r23
    tst  r25
    breq B_LISTO
B_SHIFT:
    lsl  r0
    dec  r25
    brne B_SHIFT
B_LISTO:

    lsl  r0               ; espacio entre letras de 1 columna
    or   r20, r0
    rjmp COMPOSICION_COMPLETA

SOLO_B_CON_ESPACIO:
    mov  r20, r0
    lsl  r20              ; espacio a la izquierda

COMPOSICION_COMPLETA:
    ; --- dibujar fila ---
    rcall PONER_COLUMNAS
    mov  r21, r22
    rcall ACTIVAR_FILA
    rcall ESPERAR_1MS

    ; -------- Chequeo de UART: si hay byte, salir limpio del scroll --------
    lds  r17, UCSR0A
    sbrs r17, RXC0           ; ?lleg? algo?
    rjmp NoKey_SCR_1ms
    rjmp FinScroll           ; restaurar registros y retornar
NoKey_SCR_1ms:
    ; -----------------------------------------------------------------------

    ; --- siguiente fila ---
    inc  r22
    cpi  r22, 8
    brlo Scroll_MAIN_LOOP

    ; --- pas? un frame (todas las filas) ---
    clr  r22
    dec  r24

    ; -------- Chequeo de UART tambi?n al final del frame -------------------
    lds  r17, UCSR0A
    sbrs r17, RXC0
    rjmp NoKey_SCR_frame
    rjmp FinScroll
NoKey_SCR_frame:
    ; -----------------------------------------------------------------------

    brne Scroll_MAIN_LOOP

    ; --- avanzar un ÅgpasoÅh de scroll ---
    ldi  r24, FRAMES_POR_PASO
    inc  r23               ; SHIFTX++
    cpi  r23, 9            ; 0..8 (8 = toda letra + 1 espacio)
    brlo Scroll_MAIN_LOOP

    ; --- fin de letra, pasar a siguiente ---
    clr  r23               ; SHIFTX = 0
    inc  r19               ; FIGIDX++
    cpi  r19, NUMFIG
    brlo SIGUIENTE_OK
    clr  r19               ; volver a 0 si termin? toda la frase
SIGUIENTE_OK:
    rcall CARGAR_FIGURA_Y_SIGUIENTE
    rjmp Scroll_MAIN_LOOP

FinScroll:
    pop  r31
    pop  r30
    pop  r29
    pop  r28
    pop  r27
    pop  r26
    pop  r25
    pop  r24
    pop  r23
    pop  r22
    pop  r21
    pop  r20
    pop  r19
    pop  r18
    pop  r17
    pop  r16
    pop  r0
    ret

; Carga en X=r26:r27 la figura FIGIDX y en Y=r28:r29 la siguiente figura
CARGAR_FIGURA_Y_SIGUIENTE:
    ; X <- FIGTAB[FIGIDX]
    ldi  ZL, low(FIGTAB<<1)
    ldi  ZH, high(FIGTAB<<1)
    mov  r18, r19          ; r18=FIGIDX
    lsl  r18               ; *2
    add  ZL, r18
    adc  ZH, r1
    lpm  r0, Z+
    mov  r26, r0
    lpm  r0, Z
    mov  r27, r0

    ; Y <- FIGTAB[(FIGIDX+1)%NUMFIG]
    mov  r18, r19
    inc  r18
    cpi  r18, NUMFIG
    brlo IDX_OK
    clr  r18
IDX_OK:
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

; ================== FIN ==================
