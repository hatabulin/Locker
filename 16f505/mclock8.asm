;--------
; mclock8.asm
; "The Propeller" mechanically scanned LED clock
; some changes since last version -
; modified table etc for compatiblility with 8th LED
; watchdog timer used to ensure startup
; Bob Blick February 12, 1997
; Licensed under the terms of the GNU General Public License, www.gnu.org
; No warranties expredded or implied
; Bob Blick February 18, 2002
;--------
		list	p=16C84
		radix	hex
		include	"p16c84.inc"
;--------
; remember to set blast-time options: OSC=regular xtal, WDT=ON
; timings all based on 4 MHz crystal
;--------
; are these equates already in the include file? someday I'll look.
;--------
w		equ	0
f		equ	1
;--------
; Start of available RAM.
;--------
	cblock	0x0C
		safe_w		;not really temp, used by interrupt svc
		safe_s		;not really temp, used by interrupt svc
		period_count	;incremented each interrupt
		period_dup	;copy of period_count safe from interrupt
		period_calc	;stable period after hysteresis calc.
		flags		;b2=int b1=minute b4=edge
		dot_index	;which column is being displayed
		digit_index	;which digit is being displayed
		hours		;in display format, not hex(01-12)
		minutes		;00 to 59
		bigtick_dbl	;incremented each interrupt
		bigtick_hi
		bigtick_lo
		keys		;key value
		scratch		;scratch value
		tick		;used by delay
	endc
;--------
; Start of ROM
;--------
		org	0x00		;Start of code space
		goto	Start
;--------
; INTERRUPT SERVICE ROUTINE
;--------
		org	0x04		;interrupt vector
Intsvc		movwf	safe_w		;save w
		swapf	STATUS,w	;swap status, w
		movwf	safe_s		;save status(nibble swap, remember)
;--------
; done saving, now start working
;--------
; clear watchdog timer to ensure startup
		clrwdt
;
; increment period count
		incf	period_count,f
		btfsc	STATUS,Z	;zero set means overflow
		decf	period_count,f
; 234375 interrupts every minute. Increment the bigtick each time.
		incf	bigtick_lo,f
		btfsc	STATUS,Z
		incf	bigtick_hi,f
		btfsc	STATUS,Z
		incfsz	bigtick_dbl,f
		goto	Bigtick_out
;--------
; here? bigtick has rolled over to zero and one minute has passed.
; reload bigtick and set a flag for the main counter
;--------
		movlw	0xFC		;234375 = 0x039387
		movwf	bigtick_dbl	;0 - 0x039387 = 0xFC6C79
		movlw	0x6C
		movwf	bigtick_hi
		movlw	0x79
		movwf	bigtick_lo
		bsf	flags,1		;notify Keep_time
Bigtick_out
;--------
; done working, start restoring
;--------
		swapf	safe_s,w	;fetch status, reswap nibbles
		movwf	STATUS		;restore status
		swapf	safe_w,f	;swap nibbles in preparation
		swapf	safe_w,w	;for the swap restoration of w
		bcf	INTCON,2	;clear interrupt flag before return
		retfie			;return from interrupt
;--------
; CHARACTER LOOKUP TABLE
; ignore high bit. set=LED off, clear=LED on, bit0=bottom LED, bit6=top LED
;--------
Char_tbl
		addwf	PCL,f
		dt	0xC1,0xBE,0xBE,0xBE,0xC1	;"O"
		dt	0xFF,0xDE,0x80,0xFE,0xFF	;"1"
		dt	0xDE,0xBC,0xBA,0xB6,0xCE	;"2"
		dt	0xBD,0xBE,0xAE,0x96,0xB9	;"3"
		dt	0xF3,0xEB,0xDB,0x80,0xFB	;"4"
		dt	0x8D,0xAE,0xAE,0xAE,0xB1	;"5"
		dt	0xE1,0xD6,0xB6,0xB6,0xF9	;"6"
		dt	0xBF,0xB8,0xB7,0xAF,0x9F	;"7"
		dt	0xC9,0xB6,0xB6,0xB6,0xC9	;"8"
		dt	0xCF,0xB6,0xB6,0xB5,0xC3	;"9"
		dt	0xFF,0xC9,0xC9,0xFF,0xFF	;":"
