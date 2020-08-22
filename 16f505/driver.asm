;********************************************************************************
;										*
;	Требования:								*
;										*
;										*
;********************************************************************************
;										*
;	Замечания:	
; Контроллер электро-замка с автоматическим режимом закрывания
;										*
;										*
;********************************************************************************

	list      	p=16f505	; Директива определения типа контроллера
	#include	<p16f505.inc>	; Подключаем стандартный файл заголовка MPLAB
	radix		hex		; Формат чисел по умолчанию - шестнадцатиричный
	
;------------------------------------------------------------------------------
	;Задание слова конфигурации (соответствия аббревиатур битам
	;			     см. в файле p16F84.inc)

	;__CONFIG _CP_OFF & _WDT_OFF & _PWRTE_ON

;------------------------------------------------------------------------------

;		--- КОНСТАНТЫ ---

;------------------------------------------------------------------------------

;		--- МАКРОКОМАНДЫ ---

;______________________________________________________________________________
; ПИНЫ ПОРТА <PORT_C>
LED2	equ	0;	pin10
LED1	equ	1;	pin9
MOSFET_RELAY	equ	2;	pin8
POWER_UP	equ	3; pin7	
SENSE1	equ	4;	pin6
BUZZER	equ	5;	pin5

; ПИНЫ ПОРТА <PORT_B>
KEY1	equ	2;	pin11
KEY2	equ	1;	pin12
KEY3	equ	0;	pin13

AUTOMATIC_TIME_1	equ	5;	Время на закрытие двери
;--------
; Start of available RAM.
;--------
;	cblock	0x20
;		safe_w		;not really temp, used by interrupt svc
;		safe_s		;not really temp, used by interrupt svc

;***** VARIABLE DEFINITIONS
temp1	EQU     0x10        ;example variable definition
temp2	EQU     0x11        ;example variable definition
temp_time EQU	0x13
STATE	EQU		0x12;
PORTB_DATA	EQU	0x13
PORTB_STATUS	EQU 0x14

;	endc

;		--- ПУСК ---

;**********************************************************************
	ORG     0x3FF             ; processor reset vector

; Internal RC calibration value is placed at location 0x3FF by Microchip
; as a movlw k, where the k is a literal value.

	ORG     0x000             ; coding begins here
					; начинает выполнение программы
Reset	goto	Begin		; Безусловный переход на начало основной программы
					; (обходим обработчик прерываний и подпрограммы)

Ram_init
;		bsf		STATUS,PA0

		movlw	STATE; очистка переменной STATE
		movwf	FSR;
		clrf	INDF;

		bsf		INDF,KEY1
		retlw	0
;--------
; unused pins I am setting to be outputs
;--------
Port_init	
		clrf	PORTC
		clrf	PORTB

		movlw	b'11010000'
		TRIS 	PORTC
     
		movlw	b'11011111'
		TRIS 	PORTB

Port_reset
		clrf	PORTB
		clrf	PORTC
		retlw	0

;------------------------------------------------------------------------------
;		--- ОСНОВНАЯ ПРОГРАММА ---

Begin	
		call	Port_init
		call	Ram_init

		call	Beep1

;		bcf		PORTC,LED2;		выключить LED2
;		bsf		PORTC,LED1;		включить LED1

Main_Cikl
; Проверяем последнее состояние кнопок KEY1, KEY2
; и соответственно включаем светодиоды 
;
		movlw	STATE
		movwf	FSR

		btfss	INDF,KEY1
		goto	Main_Cikl_1

		bsf		PORTC,LED1;		включить LED1

Main_Cikl_1
		btfss	INDF,KEY2
		goto	Main_Cikl_2

		bsf		PORTC,LED2;		выключить LED2

Main_Cikl_2

; ОСНОВНОЙ ЦИКЛИЩЕ - продолжение !!!

Main_Cikl_LOOP	

		call	GET_KEY

		movlw	PORTB_DATA
		movwf	FSR

		btfss	INDF,KEY1
		goto 	OPEN_LOCK

		btfss	INDF,KEY2
		goto 	CLOSE_LOCK

		btfss	INDF,KEY3
		goto 	AUTOMATIC1

Wait	goto	Main_Cikl_LOOP			; Зациклиться до сброса (можно написать проcто goto $)


GET_KEY
		movlw	PORTB_DATA
		movwf	FSR

		movlw	0xFF
		movwf	INDF

		btfsc	PORTB,KEY1
		goto	GET_KEY_NEXT;	если не нажата кнопка KEY1
		
		movlw	PORTB_STATUS
		movwf	FSR

		btfsc	INDF,KEY1; проверяем флаг статуса кнопки
		goto	GET_KEY_EXIT ; уходим если установлен флаг

		bsf		INDF,KEY1
