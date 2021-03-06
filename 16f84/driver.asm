;********************************************************************************
;										*
;	����������:								*
;										*
;										*
;********************************************************************************
;										*
;	���������:	
; ���������� �������-����� � �������������� ������� ����������
;										*
;										*
;********************************************************************************

	list      	p=16f84a	; ��������� ����������� ���� �����������
	#include	<p16f84a.inc>	; ���������� ����������� ���� ��������� MPLAB
	radix		hex		; ������ ����� �� ��������� - �����������������
	
;------------------------------------------------------------------------------
	;������� ����� ������������ (������������ ����������� �����
	;			     ��. � ����� p16F84.inc)

	;__CONFIG _CP_OFF & _WDT_OFF & _PWRTE_ON

;------------------------------------------------------------------------------

;		--- ��������� ---

;------------------------------------------------------------------------------

;		--- ������������ ---

;______________________________________________________________________________
; ���� ����� <PORTB>
LED2	equ	0;	pin6
LED1	equ	1;	pin7
POWER_UP	equ	5;	
MOSFET_RELAY	equ	2;	pin9
BUZZER	equ	3;	pin10
BUZZER2	equ	4

; ���� ����� <PORTA>
KEY2	equ	0;	pin17
KEY1	equ	1;	pin18
KEY3	equ	3;	pin1
SENSE1	equ	2;	pin3


AUTOMATIC_TIME_1	equ	5;	����� �� �������� �����
;--------
; Start of available RAM.
;--------
	cblock	0x20
		safe_w		;not really temp, used by interrupt svc
		safe_s		;not really temp, used by interrupt svc

		temp1,temp2,temp3,temp_time,temp_snd,temp_snd2
		STATE
		keys

		bigtick_dbl	;incremented each interrupt
		bigtick_hi
		bigtick_lo
		tick		;used by delay
	endc

;		--- ���� ---

		ORG	0		; ������ ������ - � ����� ������ PIC
					; �������� ���������� ���������
Reset	goto	Begin		; ����������� ������� �� ������ �������� ���������
					; (������� ���������� ���������� � ������������)

;------------------------------------------------------------------------------
;		--- ���������� ���������� ---

;		ORG	4			; ������ ���������� - ������� �� ����� ������
;						; �������������� ��������� ��� ��������� �����
;						; ������� �� ����� ����������������� ����������,
;						; ��� ���� ��������� ������������ ��� GIE
;
;Interrupt	movwf	safe_w			; ���������� ��������� - ����������� ���������
;		movf	STATUS,W		; W � STATUS, ������ ��� ��� ����� ����������
;		movwf	safe_s			; � �������� ������ ����������� ����������
;
;		clrwdt


;		����� ����� ������������� ���� ������������ ��������� ����������

;End_int	movf	safe_s,W		; ��������������� ��������
;		movwf	STATUS	
;		swapf	safe_w,F		; ��� ���������� �������, ����� ��������� ��� Z � STATUS
;		swapf	safe_w,W		; (movf ��� ����� ��������, � swapf - ���)
;		retfie				; ������� �� ����������� � ���������� ���� GIE



Ram_init
		movlw	0xFC
		movwf	bigtick_dbl

		movlw	0x00
		movwf	STATE
		retlw	0
;--------
; unused pins I am setting to be outputs
;--------
Port_init	
		bcf		STATUS,RP1
		bcf		STATUS,RP0

		clrf	PORTA
		clrf	PORTB

;		movlw	0x07
;		movwf	CMCON
;		movlw	0x00
;		movwf	VRCON

		bcf		STATUS,RP1
		bsf		STATUS,RP0

		movlw	b'11111111'
		movwf 	TRISA
     
		movlw	0x00
		movwf 	TRISB

		bcf		STATUS,RP1		; �������� ����0 ��������� ���,
		bcf		STATUS,RP0		; ������� ���� ������ ������ � �������� STATUS
		
Port_reset
		clrf	PORTB		
		retlw	0

;--------
; get timer-based interrupts going
;--------
Timer_init	
		bcf	INTCON,2	;clear TMR0 int flag
		bcf	INTCON,7	;disable global interrupts
		bcf	INTCON,5	;disable TMR0 int
		clrf	TMR0		;clear timer
		clrwdt			;why is this needed? just do it..
;		movlw	b'11011000'	;set up timer. prescaler(bit3)bypassed 
;		option			;send w to option. generate warning.
		
		movlw	B'11001000'
		movwf	OPTION_REG

;		BCF	OPTION_REG,7	;��������� Pull up ��������� �� ����� B (~200K)

;		MOVLW	0 ;0x90; B'10010000'
;        MOVWF	INTCON		;���������� �� ������������
;                MOVLW   0x15            ;��������� ������� 1
;                MOVWF   T1CON

;                MOVLW   0x0B            ;��������� ������ ��� ������ ������� 1
;                MOVWF   CCP1CON; 00001011