Char_tbl_end
;--------
; SUBROUTINES STARTING HERE
;--------
; clear important bits of ram
;--------
Ram_init	movlw	0x07
		movwf	keys
		movlw	0x12		;why do clocks always start
		movwf	hours		;at 12:00 ?
		clrf	minutes
		clrf	dot_index
		clrf	digit_index
		movlw	0xFC
		movwf	bigtick_dbl
		retlw	0
;--------
; unused pins I am setting to be outputs
;--------
Port_init	movlw	0x00		;all output, b7=unused
		tris	PORTB		;on port b attached to LEDs
		movlw	b'00010111'	;port a has 5 pins. I need 4 inputs
					;b0=minutes, b1=10mins, b2=hours
					;b3=unused, b4=rotation index
		tris	PORTA		;on port a
		retlw	0
;--------
; get timer-based interrupts going
;--------
Timer_init	bcf	INTCON,2	;clear TMR0 int flag
		bsf	INTCON,7	;enable global interrupts
		bsf	INTCON,5	;enable TMR0 int
		clrf	TMR0		;clear timer
		clrwdt			;why is this needed? just do it..
		movlw	b'11011000'	;set up timer. prescaler(bit3)bypassed 
		option			;send w to option. generate warning.
		clrf	TMR0		;start timer
		retlw	0
;--------
; test for index in rotation and store period in period_dup
;--------
Check_index	movf	PORTA,w		;get the state of port a
		xorwf	flags,w		;compare with saved state
		andlw	b'00010000'	;only interested in bit 4
		btfsc	STATUS,Z	;test for edge
		retlw	0		;not an edge, same as last
		xorwf	flags,f		;save for next time
		btfsc	flags,4		;test for falling edge
		retlw	0		;must have been a rising edge
		movf	period_count,w	;make a working copy
		movwf	period_dup	;called period dup
		clrf	period_count	;a fresh start for next rotation
		clrf	digit_index	;set to first digit
		clrf	dot_index	;first column
; calculate a period that does not dither or jitter
; period will not be changed unless new period is really different
		movf	period_calc,w
		subwf	period_dup,w	;find difference
		btfss	STATUS,C	;carry flag set means no borrow
		goto	Calc_period_neg	;must be other way
		sublw	2		;allowable deviation = 3
		btfss	STATUS,C	;borrow won't skip
		incf	period_calc	;new value much larger than calc
		retlw	0
Calc_period_neg	addlw	2		;allowable deviation = 3
		btfss	STATUS,C	;carry will skip
		decf	period_calc	;no carry means it must be changed
		retlw	0
;--------
; change LED pattern based on state of digit_index and dot_index
;--------
Display_now	movlw	0x05
		xorwf	dot_index,w	;test for end of digit
		movlw	0xFF		;pattern for blank column
		btfsc	STATUS,Z
		goto	D_lookup_3	;it needs a blank
		bcf	STATUS,C	;clear carry before a rotate
		rlf	digit_index,w	;double the index because each
		addwf	PCL,f		;takes two instructions
D_10hr		swapf	hours,w
		goto	D_lookup	;what a great rush of power
D_1hr		movf	hours,w		;I feel when modifying
		goto	D_lookup	;the program counter
D_colon		movlw	0x0A
		goto	D_lookup
D_10min		swapf	minutes,w
		goto	D_lookup
D_1min		movf	minutes,w
		goto	D_lookup
D_nothing	retlw	0
D_lookup	andlw	b'00001111'	;strip off hi bits
		movwf	scratch		;multiply this by 5 for lookup
		addwf	scratch,f	;table base position
		addwf	scratch,f	;is this cheating?
		addwf	scratch,f	;I think not.
		addwf	scratch,f	;I think it is conserving energy!
		btfss	STATUS,Z	;test for zero
		goto	D_lookup_2	;not a zero
		movf	digit_index,f	;this is just to test/set flag
		movlw	0xFF		;this makes a blank LED pattern
		btfsc	STATUS,Z	;test if it is 10 hrs digit
		goto	D_lookup_3	;it's a leading zero