;		bcf		INDF,KEY2
;		bcf		INDF,KEY3

		movlw	PORTB_DATA
		movwf	FSR
		bcf		INDF,KEY1
		retlw	0

GET_KEY_NEXT
		movlw	PORTB_STATUS
		movwf	FSR
		bcf		INDF,KEY1

		btfsc	PORTB,KEY2
		goto	GET_KEY_NEXT1;	если не нажата кнопка KEY2

		movlw	PORTB_STATUS
		movwf	FSR
		
		btfsc	INDF,KEY2; проверяем флаг статуса кнопки
		goto	GET_KEY_EXIT ; уходим если установлен флаг

		bsf		INDF,KEY2
;		bcf		INDF,KEY1
;		bcf		INDF,KEY3

		movlw	PORTB_DATA
		movwf	FSR

		bcf		INDF,KEY2
		retlw	0

GET_KEY_NEXT1
		movlw	PORTB_STATUS
		movwf	FSR
		bcf		INDF,KEY2

		btfsc	PORTB,KEY3
		goto	GET_KEY_NEXT2;	если не нажата кнопка KEY3

		movlw	PORTB_STATUS
		movwf	FSR
		
		btfsc	INDF,KEY3; проверяем флаг статуса кнопки
		goto	GET_KEY_EXIT ; уходим если установлен флаг

		bsf		INDF,KEY3
;		bcf		INDF,KEY2
;		bcf		INDF,KEY1

		movlw	PORTB_DATA
		movwf	FSR
		bcf		INDF,KEY3
		retlw	0

GET_KEY_NEXT2
		movlw	PORTB_STATUS
		movwf	FSR

		bcf		INDF,KEY3
		bcf		INDF,KEY2
		bcf		INDF,KEY1
GET_KEY_EXIT
		retlw	0

OPEN_LOCK
		bsf		STATE,KEY1
		bcf		STATE,KEY2
		bcf		PORTC,LED2;		выключить LED2
		bsf		PORTC,LED1;		включить LED1

		bsf		PORTC,MOSFET_RELAY
;		call	DELAY_250MS
		bsf		PORTC,POWER_UP
		call	Beep1
		call	DELAY_250MS
		call	DELAY_250MS
		bcf		PORTC,POWER_UP
		bcf		PORTC,MOSFET_RELAY
		goto	Main_Cikl

CLOSE_LOCK2
		call	DELAY_250MS
		call	DELAY_250MS
		call	DELAY_250MS

CLOSE_LOCK
		btfss	PORTC,SENSE1
		goto	SENSE1_OK

		call	Beep2
		call	DELAY_250MS
		call	Beep2
		call	DELAY_250MS
		call	Beep2
		call	DELAY_250MS
		call	Beep2
		retlw	0

		goto	Err1

SENSE1_OK		
		call	Beep1

		bsf		STATE,KEY2
		bcf		STATE,KEY1

		bcf		PORTC,LED1
		bsf		PORTC,LED2

		bsf		PORTC,POWER_UP
		call	DELAY_250MS
		call	DELAY_250MS
		bcf		PORTC,POWER_UP
		goto	Main_Cikl

Err1
		movlw	temp_time
		movwf	FSR

		movlw	0x03
		movwf	INDF

Err1_1
		bsf		PORTC,LED1;		включить LED1
		call	DELAY_250MS
		bsf		PORTC,LED2;		включить LED1
		call	DELAY_250MS

		call	Beep2

		bcf		PORTC,LED1;		выключить LED1
		call	DELAY_250MS
		bcf		PORTC,LED2;		выключить LED1
		call	DELAY_250MS

		movlw	temp_time
		movwf	FSR
		
		decfsz	INDF,1
		goto	Err1_1
		goto	Main_Cikl

AUTOMATIC1
;
; ДЕЛАЕМ ОТКРЫТИЕ ЗАМКА
;
;		call	OPEN_LOCK
; === процедура открытия замка ===


		bsf		STATE,KEY1
		bcf		STATE,KEY2
		call	Beep1
		bcf		PORTC,LED2;		выключить LED2
		bsf		PORTC,LED1;		включить LED1

		bsf		PORTC,MOSFET_RELAY
		call	DELAY_250MS
		call	DELAY_250MS

		bsf		PORTC,POWER_UP
		call	DELAY_250MS
		call	DELAY_250MS
		bcf		PORTC,POWER_UP

		bcf		PORTC,MOSFET_RELAY
;=======================================

		movlw	temp_time
		movwf	FSR

		movlw	0x14
		movwf	INDF

AUTOMATIC_LOOP
		bcf		PORTC,LED1
		bsf		PORTC,LED2
		
;		call	BEEP2		
		call	DELAY_250MS
;		call	DELAY_250MS
		call	Beep1

		btfsc	PORTC,SENSE1;		skip if b=0
		goto	AUTOMATIC_NEXT1
		
		bcf		PORTC,LED2
		bsf		PORTC,LED1