;                MOVLW   0x64
;                MOVWF   CCPR1L;01100100

;                MOVLW   0x57
;                MOVWF   CCPR1H;



		retlw	0

;------------------------------------------------------------------------------
;		--- �������� ��������� ---

Const_init
		return

Begin	
		bcf		STATUS,RP1		; �������� ����0 ��������� ���,
		bcf		STATUS,RP0		; ������� ���� ������ ������ � �������� STATUS

		call	Port_init
		call	Ram_init
		call	Const_init

;
; ���� �������� � ������� ������
;
		btfsc	PORTA,SENSE1
		call	SENSE1_OK

		call	BEEP2
		call	DELAY_250MS
		bsf		PORTB,LED1
		bsf		PORTB,LED2

		call	BEEP1
		call	DELAY_250MS
		bcf		PORTB,LED1
		bcf		PORTB,LED2

		call	BEEP1
		call	DELAY_250MS
		bsf		PORTB,LED1
		bsf		PORTB,LED2

		call	BEEP3
		bcf		PORTB,LED1
		bcf		PORTB,LED2

		bcf		PORTB,MOSFET_RELAY
		bcf		PORTB,POWER_UP
		
		call	DELAY_500MKS
		bsf		PORTB,LED1
		bsf		PORTB,LED2

		call	DELAY_500MKS
		bcf		PORTB,LED1
		bcf		PORTB,LED2

		call	DELAY_500MKS
		bsf		PORTB,LED1
		bsf		PORTB,LED2

		call	DELAY_500MKS
		bcf		PORTB,LED1
		bcf		PORTB,LED2


;		����� ����� ������ ��� ���...

Main_Cikl
		movf	PORTA,0
		movwf	keys

		btfss	keys,KEY1
		call 	OPEN_LOCK

		btfss	keys,KEY2
		call 	CLOSE_LOCK

		btfss	keys,KEY3
		call 	AUTOMATIC1

Wait	goto	Main_Cikl			; ����������� �� ������ (����� �������� ���c�� goto $)
;
; ---======########### ������ �������������� ############=======-------
;
;
	
OPEN_LOCK
		call	BEEP1
		bcf		PORTB,LED2;		��������� LED2
		bcf		STATE,LED2

		bsf		PORTB,LED1;		�������� LED1
		bsf		STATE,LED1

		bsf		PORTB,MOSFET_RELAY
		call	DELAY_250MS

		bsf		PORTB,POWER_UP
		call	DELAY_250MS
		bcf		PORTB,POWER_UP

		bcf		PORTB,MOSFET_RELAY
		return	

CLOSE_LOCK

		btfss	PORTA,SENSE1
		goto	SENSE1_OK

		goto	SOUND_SENSE_ERROR

SENSE1_OK		
		call	BEEP1

		bcf		PORTB,LED1
		bcf		STATE,LED1

		bsf		PORTB,LED2
		bsf		STATE,LED2

		bsf		PORTB,POWER_UP
		call	DELAY_250MS
		bcf		PORTB,POWER_UP
		return	

AUTOMATIC1
;
; ������ �������� �����
;
		call	OPEN_LOCK

		movlw	0x0A;				10 ������ ���
		movwf	temp_time

AUTOMATIC_LOOP
		bcf		PORTB,LED1
		bsf		PORTB,LED2
		
		call	BEEP2		
		call	DELAY_250MS

		btfsc	PORTA,SENSE1;		skip if b=0
		goto	AUTOMATIC_NEXT1
		
;AUTOMATIC_LOOP1		
		bcf		PORTB,LED2
		bsf		PORTB,LED1

		call	BEEP2		
		call	DELAY_500MS
		
		btfsc	PORTA,SENSE1
		goto	AUTOMATIC_NEXT1

		decfsz	temp_time,1
		goto	AUTOMATIC_LOOP
		goto	SOUND_NOT_OPEN
;
; ������ �������� �����
;
AUTOMATIC_NEXT1
		movlw	0x14;				20 ������ ���
		movwf	temp_time

AUTOMATIC_NEXT2
		bcf		PORTB,LED1
		bcf		PORTB,LED2
		
		call	BEEP1		
		call	DELAY_500MS

		btfss	PORTA,SENSE1;		skip if b=1
		goto	CLOSE_LOCK
		
		bsf		PORTB,LED2
		bsf		PORTB,LED1

		call	BEEP2		
		call	DELAY_500MS

		btfss	PORTA,SENSE1
		goto	CLOSE_LOCK

		decfsz	temp_time,1
		goto	AUTOMATIC_NEXT2
		goto	SOUND_NOT_OPEN

		return	
;//
;//
;// ������ SOUND'�
;//
;//
;//
;// ����: ����� �� �������
;//
;
SOUND_SENSE_ERROR
		movlw	4
		movwf	temp_snd2