D_lookup_2	movf	dot_index,w	;get column
		addwf	scratch,w	;add it to digit base
		call	Char_tbl	;get the dot pattern for this column
D_lookup_3	movwf	PORTB		;send it to the LEDs
		movlw	0x0C		;overhead value sub from period
		subwf	period_calc,w	;compensate for overhead and set
		call	Delay		;width of digits with this delay
		incf	dot_index,f	;increment to the next column
		movlw	0x06		;6 columns is a digit plus space
		xorwf	dot_index,w	;next digit test
		btfss	STATUS,Z
		retlw	0		;not a new digit
		clrf	dot_index	;new digit time
		incf	digit_index,f
		retlw	0		;Display_now done.
;--------
; a short delay routine
;--------
Delay		movwf	tick
Delay_loop	decfsz	tick,f
		goto	Delay_loop	;w is not damaged, so Delay can
		return			;be recalled without reloading
;--------
; test for keypress and call time adjust if needed
;--------
Check_keys	movf	PORTA,w		;get port "a"
		xorwf	keys,w		;compare with previous
		andlw	b'00000111'	;only care about button pins
		btfsc	STATUS,Z	;zero set=no buttons
		retlw	0		;return
		xorwf	keys,f		;store key value
		movlw	0x64		;a fairly long delay will
		movwf	scratch		;prevent key bounces
Key_delay	movlw	0xFF
		call	Delay
		decfsz	scratch
		goto	Key_delay
		btfss	keys,2		;test "minutes" button
		goto	Inc_mins
		btfss	keys,1		;test "tens" button
		goto	Inc_tens
		btfss	keys,0		;test "hours" button
		goto	Inc_hours
		retlw	0		;must be a glitch. yeah, right!
;--------
; increment ten minutes
;--------
Inc_tens	movlw	0x0A
		movwf	scratch		;scratch has ten
Inc_tens_loop	call	Inc_mins
		decfsz	scratch
		goto	Inc_tens_loop	;another minute added
		retlw	0
;--------
; increment one hour
;--------
Inc_hours	movlw	0x12
		xorwf	hours,w
		btfsc	STATUS,Z
		goto	Inc_hours_12
		movlw	0x07		;this part gets a little sloppy
		addwf	hours,w
		movlw	0x07
		btfss	STATUS,DC
		movlw	1
		addwf	hours,f
		retlw	0
Inc_hours_12	movlw	0x01
		movwf	hours
		retlw	0
;--------
; increment the time based on flags,1 as sent by interrupt routine
; Inc_mins loop also used by time-setting routine
;--------
Keep_time	btfss	flags,1		;the minutes flag
		retlw	0		;not this time
		bcf	flags,1		;clear the minutes flag
Inc_mins	movlw	0x07		;start incrementing time
		addwf	minutes,w	;add 7 minutes into w
		btfsc	STATUS,DC	;did adding 7 cause digit carry?
		goto	Sixty_mins	;then test for an hour change
		incf	minutes		;otherwise add 1 for real
		retlw	0		;and go back
Sixty_mins	movwf	minutes		;save the minutes
		movlw	0x60		;test for 60
		xorwf	minutes,w	;are minutes at 60?
		btfss	STATUS,Z
		retlw	0		;no? go back
		clrf	minutes		;otherwise zero minutes
		goto	Inc_hours	;and increment hours
;--------
; End of subroutines
; Program starts here
;--------
Start		call	Ram_init	;set variables to nice values
		call	Port_init	;set port directions
		call	Timer_init	;start timer based interrupt
;--------
; Done initializing, start the endless loop.
;--------
;
Circle					;begin the big loop
;
;--------
; detect falling edge on PORTA,4 to determine rotary index
; calculate rotation period and store in period_dup
; compare with working period(period_calc) and adjust if way different
;--------
		call	Check_index
;--------
; check display state and change if needed
;--------
		call	Display_now
;--------
; check keyboard and adjust time
;--------
		call	Check_keys
;--------
; check minute flag and increment time if a minute has passed
;--------
		call	Keep_time
;--------
; gentlemen, that's a clock, keep it rolling
;--------
		goto	Circle		;you heard the man, get going!
		end
;--------
; end of file
;--------
