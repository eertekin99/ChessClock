.section .vectors, "ax"
	B _start // reset vector
	B SERVICE_UND // undefined instruction vector
	B SERVICE_SVC // software interrrupt vector
	B SERVICE_ABT_INST // aborted prefetch vector
	B SERVICE_ABT_DATA // aborted data vector
	.word 0 // unused vector
	B SERVICE_IRQ // IRQ interrupt vector
	B SERVICE_FIQ // FIQ interrupt vector
.text
.global _start
_start:
	/* Set up stack pointers for IRQ and SVC processor modes */
	MOV R1, #0b11010010 // interrupts masked, MODE = IRQ
	MSR CPSR_c, R1 // change to IRQ mode
	LDR SP, =0xFFFFFFFF - 3 // set IRQ stack to A9 onchip memory

	/* Change to SVC (supervisor) mode with interrupts disabled */
	MOV R1, #0b11010011 // interrupts masked, MODE = SVC
	MSR CPSR, R1 // change to supervisor mode
	LDR SP, =0x3FFFFFFF - 3 // set SVC stack to top of DDR3 memory
	BL CONFIG_GIC // configure the ARM GIC

	// write to the pushbutton KEY interrupt mask register
	LDR R0, =0xFF200050 // pushbutton KEY base address
	MOV R1, #0xF // set interrupt mask bits
	STR R1, [R0, #0x8] // interrupt mask register (base + 8)

	// enable IRQ interrupts in the processor
	MOV R0, #0b01010011 // IRQ unmasked, MODE = SVC
	MSR CPSR_c, R0



IDLE:
	
	BL RESET_ALL			//Resets all values that are necessary for another game is played by just clicking compile and load.
	
	LDR R0, =0xff200040 		//switches
	LDR R1, [R0]				//load switches address to the R1
	
	CMP R1, #0  				//no decision so 3+0 will be played
	BEQ three
	
	CMP R1, #2					//1+0	(Only switch 1)
	BEQ one
	
	CMP R1, #1					//1+3	(Only switch 0)
	LDREQ R0, =EXTRA			//Activate EXTRA for adding games
	MOVEQ R1, #1				//EXTRA will be "1" for these games
	STREQ R1, [R0]
	BEQ one
	
	CMP R1, #8					//3+0	(Only switch 3)
	BEQ three
	
	CMP R1, #4					//3+3	(Only switch 2)
	LDREQ R0, =EXTRA			//Activate EXTRA for adding games
	MOVEQ R1, #1				//EXTRA will be "1" for these games
	STREQ R1, [R0]
	BEQ three
	
	CMP R1, #32					//5+0	(Only switch 5)
	BEQ five
	
	CMP R1, #16					//5+3	(Only switch 4)
	LDREQ R0, =EXTRA			//Activate EXTRA for adding games
	MOVEQ R1, #1				//EXTRA will be "1" for these games
	STREQ R1, [R0]
	BEQ five
	
	//if switch conditions are not satisfied it automatically start 3+0 game
	B three
	
	//It sets time1 and time2 to 1 minute. (M:SS) is the format for the beginning.
	one:
		MOV R5, #0
		MOV R6, #0
		MOV R7, #1
	
		LDR R1, =TIME1
		MOV R2, #100
		STR R2, [R1]
		LDR R1, =TIME2
		STR R2, [R1]
		B Chosen_one
	
	//It sets time1 and time2 to 3 minutes. (MM:SS) is the format for the beginning.
	three:
		MOV R5, #0
		MOV R6, #0
		MOV R7, #3
	
		LDR R1, =TIME1
		MOV R2, #300
		STR R2, [R1]
		LDR R1, =TIME2
		STR R2, [R1]
		B Chosen_one
	
	//It sets time1 and time2 to 5 minutes. (MM:SS) is the format for the beginning.
	five:
		MOV R5, #0
		MOV R6, #0
		MOV R7, #5
	
		LDR R1, =TIME1
		MOV R2, #500
		STR R2, [R1]
		LDR R1, =TIME2
		STR R2, [R1]
		B Chosen_one
	
	
	
	Chosen_one:
	BL Display0		//to display first time1 and time2 in 7-segment
	
	//to start the timer, gamers should activate KEY3.
	//Otherwise, STOP won't be "1" and it will stuck in here.
	game_stopped:
		LDR R0, =0xff200000	//LEDs address
		MOV R1, #1			//right-most LED will be "on" while game is stopped
		STR R1, [R0]		
	
		LDR R0, =RESET
		LDR R1, [R0]
		CMP R1, #1
		BEQ IDLE
	
		LDR R0, =STOP
		LDR R1, [R0]
		CMP R1, #0
		BEQ game_stopped
	
	BL RESET_ALL_NUM_REGISTERS  //Reset all num registers (r0-r12)
	BL CONFIG_PRIV_TIME			//sets up the timer
	BL RESET_ALL_NUM_REGISTERS	//Reset all num registers (r0-r12)
	
	LDR R0, =0xff200000		//LEDs address
	MOV R1, #0b1000000000	//left-most LED will be "on" while game is running
	STR R1, [R0]
	
	LOOP:
		//In this loop, interrupts are handled
		LDR R0, =RESET
		LDR R1, [R0]
		CMP R1, #1
		BEQ IDLE
		B LOOP



/* Define the exception service routines */
/*--- Undefined instructions --------------------------------------------------*/
SERVICE_UND:
	B SERVICE_UND
/*--- Software interrupts -----------------------------------------------------*/
SERVICE_SVC:
	B SERVICE_SVC
/*--- Aborted data reads ------------------------------------------------------*/
SERVICE_ABT_DATA:
	B SERVICE_ABT_DATA
/*--- Aborted instruction fetch -----------------------------------------------*/
SERVICE_ABT_INST:
	B SERVICE_ABT_INST

/*--- IRQ ---------------------------------------------------------------------*/
SERVICE_IRQ:
	PUSH {R0-R7, LR}
	/* Read the ICCIAR from the CPU Interface */
	LDR R4, =0xFFFEC100
	LDR R5, [R4, #0x0C] // read from ICCIAR

//Push Buttons' Handler
FPGA_IRQ1_HANDLER:
	CMP R5, #73		//Checks if it is IRQ of pushbuttons
	BLEQ KEY_ISR	//It goes to interrupt the service routine of pushbuttons
	CMP R5, #73		//Checks if it is IRQ of push buttons (because it lost flag after going to key_isr)
	BEQ EXIT_IRQ	//Exit IRQ

//A9 Private Timer's Handler
FPGA_IRQ2_HANDLER:
	CMP R5, #29 			//Checks if it is IRQ of A9 Private Timer
	BLEQ PRIV_TIME_ISR		//It goes to interrupt service routine of timer
	CMP R5, #29				//Checks if it is IRQ of A9 Private Timer (because it lost flag after going to priv_time_isr)
	BEQ EXIT_IRQ			//Exit IRQ

UNEXPECTED:
	BNE UNEXPECTED		// if not recognized, stop here

EXIT_IRQ:
	/* Write to the End of Interrupt Register (ICCEOIR) */
	STR R5, [R4, #0x10] // write to ICCEOIR
	POP {R0-R7, LR}
	SUBS PC, LR, #4
/*--- FIQ ---------------------------------------------------------------------*/
	SERVICE_FIQ:
	B SERVICE_FIQ

/* ^^^^ END of Define the exception service routines ^^^^ */

/* Configure the Generic Interrupt Controller (GIC)
	*/
CONFIG_GIC:
	PUSH {LR}
/* To configure the FPGA KEYS interrupt (ID 73):
* 1. set the target to cpu0 in the ICDIPTRn register
* 2. enable the interrupt in the ICDISERn register */

/* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
	MOV R0, #73 // KEY port (Interrupt ID = 73)
	MOV R1, #1 // this field is a bit-mask; bit 0 targets cpu0
	BL CONFIG_INTERRUPT
	
	MOV R0, #29 		//Key port for A9 Private Timer
	BL CONFIG_INTERRUPT //Configurations
	
	/* configure the GIC CPU Interface */
	LDR R0, =0xFFFEC100 // base address of CPU Interface
	
	/* Set Interrupt Priority Mask Register (ICCPMR) */
	LDR R1, =0xFFFF // enable interrupts of all priorities levels
	STR R1, [R0, #0x04]
	
	/* Set the enable bit in the CPU Interface Control Register (ICCICR).
	* This allows interrupts to be forwarded to the CPU(s) */
	MOV R1, #1
	STR R1, [R0]
	
	/* Set the enable bit in the Distributor Control Register (ICDDCR).
	* This enables forwarding of interrupts to the CPU Interface(s) */
	LDR R0, =0xFFFED000
	STR R1, [R0]
	POP {PC}

/*
* Configure registers in the GIC for an individual Interrupt ID
* We configure only the Interrupt Set Enable Registers (ICDISERn) and
* Interrupt Processor Target Registers (ICDIPTRn). The default (reset)
* values are used for other registers in the GIC
* Arguments: R0 = Interrupt ID, N
* R1 = CPU target
*/
CONFIG_INTERRUPT:
	PUSH {R4-R5, LR}
/* Configure Interrupt Set-Enable Registers (ICDISERn).
* reg_offset = (integer_div(N / 32) * 4
* value = 1 << (N mod 32) */
	LSR R4, R0, #3 // calculate reg_offset
	BIC R4, R4, #3 // R4 = reg_offset
	LDR R2, =0xFFFED100
	ADD R4, R2, R4 // R4 = address of ICDISER
	AND R2, R0, #0x1F // N mod 32
	MOV R5, #1 // enable
	LSL R2, R5, R2 // R2 = value
	
/* Using the register address in R4 and the value in R2 set the
* correct bit in the GIC register */
	LDR R3, [R4] // read current register value
	ORR R3, R3, R2 // set the enable bit
	STR R3, [R4] // store the new register value
	
/* Configure Interrupt Processor Targets Register (ICDIPTRn)
* reg_offset = integer_div(N / 4) * 4
* index = N mod 4 */
	BIC R4, R0, #3 // R4 = reg_offset
	LDR R2, =0xFFFED800
	ADD R4, R2, R4 // R4 = word address of ICDIPTR
	AND R2, R0, #0x3 // N mod 4
	ADD R4, R2, R4 // R4 = byte address in ICDIPTR
	
/* Using register address in R4 and the value in R2 write to
* (only) the appropriate byte */
	STRB R1, [R4]
	POP {R4-R5, PC}
	

/*************************************************************************
* Pushbutton - Interrupt Service Routine
*
* This routine checks which KEY has been pressed. It writes to HEX0
************************************************************************/
.equ KEY_BASE, 0xFF200050
.equ LED_BASE, 0xFF200000
KEY_ISR:


	LDR R0, =KEY_BASE // base address of pushbutton KEY port
	LDR R1, [R0, #0xC] // read edge capture register
	MOV R2, #0xF
	STR R2, [R0, #0xC] // clear the interrupt
	//LDR R0, =LED_BASE // based address of LEDs	
	

//for the time1's gamer to say its turn is done
//in chess timers, players have only one button to use
//to show their turn is done
CHECK_KEY0:
	//if game is stopped, key0 and key1 shouldn't work
	LDR R0, =STOP
	LDR R0, [R0]
	CMP R0, #0
	
	BEQ CHECK_KEY1
	MOV R3, #0x1
	ANDS R3, R3, R1 // check for KEY0
	BEQ CHECK_KEY1
	//MOV R2, #0b1
	//STR R2, [R0] 	// display "1"
	
	LDR R3, =RUN	//load the RUN's address into R3
	LDR R7, [R3]	//load RUN's value to the R7
	
	CMP R7, #0		//checks whether its time1's player turn
	BNE END_KEY_ISR
	
	//if EXTRA is "1", then it shows the game is in x+3 format.
	//adding 3 seconds when its turn is over.
	LDR R7, =EXTRA
	LDR R7, [R7]
	CMP R7, #1
	LDREQ R0, =TIME1
	LDREQ R1, [R0]
	ADDEQ R1, R1, #3	//adding 3 seconds to time1.
	STREQ R1, [R0]
	
	LDR R3, =RUN	//load the RUN's address into R3
	LDR R7, [R3]	//load RUN's value to the R7
	
	EOR R7, R7, #1	//XOR for reverse the value of R7 which is RUN's value
	STR R7, [R3]	//Update RUN's value with store
	
	
	B END_KEY_ISR

//for the time2's gamer to say its turn is done
CHECK_KEY1:
	//if game is stopped, key0 and key1 shouldn't work
	LDR R0, =STOP
	LDR R0, [R0]
	CMP R0, #0
	
	BEQ CHECK_KEY2
	MOV R3, #0x2
	ANDS R3, R3, R1 // check for KEY1
	BEQ CHECK_KEY2
	//MOV R2, #0b10
	//STR R2, [R0]	// display "2"
	
	LDR R3, =RUN	//load the RUN's address into R3
	LDR R7, [R3]	//load RUN's value to the R7
	
	CMP R7, #1		//checks whether its time2's player turn
	BNE END_KEY_ISR
	
	//if EXTRA is "1", then it shows the game is in x+3 format.
	//adding 3 seconds when its turn is over.
	LDR R7, =EXTRA
	LDR R7, [R7]
	CMP R7, #1
	LDREQ R0, =TIME2
	LDREQ R1, [R0]
	ADDEQ R1, R1, #3		//adding 3 seconds to time2.
	STREQ R1, [R0]

	LDR R3, =RUN	//load the RUN's address into R3
	LDR R7, [R3]	//load RUN's value to the R7
	
	EOR R7, R7, #1	//XOR for reverse the value of R7 which is RUN's value
	STR R7, [R3]	//Update RUN's value with store
	
	B END_KEY_ISR

CHECK_KEY2:
	
	MOV R3, #0x4
	ANDS R3, R3, R1 // check for KEY2
	BEQ IS_KEY3
	//MOV R2, #0b100
	//STR R2, [R0] // display "3"
	
	//RESET changes to "1" to reset the game
	LDR R3, =RESET	//load the RESET's address into R3
	MOV R7, #1
	STR R7, [R3]	//store "1"to the RESET
	
	B END_KEY_ISR

IS_KEY3:
	MOV R3, #0x8
	ANDS R3, R3, R1 // check for KEY3
	BEQ END_KEY_ISR
	//MOV R2, #0b1000
	//STR R2, [R0] // display "4"
	
	//This subroutine is used for pause/run operation.
	//When the key3 is pressed and released, enable bit of private timer will be reversed
	//With this, code can achieve stop or run using key3.
	STOPTIMER:
		PUSH {R0-R4,LR}			//push operation for r0-r4 range
		LDR R1, =0xfffec608		//loads CONTROL part of the private timer into R1
		LDR R4, [R1]			//CONTROL's value loaded to R4
		EOR R3, R4, #1			//Enable bit is reversed and new CONTROL's value loaded to R3
		STR R3, [R1]			//Last value is loaded to CONTROL
		
		LDR R1, =STOP
		LDR R4, [R1]
		CMP R4, #1
		LDREQ R0, =0xff200000	//LEDs address
		MOVEQ R1, #1			//right-most LED will be "on" while game is stopped
		STREQ R1, [R0]
		
		LDRNE R0, =0xff200000		//LEDs address
		MOVNE R1, #0b1000000000	//left-most LED will be "on" while game is running
		STRNE R1, [R0]
		
		//This part for the start/stop of the game
		LDR R1, =STOP			//loads STOP's address to R1
		LDR R4, [R1]			//R4 now have STOP's value
		EOR R3, R4, #1			//XOR for reverse the value of STOP
		STR R3, [R1]			//store that value into STOP
		POP {PC,R0-R4}			//pop operation for r0-r4 range and PC
		

END_KEY_ISR:
	BX LR



PRIV_TIME_ISR:

	LDR R0, =0xfffec60c	//Timer interrupt status address
	MOV R2, #1			//Moves 1 to the R2
	STR R2, [R0] 		//Clear the interrupt status
	
	LDR R0, =RUN		//checks to find which player's turn is on
	LDR R1, [R0]
	CMP R1, #0
	
	LDREQ R0, =TIME1	//if RUN is "0", player1's turn
	LDREQ R1, [R0]
	
	LDRNE R0, =TIME2	//if RUN is "1", player2's turn
	LDRNE R1, [R0]
	
	CMP R1, #0			//If TIME is 0
	BLEQ RESET_ALL		//reset the timer
	BEQ end				//End of the game

	
	LDR R0, =0xff200020 //seven segment
	
	B shifting
	BX LR

///////////////////////////////////////////////////
/*
Shifting is used to get TIME1 and TIME2
and changes them to the decimal format.
Their decimal numbers' digits are moved to registers.
With this, display operations can be possible.
*/
shifting:
	
	PUSH {R0-R12,LR}
	
	LDR R1, =TIME1
	LDR R0, [R1]
	
	/*In this part of the code, TIME is in Hexa form.
    So, with this, it can find its decimal version and digit by digit move them to R5, R6, R7. For instance: decimal num:234
    R5=4, R6=3, R7=2 in this case.
    */
	
	//R10 = TIME1
	MOV R10,R0
	MOV R11,#10		//move 10 to R11, because division works with it
	BL Division
	MOV R5,R10		//move remainder of operation to R5 (lowest digit of decimal num)
	MOV R0,R12		//move (the number of times which 10 can be subtracted from the number) to R0.
	
	//use R0 for same operations
	MOV R10,R0
	MOV R11,#10
	BL Division
	MOV R6,R10
	MOV R0,R12

	MOV R10,R0
	MOV R11,#10
	BL Division
	MOV R7,R10
	MOV R0,R12
	
	
	////////////////TIME2
	
	LDR R1, =TIME2
	LDR R0, [R1]
	
	/*In this part of the code, TIME is in Hexa form.
    So, with this, it can find its decimal version and digit by digit move them to R8, R9, R10. For instance: decimal num:234
    R8=4, R9=3, R10=2 in this case.
    */
	
	//R10 = TIME2
	MOV R10,R0
	MOV R11,#10		//move 10 to R11, because division works with it
	BL Division
	MOV R8,R10		//move remainder of operation to R5 (lowest digit of decimal num)
	MOV R0,R12		//move (the number of times which 10 can be subtracted from the number) to R0.
	
	//use R0 for same operations
	MOV R10,R0
	MOV R11,#10
	BL Division
	MOV R9,R10
	MOV R0,R12

	MOV R10,R0
	MOV R11,#10
	BL Division
	MOV R10,R10
	MOV R0,R12
	
	BL Display		//to show times in 7-segment displays
	
	POP {R0-R12,PC}


///////////////////////////////////////////////////

/*
This is the display that shows the first status of the game.
Both players have to have the same time in the beginning.
So, there is no need to use TIME2's registers in this case.
*/
Display0:
	
	PUSH {R0-R4,LR}
	
	LDR R0, =0xff200020	//7-segment
	LDR R1, =HEXTABLE
	MOV R4, #0			//R4 ve R9 u burda 0 lıyoruz.
	MOV R2, #0
	MOV R3, #0

	
	LDRB R2, [R1, R5]	//Player2's time
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R7]	//Player1's time
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R6]	//Player1's time
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R5]	//Player1's time
	ORR R4, R4, R2
	
	LDRB R2, [R1, R7]	//R3 is used for other 2 digits of player2
	ORR R3, R3, R2
	LSL R3, #8
	
	LDRB R2, [R1, R6]	//Player2's time
	ORR R3, R3, R2
	
	
	STR R4,[R0] 		//show them in 7-segment display
	STR R3,[R0, #16]
	
	POP {R0-R4,LR}
	BX LR
	
/////////////////////////////////////////////
/*
This display is used for mid-game.
After display0 is used for the first status of the game,
this display changes TIME1 and TIME2 and displays their current values
in 7-segment displays. Also, it handles the formatting of the timer.
*/
Display:
	
	PUSH {R0-R4,LR}
	PUSH {R8-R12}
	
	//for TIME2, formatting
	LDR R1, =TIME2
	
	//when +3 is occured, if time exceeds 60 sec, this part will handle that
	CMP R9, #6
	ADDEQ R10, R10, #1
	MOVEQ R9, #0
	
	MOVEQ R12, #100
	MULEQ R0,R10,R12
	ADDEQ R0,R0,R8
		
	STREQ R0, [R1]
	
	
	//for TIME1, formatting
	LDR R1, =TIME1
	
	//when +3 is occured, if time exceeds 60 sec, this part will handle that
	CMP R6, #6
	ADDEQ R7, R7, #1
	MOVEQ R6, #0
	
	MOVEQ R12, #100
	MULEQ R0,R7,R12
	ADDEQ R0,R0,R5
		
	STREQ R0, [R1]
	
	
	
	LDR R0, =0xff200020		//7-segment
	LDR R1, =HEXTABLE
	MOV R4, #0
	MOV R2, #0
	MOV R3, #0
	
	
	//R7-R6-R5 = time1
	//R10-R9-R8 = time2

	LDRB R2, [R1, R8]	//TIME2
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R7]	//TIME1
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R6]	//TIME1
	ORR R4, R4, R2
	LSL R4, #8
	
	LDRB R2, [R1, R5]	//TIME1
	ORR R4, R4, R2
	
	LDRB R2, [R1, R10]	//Use R3 for remaining 2 digits of TIME2
	ORR R3, R3, R2
	LSL R3, #8
	
	LDRB R2, [R1, R9]	//TIME2
	ORR R3, R3, R2
	
	
	STR R4,[R0] 		//Store them into 7-segment
	STR R3,[R0, #16]
	
	
	//Time decreasing operation is handling here
	//Firstly, it finds which player's turn is on
	LDR R0, =RUN
	LDR R1, [R0]
	CMP R1, #0
	BEQ time1_decrease

	time2_decrease:
		
		LDR R1, =TIME2
		LDR R0, [R1]	
		
		//if last 2 digits are 0, minute should be minus 1
		//after that, seconds should be 59.
		ADD R2,R8,R9
		CMP R2, #0
		SUBEQ R10, R10, #1
		MOVEQ R9, #5
		MOVEQ R8, #9
		
		MOVEQ R11, #10
		MOVEQ R12, #100
		
		//This part is storing TIME2 in hex format to memory
		MULEQ R10,R10,R12
		MULEQ R9, R9, R11
		ADDEQ R10,R10,R9
		ADDEQ R10,R10,R8
		
		STREQ R10, [R1]
		
		//if last 2 digits are not 0
		//basically subtract the TIME2
		SUBNE R0, R0, #1
		STRNE R0, [R1]
		B display_end
	
	time1_decrease:
		
		LDR R1, =TIME1
		LDR R0, [R1]
		
		//if last 2 digits are 0, minute should be minus 1
		//after that, seconds should be 59.
		ADD R2,R5,R6
		CMP R2, #0
		SUBEQ R7, R7, #1
		MOVEQ R6, #5
		MOVEQ R5, #9
		
		MOVEQ R11, #10
		MOVEQ R12, #100
		
		//This part is storing TIME1 in hex format to memory
		MULEQ R7,R7,R12
		MULEQ R6, R6, R11
		ADDEQ R7,R7,R6
		ADDEQ R7,R7,R5
		
		STREQ R7, [R1]
		
		//if last 2 digits are not 0
		//basically subtract the TIME1
		SUBNE R0, R0, #1
		STRNE R0, [R1]
	
	display_end:
	
	POP {R8-R12}
	POP {R0-R4,LR}
	BX LR

	
////////////////////////////////////////////////////////

/*
This is the configuration of a private timer.
Cortex-A9 Private Timer.
*/
CONFIG_PRIV_TIME:

	LDR R2, =0xfffec600 	//A9 Private Timer
	
	LDR R3, =200000000		//1 second
	STR R3, [R2]			//load to the timer

	MOV R3, #0b111			//control for timer
	STR R3, [R2, #8] 		//load control
	
	//Resetting registers that are used to "0"
	MOV R2, #0
	MOV R3, #0
	
	BX LR

////////////////////////////////////////////////////////

//this is used for resetting R0-R12.
//stack also can be used but this works better with
//restarting game with compile and load option that cpulator offers.
RESET_ALL_NUM_REGISTERS:
	
	MOV R0, #0
	MOV R1, #0
	MOV R2, #0
	MOV R3, #0
	MOV R4, #0
	MOV R5, #0
	MOV R6, #0
	MOV R7, #0
	MOV R8, #0
	MOV R9, #0
	MOV R10, #0
	MOV R11, #0
	MOV R12, #0
	
	BX LR

////////////////////////////////////////////////////////

/*
By using this, hexadecimal numbers can be converted to decimal.
This used in shifting operations.
*/
Division:
	PUSH {R0-R9,LR}
	MOV R12 , #0	 //move 0 to R12
	SUB R12,R12,#1	//make sure R12 starts with "-1"
	CMP R10,R11		//if R10 (which is our number) is higher than R11="10"
	MOVMI R12,#0	/* if R10 is lower than 10, R12 will be "0" because you can't   perform this "R10/10" */
	BMI leave		//if negative
	
	//to find R12's result, keep subtract 10(R11) from our number(R10)
	Div_loop:
		SUBS R10,R10,R11    //27-10 = 17; 17-10 = 7; -3
		ADD R12,R12,#1		//R12 = -1 + 1 = 0; R12 = 1; 2
		BGE Div_loop		//keep subtract until you can't

		CMP R10, #0			//if our number is went down to negative numbers	
		ADDLT R10,R10,R11	//make sure to increase with "10" to get remainder.
		
	leave:
		POP {R0-R9,LR}	
		BX LR

////////////////////////////////////////////////////////

/*
This is reset all. With this, the timer can be stopped and others can be reset.
*/
RESET_ALL:
	LDR R2, =0xfffec600 //A9 Private Timer
	MOV R4, #0b000 //control for timer
	STR R4, [R2, #8] //load control
	
	//it changes STOP, RESET, RUN and EXTRA to 0.
	LDR R2, =STOP
	MOV R4, #0
	STR R4, [R2]
	
	LDR R0, =EXTRA
	MOV R1, #0
	STR R1, [R0]
	
	LDR R0, =RESET
	MOV R1, #0
	STR R1, [R0]
	
	LDR R0, =RUN
	MOV R1, #0
	STR R1, [R0]
	
	LDR R0, =0xff200000		//LEDs address
	LDR R1, =0x3ff	//all LEDs are "on" to show game is finished
	STR R1, [R0]
	
	B shifting	//to print 000 for the last time, otherwise, it prints 1 and stops the counter at the end
	
	BX LR

////////////////////////////////////////////////////////

end: B end
RUN: .word 0x0		//whose turn 
TIME1: .word 0x0	//player1's time
TIME2: .word 0x0	//player2's time
STOP: .word 0x0		//start/stop of the game
EXTRA: .word 0x0  	//x+3 game is played or not
RESET: .word 0x0	//reset the game if it is "1"

HEXTABLE: .byte 0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f
.end