SOUND_SENSE_ERROR1
		call	BEEP3;		~1KHZ
		call	DELAY_100MS
		decfsz	temp_snd2,1
		goto	SOUND_SENSE_ERROR1
		return
;//
;//
;// ���� ������, ����� �� �������
;//
;//
SOUND_NOT_OPEN
		movlw	3
		movwf	temp_snd2
SOUND_NOT_OPEN1
		call	BEEP2;		~1KHZ
		call	DELAY_100MS

		decfsz	temp_snd2,1
		goto	SOUND_NOT_OPEN1

		movlw	3
		movwf	temp_snd2
SOUND_NOT_OPEN2
		call	BEEP3;		~1KHZ
		call	DELAY_100MS
		decfsz	temp_snd2,1
		goto	SOUND_NOT_OPEN2

		return
;//
;// ���� ��� � �������� ~1kHz
;//
BEEP1
		movlw	0x40
		movwf	temp_snd
SND1_LOOP
		bsf		PORTB,BUZZER
		movlw	0x80
		call	delay_XXms
		bcf		PORTB,BUZZER
		movlw	0x60
		call	delay_XXms		
		decfsz	temp_snd,1
		goto	SND1_LOOP
		return
;//
;// ���� ��� � �������� ~2kHz
;//

BEEP2
		movlw	0x20
		movwf	temp_snd
BEEP2_LOOP
		bsf		PORTB,BUZZER
		movlw	0xFF
		call	delay_XXms
		movlw	0xFF
		call	delay_XXms
		bcf		PORTB,BUZZER
		movlw	0xFF 
		call	delay_XXms

		decfsz	temp_snd,1
		goto	BEEP2_LOOP
		return

BEEP3
		movlw	0x08
		movwf	temp_snd
BEEP3_LOOP
		bsf		PORTB,BUZZER
		movlw	0xFF
		call	delay_XXms
		movlw	0xFF
		call	delay_XXms
		movlw	0xFF
		call	delay_XXms   
		bcf		PORTB,BUZZER
		movlw	0xFF
		call	delay_XXms
		movlw	0xFF
		call	delay_XXms
		movlw	0xFF
 		call	delay_XXms
		decfsz	temp_snd,1
		goto	BEEP3_LOOP
		return

;//
;//
;// ��������� �������� 
;//
;;;
delay_5mks
		movlw	0x0E
		movwf	temp1
delay_5mks_1
		decfsz	temp1,1
		goto	delay_5mks_1
		return

;//
;//
;//
DELAY_500MKS
		movlw	0xFF
		movwf	temp1
DELAY_500MKS_1
		decfsz	temp1,1
		goto	DELAY_500MKS_1
		return
;//
;//
;//
;;;		�������� ���������� movlw 0xXX
delay_XXms
		movwf	temp1
delay_XXms_1
		
		decfsz	temp1,1
		goto	delay_XXms_1
		return

DELAY_100MS
; 1 ���� = 12,5ns (8 MHZ)
; 1 ��� = 1000000000 ns = 80000000 ������
;
		movlw	0x80
		movwf	temp1
		movwf	temp2

DELAY_100MS_1
		decfsz	temp2,1
		goto	DELAY_250MS_1; 511 ������

		decfsz	temp1,1
		goto	DELAY_250MS_1; 130306 ������

		return


DELAY_250MS
; 1 ���� = 12,5ns (8 MHZ)
; 1 ��� = 1000000000 ns = 80000000 ������
;
		movlw	0xFF
		movwf	temp1
		movwf	temp2

DELAY_250MS_1
		decfsz	temp2,1
		goto	DELAY_250MS_1; 511 ������

		decfsz	temp1,1
		goto	DELAY_250MS_1; 130306 ������

		return

;//
;//
;//
DELAY_500MS
; 1 ���� = 12,5ns (8 MHZ)
; 1 ��� = 1000000000 ns = 80000000 ������
;
		movlw	0xFF
		movwf	temp1
		movwf	temp2

DELAY_500MS_1
		decfsz	temp2,1
		goto	DELAY_500MS_1; 511 ������

		decfsz	temp1,1
		goto	DELAY_500MS_1; 130306 ������

		movlw	0xFF
		movwf	temp1
		movwf	temp2

DELAY_500MS_2
		decfsz	temp2,1
		goto	DELAY_500MS_2; 511 ������

		decfsz	temp1,1
		goto	DELAY_500MS_2; 130306 ������
		return

		END				; ��������� "����� ���������"
;
;
;del_lo ;
;del_mi ;
;del_hi ;������� ����������

;delay_1c movlw D'172'
;movwf del_lo
;movlw D'19'
;movwf del_mi
;movlw 06h
;movwf del_hi

;label1
;decfsz del_lo,F
;goto label1
;decfsz del_mi,F
;goto label1
;decfsz del_hi,F
;goto label1
;nop
;return