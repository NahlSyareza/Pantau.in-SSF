;------------------------
; Assembly Code
;------------------------
#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global main
.global SPI_MAX7219_init
.global MAX7219_disp_text
;===============================================================
main:
;--------------
    RCALL SPI_MAX7219_init
    RCALL MAX7219_disp_text

    LDI   R25, 0xFF
    OUT   DDRC, R25
    SBI   DDRB, 1         ;pin PB1 as o/p (Trigger)
    CBI   DDRB, 0         ;pin PB0 as i/p (Echo)
    ;-----------------------------------------------------------
agn:SBI   PORTB, 1
    RCALL delay_timer0
    CBI   PORTB, 1        ;send 10us high pulse to sensor
    ;-----------------------------------------------------------
    RCALL rate_echo_PW    ;compute Echo pulse width count
    ;-----------------------------------------------------------
    RCALL byte2decimal    ;covert & display on MAX7219
    ;-----------------------------------------------------------
    RCALL delay_ms
    RJMP  agn
;===============================================================
rate_echo_PW:
    CLR   R28
    CLR   R31
    CLR   R30
    CLR   R24
    LDI   R24, 5
echo_PW:
;-------
    LDI   R20, 0b00000000
    STS   TCCR1A, R20     ;Timer 1 normal mode
    LDI   R20, 0b11000101 ;set for rising edge detection &
    STS   TCCR1B, R20     ;prescaler=1024, noise cancellation ON
    ;-----------------------------------------------------------
l1: IN    R21, TIFR1
    SBRS  R21, ICF1
    RJMP  l1              ;loop until rising edge is detected
    ;-----------------------------------------------------------
    LDS   R16, ICR1L      ;store count value at rising edge
    ;-----------------------------------------------------------
    OUT   TIFR1, R21      ;clear flag for falling edge detection
    LDI   R20, 0b10000101
    STS   TCCR1B, R20     ;set for falling edge detection
    ;-----------------------------------------------------------
l2: IN    R21, TIFR1
    SBRS  R21, ICF1
    RJMP  l2              ;loop until falling edge is detected
    ;-----------------------------------------------------------
    LDS   R28, ICR1L      ;store count value at falling edge
    ;-----------------------------------------------------------
    SUB   R28, R16        ;count diff R22 = R22 - R16
    OUT   TIFR1, R21      ;clear flag for next sensor reading
l3: CPI   R24, 0
    BREQ  l4
    ADD   R31, R28
    SUBI  R24, 1 
    RJMP  l3
l4: CPI   R31, 5
    BRMI  l5
    INC   R30
    SUBI  R31, 5
    RJMP  l4
l5: SUBI  R30, -1
    RET
;===============================================================
;MAX7219 subroutines
;===============================================================
SPI_MAX7219_init:
;----------------
.equ  SCK, 5
.equ  MOSI, 3
.equ  SS, 2
;--------------------------------------------------------------
      LDI   R17, (1<<MOSI)|(1<<SCK)|(1<<SS)
      OUT   DDRB, R17       ;set MOSI, SCK, SS as o/p
      ;--------------------------------------------------------
      LDI   R17, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
      OUT   SPCR, R17       ;enable SPI as master, fsck=fosc/16
      ;--------------------------------------------------------
      LDI   R17, 0x0A       ;set segment intensity (0 to 15)
      LDI   R18, 5          ;intensity level = 8
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x09       ;set decoding mode command
      LDI   R18, 0b00000011 ;decoding byte
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x0B       ;set scan limit command
      LDI   R18, 0x07       ;8 digits connected to MAX7219
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x0C       ;set turn ON/OFF command
      LDI   R18, 0x01       ;turn ON MAX7219
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      RET
;==============================================================
MAX7219_disp_text:
;--------------------------------------------------------
      LDI   R17, 0x08       ;select digit 7
      LDI   R18, 0x0F       ;data = t
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x07       ;select digit 6
      LDI   R18, 0x06       ;data = i
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x06       ;select digit 5
      LDI   R18, 0x15       ;data = n
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x05       ;select digit 4
      LDI   R18, 0x7B       ;data = g
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x04       ;select digit 3
      LDI   R18, 0x7B       ;data = g
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      LDI   R17, 0x03       ;select digit 2
      LDI   R18, 0x06       ;data = i
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      RET
;==============================================================
send_bytes:
      CBI   PORTB, SS       ;enable slave device MAX7219
      OUT   SPDR, R17       ;transmit command
      ;--------------------------------------------------------
ll2:  IN    R19, SPSR
      SBRS  R19, SPIF       ;wait for byte transmission
      RJMP  ll2             ;to complete
      ;--------------------------------------------------------
      OUT   SPDR, R18       ;transmit data
      ;--------------------------------------------------------
ll3:  IN    R19, SPSR
      SBRS  R19, SPIF       ;wait for byte transmission
      RJMP  ll3             ;to complete
      ;--------------------------------------------------------
      SBI   PORTB, SS       ;disable slave device MAX7219
      RET
      ;--------------------------------------------------------
min10LED:
      LDI   R25, 0x04
      OUT   PORTC, R25
      RJMP  l80
min20LED:
      LDI   R25, 0x02
      OUT   PORTC, R25
      RJMP  l80 
min30LED:
      LDI   R25, 0x01
      OUT   PORTC, R25
      RJMP  l80
;==============================================================
byte2decimal:
;------------
      CLR   R26             ;set counter1, initial value 0
      CLR   R27             ;set counter2, initial value 0
      MOV   R24, R30
      LDI   R30, 30
      SUB   R30, R24
      CPI   R30, 11
      BRMI  min10LED
      CPI   R30, 21
      BRMI  min20LED
      CPI   R30, 31
      BRMI  min30LED
      ;--------------------------------------------------------
l80:  CPI   R30, 10         ;compare R30 with 10
      BRMI  dsp             ;jump when R30 < 10
      INC   R27             ;increment counter2 by 1
      SUBI  R30, 10         ;R30 = R30 - 10
      RJMP  l80
      ;--------------------------------------------------------
dsp:  
      MOV   R18, R27
      LDI   R17, 0x02       ;select digit 1 for MSD
      RCALL send_bytes      ;send command & data to MAX7219
      ;--------------------------------------------------------
      MOV   R18, R30
      LDI   R17, 0x01       ;select digit 0 for LSD
      RCALL send_bytes      ;send command & data to MAX7219    
      ;--------------------------------------------------------
      RET
;===============================================================
;delay subroutines
;===============================================================
delay_timer0:             ;10 usec delay via Timer 0
;------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 20
    OUT   OCR0A, R20      ;OCR0 = 20
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 8
    ;-----------------------------------------------------------
l0: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l0              ;else, loop back & check OCF0 flag
    ;-----------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;-----------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET
;===============================================================
delay_ms:
;--------
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 50
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
    RET