;		call	BEEP2		
;		call	DELAY_250MS
		call	DELAY_250MS
		call	Beep1

		movlw	temp_time
		movwf	FSR
		
		btfsc	PORTC,SENSE1
		goto	AUTOMATIC_NEXT1

		call	GET_KEY
		movlw	PORTB_DATA
		movwf	FSR

		btfss	INDF,KEY3
		goto	AUTOMATIC_EXIT;		выход из автоматики

		decfsz	INDF,1
		goto	AUTOMATIC_LOOP

		goto 	Err1

;
; ДЕЛАЕМ ЗАКРЫТИЕ ЗАМКА
;
AUTOMATIC_NEXT1
		movlw	temp_time
		movwf	FSR

		movlw	0x14
		movwf	INDF

AUTOMATIC_NEXT2
		bcf		PORTC,LED1
		bcf		PORTC,LED2
		
;		call	BEEP1		
		call	DELAY_250MS
		call	Beep1
		call	Beep1

		btfss	PORTC,SENSE1
		goto	CLOSE_LOCK2

		call	DELAY_250MS

		bsf		PORTC,LED2
		bsf		PORTC,LED1

;		call	BEEP2		
		call	DELAY_250MS

		btfss	PORTC,SENSE1
		goto	CLOSE_LOCK2

		call	DELAY_250MS

		movlw	temp_time
		movwf	FSR

		decfsz	INDF,1
		goto	AUTOMATIC_NEXT2
		goto	Err1

AUTOMATIC_EXIT
		call	Beep1
		goto	Main_Cikl

;//
;//
;// Звук ОШИБКА, ДВЕРЬ НЕ ОТКРЫТА
;//
;//
SOUND_NOT_OPEN
;		movlw	3
;		movwf	temp_snd2
;SOUND_NOT_OPEN1
;		call	BEEP2;		~1KHZ
;		call	DELAY_100MS
;
;		decfsz	temp_snd2,1
;		goto	SOUND_NOT_OPEN1
;
;		movlw	3
;		movwf	temp_snd2
;SOUND_NOT_OPEN2
;		call	BEEP3;		~1KHZ
;		call	DELAY_100MS
;		decfsz	temp_snd2,1
;		goto	SOUND_NOT_OPEN2

		return

;
; ---======########### Коньец программулинки ############=======-------
;movlw

DELAY_250MS
; 1 такт = 12,5ns (8 MHZ)
; 1 сек = 1000000000 ns = 80000000 тактов
;
		movlw	temp1
		movwf	FSR

		movlw	0xFF
		movwf	INDF

		movlw	temp2
		movwf	FSR

		movlw	0xFF
		movwf	INDF

DELAY_250MS_1
		movlw	temp2
		movwf	FSR
DELAY_250MS_11
		decfsz	INDF,1
		goto	DELAY_250MS_11; 511 тактов

		movlw	0xFF
		movwf	INDF

		movlw	temp1
		movwf	FSR

		decfsz	INDF,1
		goto	DELAY_250MS_1; 130306 тактов

		retlw	0

Beep1
		bcf		PORTC,BUZZER				
		bcf		PORTB,BUZZER
		movlw	temp1
		movwf	FSR

		movlw	0x40
		movwf	INDF

Beep1_1
		movlw	temp2
		movwf	FSR

		movlw	0x70
		movwf	INDF

		bsf		PORTC,BUZZER
		bsf		PORTB,BUZZER				
Beep1_11
		decfsz	INDF,1
		goto	Beep1_11; 511 тактов

		movlw	0x70
		movwf	INDF

		bcf		PORTC,BUZZER
		bcf		PORTB,BUZZER
Beep1_12
		decfsz	INDF,1
		goto	Beep1_12; 511 тактов

		movlw	temp1
		movwf	FSR

		decfsz	INDF,1
		goto	Beep1_1; 130306 тактов
		retlw	0

Beep2
		bcf		PORTC,BUZZER				
		bcf		PORTB,BUZZER
		movlw	temp1
		movwf	FSR

		movlw	0x40
		movwf	INDF

Beep2_1
		movlw	temp2
		movwf	FSR

		movlw	0xF0
		movwf	INDF

		bsf		PORTC,BUZZER
		bsf		PORTB,BUZZER				
Beep2_11
		decfsz	INDF,1
		goto	Beep2_11; 511 тактов

		movlw	0xF0
		movwf	INDF

		bcf		PORTC,BUZZER
		bcf		PORTB,BUZZER
Beep2_12
		decfsz	INDF,1
		goto	Beep2_12; 511 тактов

		movlw	temp1
		movwf	FSR

		decfsz	INDF,1
		goto	Beep2_1; 130306 тактов
		retlw	0

		END
