; LOW-LEVEL CONS-MUNGING ROUTINES FOR CC		-*-LISP-*-

;** Still have to worry about how to detect that the pdp11 has
;** 105 foobar'ed the machine and invalidated our saved status.
;** Also what to do when initially starting up.
;** Perhaps the console display generator should call CC-FULL-SAVE?

(declare(eval(read)))
(PROGN (LOAD '(MACROS > DSK LISPM))
       (LOAD '(DEFMAC FASL DSK LISPM2))
       (LOAD '(LMMAC > DSK LISPM2)))

(declare(eval(read)))
 (DEFUN **STRING** MACRO (X) `',(CADR X)) ;Bubbles in my brain

(COMMENT DIAGNOSTIC INTERFACE DEFINITION)

;LATER, THE FOLLOWING WILL BE TURNED INTO LISP SYMBOLS
;DIAGNOSTIC INTERFACE INFO:
;764000 READ
;	100000	SPC PARITY ERROR
;	 40000	DISPATCH PARITY ERROR
;	 20000	HIGH ERROR OR HALT
;	 10000	CONTROL MEM PARITY ERROR (IN IR NOW)
;	  4000	M MEM PARITY
;	  2000	A MEM PARITY
;	  1000	PDL BUFFER PARITY
;	   400	MAIN MEMORY PARITY
;     BITS 7-0	OB23-16

;764002	READ
;	100000	NOT ERRHALT
;	 40000	NOT HIGH OK
;	 20000	S RUN (1 IF RUN AND NO ERRORS)
;	 10000	SINGLE STEP DONE
;    BITS 11-0	OPC (SHIFT REGISTER OUTPUT)

;764004	READ
;    BITS 15-0	OB15-0

;764006	READ
;    BITS 11-0	PC11-0

;764010	READ
;	100000	W-CMEM NEXT CLOCK
;	 40000	OA-MOD (IN IR NOW)
;	 20000	NO-OP FLAG
;    BITS 12-0	IR44-32

;764012	READ
;	100000	UNUSED
;	 40000	NOT MAIN MEM WAIT
;	 20000	W-PDLB
;	 10000	W-SPC
;	  4000	PAGE FAULT
;	  2000	JC-TRUE
;	  1000	PCS1	0=PC+1	1=DISP
;	   400	PCS0	2=POPJ	3=IR(JUMP)
;     BITS 7-0	OB31-24

;764014	READ
;    BITS 15-0	IR15-0

;764016 READ
;    BITS 15-0	IR31-16

;764000	WRITE
;    BITS 15-0	DIAG INSTR BUFFER 15-0

;764002 WRITE
;    BITS 15-0	DIAG INSTR BUFFER 31-16

;764004	WRITE
;    BITS 11-0	DIAG INSTR BUFFER 43-32

;764006	WRITE
;	    40	OPC CLOCK
;	    20	NO-OP (INHIBIT INSTRS FROM WRITING)
;	    10	DEBUG (INHIBIT OA-MOD AND C-MEM READ AND WRITE; ENABLE DIAG INSTR BUF)
;	     4	RESET
;	     2	SINGLE STEP (WRITE TO 1 THEN TO 0) [[CODE APPEARS TO DO 0 THEN 1 ?]]
;	     1	RUN

;THE UNIBUS MAP IS LOCATIONS 764300-764476 AND CONTROLS LOCATIONS 140000-237776
;BIT 15 IS WRITE ENABLE, BITS 13-0 ARE PAGE NUMBER.
;WRITING INTO THE UNIBUS MAPPED LOCATIONS, WHEN BITS 13-11 OF THE MAP REGISTER
;ARE 1S, CAUSE THE DATA TO BE WRITTEN INTO THE READ-MEMORY-DATA REGISTER OF CONS.

(COMMENT DECLARATIONS)

(DECLARE (SPECIAL CC-NOOP-FLAG CC-MODE-REG CC-RUNNING
		  CC-PASSIVE-SAVE-VALID CC-FULL-SAVE-VALID
		  CC-PDL-BUFFER-INDEX-CHANGED-FLAG ;NIL IF NOT SAVED YET
		  CC-SAVED-PDL-BUFFER-INDEX  ;SAVED HERE WHEN IT IS SAVED
		  CC-MICRO-STACK-SAVED-FLAG  ;NIL IF POINTER AND STACK NOT SAVED YET
		  CC-SAVED-MICRO-STACK-PTR	;SAVED HERE WHEN IT IS SAVED
		  CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG	;NIL IF NOT SAVED YET
		  CC-SAVED-LEVEL-1-MAP-LOC-0
		  CC-ERROR-STATUS CC-SAVED-PC CC-SAVED-IR CC-SAVED-OBUS CC-SAVED-NOOP-FLAG
		  CC-SAVED-A-MEM-LOC-1 CC-SAVED-M-MEM-LOC-0
		  CC-SAVED-VMA CC-SAVED-MRD CC-SAVED-MWD CC-SAVED-MAP-AND-FAULT-STATUS
		  CC-MWD-CHANGED-FLAG CC-VMA-CHANGED-FLAG
))

(SETQ CC-PASSIVE-SAVE-VALID NIL CC-FULL-SAVE-VALID NIL CC-RUNNING NIL)

(ARRAY CC-SAVED-OPCS FIXNUM 8)
(ARRAY CC-MICRO-STACK FIXNUM 32.)
;COMPILER APPARENTLY DOES THE FOLLOWING ITSELF
;(DECLARE (ARRAY* (FIXNUM CC-SAVED-OPCS 8) (FIXNUM CC-MICRO-STACK 32.)))

(DECLARE (FIXNUM (CC-READ-OBUS)
		 (CC-READ-PC)
		 (CC-READ-STATUS)
		 (CC-READ-M-MEM FIXNUM)
		 (CC-READ-A-MEM FIXNUM)
		 (CC-READ-PDL-BUFFER FIXNUM)
		 (CC-READ-MICRO-STACK-PTR)
		 (CC-READ-DISP-CONST)
		 (CC-READ-D-MEM FIXNUM)
		 (CC-READ-LEVEL-1-MAP FIXNUM)
		 (CC-ADDRESS-LEVEL-2-MAP FIXNUM)
		 (CC-READ-LEVEL-2-MAP FIXNUM)
		 CC-MODE-REG
		 CC-SAVED-PC
		 CC-SAVED-OBUS
		 CC-SAVED-PDL-BUFFER-INDEX
		 CC-SAVED-MICRO-STACK-PTR
		 CC-SAVED-A-MEM-LOC-1
		 CC-SAVED-M-MEM-LOC-0
		 CC-SAVED-LEVEL-1-MAP-LOC-0
		 CC-SAVED-VMA
		 CC-SAVED-MRD
		 CC-SAVED-MWD
		 CC-SAVED-MAP-AND-FAULT-STATUS
		 (CNSUBR FIXNUM)
		 (CNSUBW FIXNUM FIXNUM)
		 (LOGLDB FIXNUM NOTYPE) ;TAKES BIGNUM BUT RETURNS FIXNUM
		 (LOGLDB-FROM-FIXNUM FIXNUM FIXNUM)
		 (LOGDPB-INTO-FIXNUM FIXNUM FIXNUM FIXNUM)
)
	 (NOTYPE (CC-WRITE-MRD FIXNUM)
		 (CC-WRITE-MODE-REG)
		 (CC-EXECUTE-3 FIXNUM FIXNUM FIXNUM)
		 (CC-WRITE-M-MEM FIXNUM FIXNUM)
		 (CC-WRITE-A-MEM FIXNUM FIXNUM)
		 (CC-READ-C-MEM FIXNUM)
		 (CC-WRITE-C-MEM FIXNUM NOTYPE)
		 (CC-WRITE-PC FIXNUM)
		 (CC-WRITE-PDL-BUFFER-INDEX FIXNUM)
		 (CC-WRITE-PDL-BUFFER FIXNUM FIXNUM)
		 (CC-WRITE-D-MEM FIXNUM FIXNUM)
		 (CC-WRITE-DISP-CONST FIXNUM)
		 (CC-WRITE-LEVEL-1-MAP FIXNUM FIXNUM)
		 (CC-WRITE-LEVEL-2-MAP FIXNUM FIXNUM)
		 (CC-R-E FIXNUM) ;CAN'T RETURN FIXNUM DUE TO DAMNABLE C MEM BIGNUMS
		 (CC-R-D FIXNUM NOTYPE)
		 (CC-WRITE-C-MEM-3-16BIT-WORDS FIXNUM FIXNUM FIXNUM FIXNUM)
)

(SPECIAL RAPC RASIR RAOBS RANOOPF RASTS 
	 RACMO RACME RADME RAPBE RAM1E RAM2E RAAME RAUSE RAMME RAFSE RAFDE 
	 RARGE RACSWE RARDRE RACIBE RAGO RASTOP RARDRO RAFDO RAOPCE
	 RAORG RAFSO RAM2O RADMO RAM1O 
	 RAPI RAPP RAUSP RAIR RAQ RADC RAMOD RAOPCO RARSET
	 RARS RASTEP RASA RAAMO RAMMO RARCON RAPBO RAUSO)
(FIXNUM RAPC RASIR RAOBS RANOOPF RASTS 
	 RACMO RACME RADME RAPBE RAM1E RAM2E RAAME RAUSE RAMME RAFSE RAFDE 
	 RARGE RACSWE RARDRE RACIBE RAGO RASTOP RARDRO RAFDO RAOPCE
	 RAORG RAFSO RAM2O RADMO RAM1O
	 RAPI RAPP RAUSP RAIR RAQ RADC RAMOD RAOPCO RARSET
	 RARS RASTEP RASA RAAMO RAMMO RARCON RAPBO RAUSO)
)

;THESE CAN BE REF'ED IF SWITCH BETWEEN TEN MODE AND 11 MODE.  TRY TO MINIMIZE RESULTING
; CONFUSION.
	 (SETQ   CC-NOOP-FLAG NIL 
		 CC-PDL-BUFFER-INDEX-CHANGED-FLAG NIL 
		 CC-MICRO-STACK-SAVED-FLAG NIL 
		 CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG NIL 
		 CC-ERROR-STATUS 0 
		 CC-SAVED-IR 0
		 CC-SAVED-NOOP-FLAG NIL 
		 CC-MWD-CHANGED-FLAG NIL 
		 CC-VMA-CHANGED-FLAG NIL
	 	 CC-MODE-REG 0 
		 CC-SAVED-PC 0
		 CC-SAVED-OBUS 0
		 CC-SAVED-PDL-BUFFER-INDEX 0
		 CC-SAVED-MICRO-STACK-PTR 0
		 CC-SAVED-A-MEM-LOC-1 0
		 CC-SAVED-M-MEM-LOC-0 0
		 CC-SAVED-LEVEL-1-MAP-LOC-0 0
		 CC-SAVED-VMA 0
		 CC-SAVED-MRD 0
		 CC-SAVED-MWD 0
		 CC-SAVED-MAP-AND-FAULT-STATUS 0)


(COMMENT MACROS)

(declare(eval(read))(eval(read))(eval(read))) ;Foo, MACRO is a FEXPR

(DEFMACRO LOGAND REST
  `(BOOLE 1 . ,REST))

(DEFMACRO LOGIOR REST
  `(BOOLE 7 . ,REST))

(DEFMACRO LOGXOR REST
  `(BOOLE 6 . ,REST))

;BUILD UP A WORD OUT OF A BUNCH OF FIELDS
(DEFUN BUILD MACRO (X)
  (DO ((X (CDR X) (CDDR X))
       (EXP 0))
      ((NULL X) EXP)
    (SETQ EXP `(LOGDPB ,(CADR X) ,(CAR X) ,EXP))))

(declare(eval(read)))
  (progn (VALRET ":SL�P")
	 (FASLOAD UTIL1 FASL DSK LISPM)) ;NEEDED BY MACRO

;BUILD AND EXECUTE A MICRO INSTRUCTION.  WORKS HARD TO AVOID BIGNUM+NUMBER CONSING.
;ALSO RECOGNIZES COMPILE TIME CONSTANTS.  MOST MICRO INSTRUCTIONS EXECUTED BY
;THIS STUFF ARE COMPLETELY CONSTANT AT COMPILE TIME.
(DEFUN CC-EXECUTE MACRO (X)
  (LET ((HIGH 0)		;BUILD INSTRUCTION WORD IN THREE PIECES
	(MIDDLE 0)
	(LOW 0)
	(FIELD NIL)
	(P NIL)
	(P+S NIL)
	(ARG NIL)
	(ARG-CONSTANT-P NIL)
	(EXECUTOR (COND ((EQUAL (CADR X) '(WRITE))
			 (SETQ X (CDR X))
			 'CC-EXECUTE-W)
			(T 'CC-EXECUTE-R))))
     ;FIRST PASS DOES ALL THE CONSTANT ONES
     (DO X (CDR X) (CDDR X) (NULL X)
       (SETQ FIELD (SYMEVAL (CAR X)) ARG (CADR X)
	     P (LSH FIELD -6) P+S (+ P (LOGAND 77 FIELD)))
       (COND ((AND (SYMBOLP ARG) (GET ARG 'CONSTANT))	;CONSTANT ARG, DO AT COMPILE TIME
	      (SETQ ARG (SYMEVAL ARG))
	      (AND (< P 20)	;OVERLAPS LOW WORD
		   (SETQ LOW (LOGDPB-INTO-FIXNUM ARG FIELD LOW)))
	      (AND (< P 40)
		   (>= P+S 20)	;OVERLAPS MIDDLE WORD
		   (SETQ MIDDLE
			 (COND ((>= P 20) (LOGDPB-INTO-FIXNUM ARG (- FIELD 2000) MIDDLE))
			       (T (LOGDPB-INTO-FIXNUM (LSH ARG (- P 20))
						      (- P+S 20)
						      MIDDLE)))))
	      (AND (>= P+S 40)	;OVERLAPS HIGH WORD
		   (SETQ HIGH
			 (COND ((>= P 40) (LOGDPB-INTO-FIXNUM ARG (- FIELD 4000) HIGH))
			       (T (LOGDPB-INTO-FIXNUM (LSH ARG (- P 40))
						      (- P+S 40)
						      HIGH))))))))
     ;SECOND PASS FILLS IN THE NON-CONSTANT ONES
     (DO X (CDR X) (CDDR X) (NULL X)
       (SETQ FIELD (SYMEVAL (CAR X)) ARG (CADR X)
	     P (LSH FIELD -6) P+S (+ P (LOGAND 77 FIELD)))
       (COND ((NOT (AND (SYMBOLP ARG) (GET ARG 'CONSTANT)))
	      (AND (< P 20)	;OVERLAPS LOW WORD
		   (SETQ LOW `(LOGDPB-INTO-FIXNUM ,ARG ,FIELD ,LOW)))
	      (AND (< P 40)
		   (>= P+S 20)	;OVERLAPS MIDDLE WORD
		   (SETQ MIDDLE
			 (COND ((>= P 20) `(LOGDPB-INTO-FIXNUM ,ARG ,(- FIELD 2000) ,MIDDLE))
			       (T `(LOGDPB-INTO-FIXNUM (LSH ,ARG ,(- P 20))
						       ,(- P+S 20)
						       ,MIDDLE)))))
	      (AND (>= P+S 40)	;OVERLAPS HIGH WORD
		   (SETQ HIGH
			 (COND ((>= P 40) `(LOGDPB-INTO-FIXNUM ,ARG ,(- FIELD 4000) ,HIGH))
			       (T `(LOGDPB-INTO-FIXNUM (LSH ,ARG ,(- P 40))
						       ,(- P+S 40)
						       ,HIGH))))))))
     `(,EXECUTOR ,LOW ,MIDDLE ,HIGH)))

(COMMENT CONS MICROINSTRUCTION FIELD DEFINITIONS)

(DECLARE (COUTPUT (CONS 'SETQ (EVAL (READ)))))
			;MAKE SYMBOLS AVAILABLE AT BOTH COMPILE TIME & RUN TIME
			;AND DECLARE THEM SPECIAL AND FIXNUM.
((LAMBDA (L)
   (DO L L (CDDR L) (NULL L)
     (COND (COMPILER-STATE
	    (APPLY 'SPECIAL (LIST (CAR L)))
	    (APPLY 'FIXNUM (LIST (CAR L)))))
     (PUTPROP (CAR L) T 'CONSTANT)
     (SET (CAR L) (CADR L)))
   L)
 '(
   ;IR FIELDS
   CONS-IR-OP 4702
     CONS-OP-ALU 0 ;ASSUMED 0 AND OMITTED IN MANY PLACES FOR BREVITY
     CONS-OP-DISPATCH 1
     CONS-OP-JUMP 2
     CONS-OP-BYTE 3
   CONS-IR-POPJ 4601
   CONS-IR-A-SRC 3610
   CONS-IR-M-SRC 3006
    CONS-M-SRC-MRD 42
    CONS-M-SRC-MWD 52
    CONS-M-SRC-VMA 62
    CONS-M-SRC-Q 43
    CONS-M-SRC-PDL-PTR-AND-INDEX 44 ;PI BITS 9-0, PP BITS 19-10
      CONS-PP-BYTE 1212
      CONS-PI-BYTE 0012
    CONS-M-SRC-C-PDL-BUFFER-INDEX 47
    CONS-M-SRC-MICRO-STACK 45 ;USP BITS 31-27, SPCn BITS 15-0
    CONS-M-SRC-MICRO-STACK-POP 55 ;SAME BUT ALSO POPS USP
      CONS-US-POINTER-BYTE 3305
      CONS-US-DATA-BYTE 0020
    CONS-M-SRC-DISP-CONST 46
    CONS-M-SRC-MAP 72
      CONS-MAP-LEVEL-1-BYTE 3305
      CONS-MAP-LEVEL-2-BYTE 0724
   CONS-IR-A-MEM-DEST 1612
     CONS-A-MEM-DEST-INDICATOR 1000  ;ADD THIS TO A MEM ADDRESS
   CONS-IR-M-MEM-DEST 1605
   CONS-IR-FUNC-DEST 2305
    CONS-FUNC-DEST-PDL-BUFFER-INDEX 13
    CONS-FUNC-DEST-PDL-BUFFER-POINTER 14
    CONS-FUNC-DEST-C-PI 12
    CONS-FUNC-DEST-MICRO-STACK-PUSH 15
    CONS-FUNC-DEST-VMA 4
      CONS-VMA-LEVEL-1-BYTE 1413
      CONS-VMA-LEVEL-2-BYTE 0705
    CONS-FUNC-DEST-MWD 1
    CONS-FUNC-DEST-VMA-START-READ 5
    CONS-FUNC-DEST-VMA-START-WRITE 6
    CONS-FUNC-DEST-VMA-WRITE-MAP 7
   CONS-IR-OB 1402
    CONS-OB-MSK 0 ;DEPENDS ON THIS =0 FOR BREVITY
    CONS-OB-ALU 1
    CONS-OB-ALU-RIGHT-1 2
    CONS-OB-ALU-LEFT-1 3
  CONS-IR-MF 1202 ;MISCELLANEOUS FUNCTION
  CONS-IR-ALUF 0210  ;INCLUDING CARRY
    CONS-ALU-SETA 32_2
    CONS-ALU-SETM 37_2
    CONS-ALU-ADD 11_2
  CONS-IR-Q 0002
    CONS-Q-LEFT 1
    CONS-Q-RIGHT 2
    CONS-Q-LOAD 3
  CONS-IR-DISP-CONST 3610
  CONS-IR-DISP-ADDR 1612
  CONS-IR-BYTL-1 0505
  CONS-IR-MROT 0005
  CONS-IR-JUMP-ADDR 1414
  CONS-IR-JUMP-COND 0007
    CONS-JUMP-COND-UNC 47
  CONS-IR-R 1101
  CONS-IR-P 1001
  CONS-IR-N 0701
  CONS-IR-BYTE-FUNC 1402
    CONS-BYTE-FUNC-LDB 1
    CONS-BYTE-FUNC-SELECTIVE-DEPOSIT 2
    CONS-BYTE-FUNC-DPB 3
))

(COMMENT ROUTINES WHICH MANIPULATE THE MACHINE DIRECTLY)

;READ OBUS AS A FIXNUM
(DEFUN CC-READ-OBUS ()
  (LET ((LOW (CNSUBR 764004))
	(MIDDLE (LOGAND 377 (CNSUBR 764000)))
	(HIGH (LOGAND 377 (CNSUBR 764012))))
     (DECLARE (FIXNUM LOW MIDDLE HIGH))
     (+ (LSH HIGH 24.) (LSH MIDDLE 16.) LOW)))

;READ IR AS A BIGNUM
(DEFUN CC-READ-IR ()
  (LET ((LOW (CNSUBR 764014))
	(MIDDLE (CNSUBR 764016))
	(HIGH (CNSUBR 764010)))
     (DECLARE (FIXNUM LOW MIDDLE HIGH))
     (LOGDPB HIGH 4015 (+ (LSH MIDDLE 16.) LOW))))

;READ PC AS A FIXNUM
(DEFUN CC-READ-PC ()
  (LOGAND 7777 (CNSUBR 764006)))

;GET 32-BIT ERROR STATUS WORD
(DEFUN CC-READ-STATUS ()
  (LET ((LOW1 (LOGAND 360 (LSH (CNSUBR 764002) -8)))
	(HIGH1 (LSH (CNSUBR 764000) -8))
	(LOW2 (LOGAND 177 (LSH (CNSUBR 764012) -8)))
	(HIGH2 (LOGAND 160000 (CNSUBR 764010))))
     (DECLARE (FIXNUM LOW1 HIGH1 LOW2 HIGH2))
     (+ LOW1 (LSH HIGH1 8.) (LSH LOW2 16.) (LSH HIGH2 16.))))

;WRITE DIAG IR FROM A BIGNUM
(DEFUN CC-WRITE-DIAG-IR (IR)
  (CNSUBW 764000 (LOGLDB 0020 IR))
  (CNSUBW 764002 (LOGLDB 2020 IR))
  (CNSUBW 764004 (LOGLDB 4020 IR))
  T)

;WRITE A FIXNUM INTO THE READ-MEMORY-DATA REGISTER
;USES MAPPING REGISTER 7
(DEFUN CC-WRITE-MRD (NUM)
  (CNSUBW 764316 134000) ;MR7 := WR-ENB + MAGIC 7
  (CNSUBW 147000 NUM)	 ;WRITE LOW HALF-WORD
  (CNSUBW 147002 (LSH NUM -16.)) ;THEN HIGH HALF-WORD
  T)

;THE WAY THE CONS CLOCK WORKS IS DROPPING BIT 2 OF 764006 CLEARS SSDONE.
;THEN RAISING BIT 2 ASSERTS SSGO WHICH ASSERTS IGO WHICH CAUSES A CLOCK WHICH SETS SSDONE,
;PREVENTING ADDITIONAL CLOCKS.
;WHEN YOU TICK THE CLOCK, IT SITS HIGH FOR A WHILE, THEN GOES LOW, DOES
;ONE WRITE-PULSE, AND COMES HIGH AGAIN, AND STOPS HIGH.

;TICK CLOCK IN DEBUG MODE (EXECUTE IR, LOAD IR FROM DIAG IR)
(DEFUN CC-DEBUG-CLOCK ()
  (CNSUBW 764006 10) ;DEBUG ON, CLEAR SSDONE
  (CNSUBW 764006 12) ;DEBUG ON, TICK CLOCK
  T)

;TICK CLOCK IN NOOP-DEBUG MODE, WHICH FINISHES WRITES
(DEFUN CC-NOOP-DEBUG-CLOCK ()
  (CNSUBW 764006 30) ;DEBUG, NOOP ON, CLEAR SSDONE
  (CNSUBW 764006 32) ;DEBUG, NOOP ON, TICK CLOCK
  (CNSUBW 764006 12) ;CLEAR NOOP, LEAVE SSDONE SET
  T)

;TICK CLOCK IN DEBUG MODE, ALSO NOOP IF CC-NOOP-FLAG IS SET, AND CLEAR CC-NOOP-FLAG
;THIS IS THE DIAG-IR FORM OF SINGLE-STEP
(DEFUN CC-DEBUG-SINGLE-STEP ()
  (COND (CC-NOOP-FLAG
	   (SETQ CC-NOOP-FLAG NIL)
	   (CC-NOOP-CLOCK))
	(T (CC-DEBUG-CLOCK))))

;NORMAL-MODE CLOCK
(DEFUN CC-CLOCK ()
  (CNSUBW 764006 0) ;CLEAR SSDONE
  (CNSUBW 764006 2) ;TICK CLOCK
  T)

;TICK CLOCK IN NORMAL-NOOP MODE
(DEFUN CC-NOOP-CLOCK ()
  (CNSUBW 764006 20) ;NOOP ON, CLEAR SSDONE
  (CNSUBW 764006 22) ;NOOP ON, TICK CLOCK
  (CNSUBW 764006 2)  ;CLEAR NOOP, LEAVE SSDONE SET
  T)

;SINGLE-STEP THE MACHINE (USES CC-NOOP-FLAG)
(DEFUN CC-SINGLE-STEP ()
  (COND (CC-NOOP-FLAG
	   (SETQ CC-NOOP-FLAG NIL)
	   (CC-NOOP-CLOCK))
	(T (CC-CLOCK))))

(COMMENT ROUTINE TO EXECUTE A SYMBOLIC INSTRUCTION)

;CALL THESE VIA THE CC-EXECUTE MACRO

;FOR READING.  WILL LEAVE THE DESIRED DATA ON THE OBUS
(DEFUN CC-EXECUTE-R (LOW MIDDLE HIGH)
  (CNSUBW 764000 LOW)		;PUT INSTRUCTION INTO MACHINE
  (CNSUBW 764002 MIDDLE)
  (CNSUBW 764004 HIGH)
  (CC-NOOP-DEBUG-CLOCK))	;PUT IT INTO IR, IT WILL THEN ROUTE PROPER STUFF TO OBUS

;FOR WRITING.  WILL CLOCK THE MACHINE IN NON-DEBUG MODE WHICH IS
;GOOD FOR READING AND WRITING CONTROL MEMORY.
(DEFUN CC-EXECUTE-W (LOW MIDDLE HIGH)
  (CNSUBW 764000 LOW)		;PUT INSTRUCTION INTO MACHINE
  (CNSUBW 764002 MIDDLE)
  (CNSUBW 764004 HIGH)
  (CC-NOOP-DEBUG-CLOCK)		;PUT IT INTO IR, IT WILL START EXECUTING
  (CC-CLOCK)			;CLOCK THAT INSTRUCTION, GARBAGE TO IR
  (CC-NOOP-CLOCK)		;CLOCK MACHINE AGAIN TO CLEAR PASS AROUND PATH, LOAD IR
  T)				; WITH INSTRUCTION JUMPED TO, ETC.

(COMMENT READ AND WRITE RAMS)

;READ M-MEMORY DIRECTLY OUT OF MACHINE
;WE USE THIS FOR READING FUNCTIONAL SOURCES ALSO
(DEFUN CC-READ-M-MEM (ADR)
  (CC-EXECUTE CONS-IR-M-SRC ADR	;PUT IT ONTO THE OBUS
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (CC-READ-OBUS))

;WRITE INTO M-MEMORY
(DEFUN CC-WRITE-M-MEM (LOC VAL)
  (CC-WRITE-MRD VAL)		;PUT VALUE INTO THE MRD REGISTER
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD	;MOVE IT TO DESIRED PLACE
	      CONS-IR-ALUF CONS-ALU-SETM 
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-M-MEM-DEST LOC))

;READ A-MEMORY
(DEFUN CC-READ-A-MEM (ADR)
  (CC-EXECUTE CONS-IR-A-SRC ADR	;PUT IT ONTO THE OBUS
	      CONS-IR-ALUF CONS-ALU-SETA
	      CONS-IR-OB CONS-OB-ALU)
  (CC-READ-OBUS))

;WRITE INTO A-MEMORY
(DEFUN CC-WRITE-A-MEM (LOC VAL)
  (CC-WRITE-MRD VAL)		;PUT VALUE INTO THE MRD REGISTER
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD	;MOVE IT TO DESIRED PLACE
	      CONS-IR-ALUF CONS-ALU-SETM 
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-A-MEM-DEST (+ CONS-A-MEM-DEST-INDICATOR LOC)))

;READ CONTROL-MEMORY
(DEFUN CC-READ-C-MEM (ADR)
  (CC-EXECUTE (WRITE)
	      CONS-IR-OP CONS-OP-JUMP	;DO JUMP INSTRUCTION TO DESIRED PLACE
	      CONS-IR-JUMP-ADDR ADR
	      CONS-IR-JUMP-COND CONS-JUMP-COND-UNC)
  (CC-READ-IR))			;RETURN CONTENTS

;WRITE CONTROL-MEMORY
(DEFUN CC-WRITE-C-MEM (ADR VAL)
  (CC-WRITE-A-MEM 1 (LOGLDB 4020 VAL))	;1@A GETS HIGH 16 BITS
  (CC-WRITE-M-MEM 0 (LOGLDB 2040 VAL))	;0@M GETS LOW 32 BITS
  (CC-EXECUTE (WRITE)
	      CONS-IR-OP CONS-OP-JUMP	;EXECUTE MAGIC FLAVOR OF JUMP INSTRUCTION
	      CONS-IR-JUMP-ADDR ADR
	      CONS-IR-P 1		;R+P=WRITE C MEM
	      CONS-IR-R 1
	      CONS-IR-A-SRC 1
	      ;CONS-IR-M-SRC 0
	      CONS-IR-JUMP-COND CONS-JUMP-COND-UNC))

;THIS ONE IS DIFFERENT FROM EVERYTHING ELSE.  IT AGREES WITH THE ULOAD FORMAT.
(DEFUN CC-WRITE-C-MEM-3-16BIT-WORDS (ADR HIGH MIDDLE LOW)
  (CC-WRITE-A-MEM 1 HIGH)		;1@A GETS HIGH 16 BITS
  (CC-WRITE-M-MEM 0 (+ (LSH MIDDLE 16.) LOW))  ;0@M GETS LOW 32 BITS
  (CC-EXECUTE (WRITE)
	      CONS-IR-OP CONS-OP-JUMP	;EXECUTE MAGIC FLAVOR OF JUMP INSTRUCTION
	      CONS-IR-JUMP-ADDR ADR
	      CONS-IR-P 1		;R+P=WRITE C MEM
	      CONS-IR-R 1
	      CONS-IR-A-SRC 1
	      ;CONS-IR-M-SRC 0
	      CONS-IR-JUMP-COND CONS-JUMP-COND-UNC))

;WRITE INTO MACHINE'S PC
(DEFUN CC-WRITE-PC (PC)
  (LET ((TEM NIL))
    (CC-EXECUTE CONS-IR-OP CONS-OP-JUMP	;JUMP INSTRUCTION TO IR
		CONS-IR-JUMP-ADDR PC
		CONS-IR-JUMP-COND CONS-JUMP-COND-UNC)
    (CC-DEBUG-CLOCK)		;CLOCK INTO PC
    (OR (= PC (SETQ TEM (CC-READ-PC)))	;CHECK?
	(ERROR '|CORRECT . ACTUAL - LOSSAGE - CC-WRITE-PC| (CONS PC TEM) 'FAIL-ACT))
    T))

;SAVE THE PDL-BUFFER-INDEX INTO CC-SAVED-PDL-BUFFER-INDEX
(DEFUN CC-SAVE-PDL-BUFFER-INDEX ()
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-PDL-PTR-AND-INDEX ;PUT PDL INDEX ONTO OBUS BITS 9-0
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (SETQ CC-PDL-BUFFER-INDEX-CHANGED-FLAG T
	CC-SAVED-PDL-BUFFER-INDEX (LOGLDB-FROM-FIXNUM CONS-PI-BYTE (CC-READ-OBUS))))

;WRITE INTO PDL-BUFFER-INDEX
(DEFUN CC-WRITE-PDL-BUFFER-INDEX (VAL)
  (CC-WRITE-MRD VAL)					;PUT VALID INTO MRD
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD		;MOVE INTO PDL INDEX
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-PDL-BUFFER-INDEX))

;READ THE PDL BUFFER
(DEFUN CC-READ-PDL-BUFFER (ADR)
  (OR CC-PDL-BUFFER-INDEX-CHANGED-FLAG
      (CC-SAVE-PDL-BUFFER-INDEX))			;SAVE PDL INDEX IF NECESSARY
  (CC-WRITE-PDL-BUFFER-INDEX ADR)			;ADDRESS THE PDL
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-C-PDL-BUFFER-INDEX	;READ IT OUT
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (CC-READ-OBUS))					;RETURN CONTENTS

;WRITE THE PDL BUFFER
(DEFUN CC-WRITE-PDL-BUFFER (ADR VAL)
  (OR CC-PDL-BUFFER-INDEX-CHANGED-FLAG (CC-SAVE-PDL-BUFFER-INDEX)) ;SAVE PDL INDEX IF NECESSARY
  (CC-WRITE-PDL-BUFFER-INDEX ADR)			;ADDRESS THE PDL
  (CC-WRITE-MRD VAL)					;PUT VALUE INTO MRD
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD		;STORE INTO PDL BUFFER
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-C-PI))

;READ OUT THE MICRO STACK POINTER
(DEFUN CC-READ-MICRO-STACK-PTR ()
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MICRO-STACK	;READ OUT THE MICRO STACK PTR
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (LOGLDB-FROM-FIXNUM CONS-US-POINTER-BYTE (CC-READ-OBUS)))

;SAVE THE ENTIRE MICRO STACK (AND THE POINTER)
(DEFUN CC-SAVE-MICRO-STACK ()
  (COND ((NOT CC-MICRO-STACK-SAVED-FLAG)	;DON'T DO IF DID ALREADY
	 (SETQ CC-MICRO-STACK-SAVED-FLAG T)
	 (SETQ CC-SAVED-MICRO-STACK-PTR (CC-READ-MICRO-STACK-PTR))
	 (DO ((COUNT 32. (1- COUNT))	;NOW READ OUT THE WHOLE STACK
	      (IDX CC-SAVED-MICRO-STACK-PTR (LOGAND 37 (1- IDX))))
	     ((= 0 COUNT))
	   (DECLARE (FIXNUM COUNT IDX))
	   (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MICRO-STACK-POP
		       CONS-IR-ALUF CONS-ALU-SETM
		       CONS-IR-OB CONS-OB-ALU)
	   (STORE (CC-MICRO-STACK IDX)
		  (LOGLDB-FROM-FIXNUM CONS-US-DATA-BYTE (CC-READ-OBUS)))
	   (CC-CLOCK)))))		;NOW DECREMENT USP


;RESTORE THE MICRO STACK AND THE POINTER
(DEFUN CC-RESTORE-MICRO-STACK ()
  (COND (CC-MICRO-STACK-SAVED-FLAG 
	 (DO ()						;UNTIL USP EQUALS THE DESIRED VALUE,
	     ((= CC-SAVED-MICRO-STACK-PTR (CC-READ-MICRO-STACK-PTR)))
	     (CC-EXECUTE (WRITE) CONS-IR-M-SRC CONS-M-SRC-MICRO-STACK-POP)) ;KEEP POPPING IT
	 (DO ((COUNT 32. (1- COUNT))			;NOW RESTORE THE WHOLE STACK
	      (IDX CC-SAVED-MICRO-STACK-PTR))
	     ((= COUNT 0))
	     (DECLARE (FIXNUM COUNT IDX))
	     (SETQ IDX (LOGAND 37 (1+ IDX)))		;SIMULATE HARDWARE PUSH OPERATION
	     (CC-WRITE-MRD (CC-MICRO-STACK IDX))	;GET DATA INTO MRD
	     (CC-EXECUTE (WRITE)
			 CONS-IR-M-SRC CONS-M-SRC-MRD	;PUSH IT
			 CONS-IR-ALUF CONS-ALU-SETM
			 CONS-IR-OB CONS-OB-ALU
			 CONS-IR-FUNC-DEST CONS-FUNC-DEST-MICRO-STACK-PUSH))
	 (COND ((NOT (= CC-SAVED-MICRO-STACK-PTR (CC-READ-MICRO-STACK-PTR)))
		(PRINT (LIST 'MICRO-STACK-DID-NOT-WRAP-AFTER-32-PUSHES
			     'START CC-SAVED-MICRO-STACK-PTR 
			     'END (CC-READ-MICRO-STACK-PTR)))))
	 (SETQ CC-MICRO-STACK-SAVED-FLAG NIL))))

;READ OUT DISPATCH CONSTANT
(DEFUN CC-READ-DISP-CONST ()
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-DISP-CONST
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (CC-READ-OBUS))

;READ OUT DISPATCH MEMORY (STOCHASTICLY)
;******* NOTE THE R,P,N BITS HEREIN SHOULD BE SYMBOLIC *******
(DEFUN CC-READ-D-MEM (ADR)
  (LET ((DC (CC-READ-DISP-CONST))	;GET DISPATCH CONSTANT SO AS NOT TO SMASH IT
	(PCS 0)
	(RPN 0))
     (DECLARE (FIXNUM DC PCS RPN))
     (CC-SAVE-MICRO-STACK)		;AVOID SMASHING MICRO STACK
     (CC-EXECUTE CONS-IR-OP CONS-OP-DISPATCH	;EXECUTE A DISPATCH WITH BYTE SIZE ZERO
		 CONS-IR-DISP-CONST DC		;AND RESTORE THE DISPATCH CONSTANT!
		 CONS-IR-DISP-ADDR ADR)
	     ;AT THIS POINT THE DISP IS IN IR BUT HAS NOT YET BEEN EXECUTED.
	     ;WE'LL EXECUTE IT IN A MOMENT, BUT FIRST CHECK OUT THE PC SELECT BITS.
     (SETQ PCS (LOGLDB-FROM-FIXNUM 1002 (CNSUBR 764012))) ;GET PC SELECT BITS
     (SETQ RPN (NTH PCS '(60000		;R+P (DROP THROUGH)
			  0		;(JUMP VIA D-MEM)
			  40000		;R (POPJ)
			  0)))		;(JUMP VIA IR??)
     (AND (BIT-TEST 20000 (CNSUBR 764010))	;SEE IF NOOP FLAG ON
	  (SETQ RPN (LOGIOR RPN 10000)))	;TURN ON N BIT
     (CC-CLOCK)				;CLOCK IT SO PC LOADS FROM DISP MEM
     (LOGIOR (CC-READ-PC) RPN)))	;RETURN R,P,N BITS MERGED WITH PC

;WRITE INTO DISPATCH MEMORY
(DEFUN CC-WRITE-D-MEM (ADR VAL)
  (LET ((DC (CC-READ-DISP-CONST)))	;GET DISPATCH CONSTANT SO AS NOT TO SMASH IT
     (DECLARE (FIXNUM DC))
     (CC-SAVE-MICRO-STACK)		;DON'T SMASH MICRO STACK
     (SETQ VAL				;COMPUTE PARITY
	   (LOGIOR VAL
		   (LOGAND 100000
			   (DO ((COUNT 16. (1- COUNT))
				(X VAL (LOGXOR VAL (LSH X 1))))
			       ((= COUNT 0)
				(LOGXOR 100000 X))))))	;ODD PARITY
     (CC-WRITE-M-MEM 0 VAL)		;DATA TO BE WRITTEN TO M-LOC 0 (MUST COME FROM MEM!)
     ;PUT INSTRUCTION IN DIR AND IR
     (CC-EXECUTE CONS-IR-OP CONS-OP-DISPATCH
		 ;CONS-IR-M-SRC 0
		 CONS-IR-DISP-CONST DC
		 CONS-IR-DISP-ADDR ADR
		 CONS-IR-MF 2)	;MF2 IS WRITE D-MEM
     ;GENERATE A CLOCK FOLLOWED BY A WRITE PULSE, WITHOUT CHANGING IR
     ;NOTE THAT WRITING D MEM IS DIFFERENT FROM WRITING ANYTHING ELSE
     ;BECAUSE THE WRITE IS NOT DELAYED, BUT DOES USE WP.
     (CC-DEBUG-CLOCK)))

;WRITE INTO THE DISPATCH CONSTANT
(DEFUN CC-WRITE-DISP-CONST (VAL)
  (CC-SAVE-MICRO-STACK)			;IN CASE IT HAPPENS TO PUSH OR POP
  (CC-EXECUTE (WRITE)
	      CONS-IR-OP CONS-OP-DISPATCH	;DO A DUMMY DISPATCH INSTRUCTION
	      CONS-IR-DISP-CONST VAL))

(COMMENT RESET START AND STOP)

;RESET THE MACHINE
(DEFUN CC-RESET-MACH ()
  (CNSUBW 764006 4) ;RESET HIGH
  (CNSUBW 764006 0) ;RESET LOW
  (CC-WRITE-MODE-REG CC-MODE-REG))

;STORE MODE-REG VALUE INTO THE MACHINE
(DEFUN CC-WRITE-MODE-REG (MODE)
  (LET ((HARDW 100000))
     (AND (BIT-TEST 1 MODE)	;SLOW MODE
	  (SETQ HARDW (LOGIOR 400 HARDW)))
     (OR (BIT-TEST 2 MODE)	;DISABLE ERROR HALT MODE
	 (SETQ HARDW (LOGIOR 1000 HARDW)))
     (CNSUBW 764006 HARDW)	;STORE INTO MACHINE
     T))

;STOP THE MACHINE
(DEFUN CC-STOP-MACH ()
  (CNSUBW 764006 0)		;STOP CLOCK
  (SETQ CC-RUNNING NIL))	;NOT RUNNING NOW

;START THE MACHINE.
(DEFUN CC-START-MACH ()
  (CC-FULL-RESTORE)		;RESTORE MACHINE IF TRYING TO RUN
  (CC-SINGLE-STEP)		;CLOCK ONCE, OBEYING SAVED NOOP FLAG
  (CC-CLOCK)			;CLOCK AGAIN
  (CNSUBW 764006 1)		;TAKE OFF
  (SETQ CC-RUNNING T))))

;ARG IF SMALL IS A COUNT OTHERWISE IT IS THE REGISTER ADDRESS OF PC TO STOP AT.
(DEFUN CC-STEP-MACH (ARG)
  (COND ((< ARG RAORG)
	 (DO N (MAX ARG 1) (1- N) (= N 0)
	   (CC-SINGLE-STEP)))
	(T (SETQ ARG (- ARG RACMO))	;STOP PC
	   (PROG NIL	;ALWAYS EXECUTE AT LEAST ONCE
	    LP (CC-SINGLE-STEP)
	       (OR (BIT-TEST 100000 (CNSUBR 764002))
		   (RETURN NIL))	;MACHINE LOSSAGE, STOP
	       (OR (= (CC-READ-PC) ARG)
		   (GO LP))
	       (CC-SINGLE-STEP)		;CLOCK ONCE MORE TO FETCH DESIRED INSTR
	       (AND (BIT-TEST 20000 (CNSUBR 764010))
		    (GO LP))		;NOOP FLAG SET, NOT REALLY EXECUTING IT
	       (RETURN T)))))		;REACHED DESIRED PC, STOP

(DEFUN CC-ZERO-ENTIRE-MACHINE ()
  (CC-RESET-MACH)
  (DO ADR RACMO (1+ ADR) (>= ADR RAMME)  ;THIS COULD BE CLEVERER!
    (DECLARE (FIXNUM ADR))
    (CC-R-D ADR 0)))

(COMMENT READ WRITE AND MUNG MEMORY)

;READ OUT CONTENTS OF LEVEL 1 MAP
(DEFUN CC-READ-LEVEL-1-MAP (ADR)
  (CC-WRITE-MRD (LOGDPB-INTO-FIXNUM ADR CONS-VMA-LEVEL-1-BYTE 0))	;ADDRESS VIA VMA
  (SETQ CC-VMA-CHANGED-FLAG T)
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA)
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MAP	;READ OUT MAP DATA
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (LOGLDB-FROM-FIXNUM CONS-MAP-LEVEL-1-BYTE (CC-READ-OBUS)))

;WRITE INTO LEVEL 1 MAP
(DEFUN CC-WRITE-LEVEL-1-MAP (ADR VAL)
  (CC-WRITE-MRD (LOGDPB-INTO-FIXNUM VAL CONS-MAP-LEVEL-1-BYTE 0))	;DATA TO WRITE
  (SETQ CC-MWD-CHANGED-FLAG T)
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD	;MOVE MRD INTO MWD
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-MWD)
  (CC-WRITE-MRD (LOGDPB-INTO-FIXNUM ADR CONS-VMA-LEVEL-1-BYTE 0))	;ADDRESS VIA VMA
  (SETQ CC-VMA-CHANGED-FLAG T)
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD	;DO A VMA-WRITE-MAP
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA-WRITE-MAP))

;SUBROUTINE TO SET UP ADDRESS FOR LEVEL 2 MAP (USING LEVEL 1 MAP LOCATION 0)
;RETURNS VALUE TO GO INTO VMA
(DEFUN CC-ADDRESS-LEVEL-2-MAP (ADR)
  (COND ((NOT CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG)	;SAVE AND SET CLOBBERED FLAG
	 (SETQ CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG T)
	 (SETQ CC-SAVED-LEVEL-1-MAP-LOC-0 (CC-READ-LEVEL-1-MAP 0))))
  (CC-WRITE-LEVEL-1-MAP 0 (LSH ADR -5))	;HIGH 5 BITS OF ADDRESS TO LEVEL 1 MAP ENTRY 0
  (LOGDPB-INTO-FIXNUM ADR CONS-VMA-LEVEL-2-BYTE 0))	;RETURN APPROP VMA VALUE

;READ OUT CONTENTS OF LEVEL 2 MAP
(DEFUN CC-READ-LEVEL-2-MAP (ADR)
  (CC-WRITE-MRD (CC-ADDRESS-LEVEL-2-MAP ADR))	;SET UP VMA
  (SETQ CC-VMA-CHANGED-FLAG T)
  (CC-EXECUTE (WRITE)
	      CONS-IR-M-SRC CONS-M-SRC-MRD
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU
	      CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA)
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MAP	;READ OUT MAP
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (LOGLDB-FROM-FIXNUM CONS-MAP-LEVEL-2-BYTE (CC-READ-OBUS)))

;WRITE INTO LEVEL 2 MAP
(DEFUN CC-WRITE-LEVEL-2-MAP (ADR VAL)
  (LET ((VMA (CC-ADDRESS-LEVEL-2-MAP ADR)))	;SET UP VMA (DON'T STORE IN HARDW YET)
     (DECLARE (FIXNUM VMA))
     (CC-WRITE-MRD (LOGDPB-INTO-FIXNUM VAL CONS-MAP-LEVEL-2-BYTE 1))	;DATA TO WRITE
						; AND BIT 0 = 1 MEANS WRITE LEVEL 2 MAP
     (SETQ CC-MWD-CHANGED-FLAG T)
     (CC-EXECUTE (WRITE)
		 CONS-IR-M-SRC CONS-M-SRC-MRD	;MOVE MRD INTO MWD
		 CONS-IR-ALUF CONS-ALU-SETM
		 CONS-IR-OB CONS-OB-ALU
		 CONS-IR-FUNC-DEST CONS-FUNC-DEST-MWD)
     (CC-WRITE-MRD VMA)				;NOW SET UP VMA
     (SETQ CC-VMA-CHANGED-FLAG T)
     (CC-EXECUTE (WRITE)
		 CONS-IR-M-SRC CONS-M-SRC-MRD	;DO A VMA-WRITE-MAP
		 CONS-IR-ALUF CONS-ALU-SETM
		 CONS-IR-OB CONS-OB-ALU
		 CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA-WRITE-MAP)))

(COMMENT SAVE AND RESTORE THE STATE OF THE MACHINE)

;SAVE THINGS WHICH CAN BE SAVED WITHOUT MODIFYING THE STATE OF THE MACHINE
(DEFUN CC-PASSIVE-SAVE ()
  (COND ((NOT CC-PASSIVE-SAVE-VALID)
	 (SETQ CC-PDL-BUFFER-INDEX-CHANGED-FLAG NIL	;FIRST OF ALL, CLEAR FLAGS
	       CC-MICRO-STACK-SAVED-FLAG NIL		; WHICH MARK AUXILIARY PORTIONS
	       CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG NIL	; OF THE MACHINE NEED RESTORATION
	       CC-MWD-CHANGED-FLAG NIL
	       CC-VMA-CHANGED-FLAG NIL) ;MRD ALMOST ALWAYS CHANGED, ALWAYS RESTORE IT
	 (SETQ CC-ERROR-STATUS (CC-READ-STATUS)
	       CC-SAVED-PC (CC-READ-PC)
	       CC-SAVED-IR (CC-READ-IR)
	       CC-SAVED-OBUS (CC-READ-OBUS)
	       CC-SAVED-NOOP-FLAG (BIT-TEST 20000_16. ;SYMBOL?
					   CC-ERROR-STATUS))
	 (SETQ CC-PASSIVE-SAVE-VALID T))))

;THE INVERSE OF THAT (IS THIS FUNCTION NEEDED?)
(DEFUN CC-PASSIVE-RESTORE ()
  (SETQ CC-PASSIVE-SAVE-VALID NIL))

;FULL SAVE
(DEFUN CC-FULL-SAVE ()
  (COND ((NOT CC-FULL-SAVE-VALID)
	 (CC-STOP-MACH)
	 (CC-PASSIVE-SAVE)
	 (CC-SAVE-OPCS)
	 (SETQ CC-SAVED-A-MEM-LOC-1 (CC-READ-A-MEM 1))
	 (SETQ CC-SAVED-M-MEM-LOC-0 (CC-READ-M-MEM 0))
	 (CC-SAVE-MEM-STATUS)
	 (SETQ CC-FULL-SAVE-VALID T))))

;RESTORE THAT
(DEFUN CC-FULL-RESTORE ()
  (COND (CC-FULL-SAVE-VALID
	 (AND CC-MICRO-STACK-SAVED-FLAG
	      (CC-RESTORE-MICRO-STACK))
	 (AND CC-PDL-BUFFER-INDEX-CHANGED-FLAG
	      (CC-WRITE-PDL-BUFFER-INDEX CC-SAVED-PDL-BUFFER-INDEX))
	 (SETQ CC-PDL-BUFFER-INDEX-CHANGED-FLAG NIL)
	 (CC-WRITE-A-MEM 1 CC-SAVED-A-MEM-LOC-1) ;ON NEXT MACHINE, THIS LINE HAS TO CHANGE?
	 (CC-WRITE-M-MEM 0 CC-SAVED-M-MEM-LOC-0)
	 (CC-RESTORE-MEM-STATUS)
	 (CC-WRITE-PC (1- CC-SAVED-PC))	;GETS INCREMENTED WHEN IR IS LOADED
	 (CC-EXECUTE-R (LOGLDB 0020 CC-SAVED-IR)	;RESTORE IR
		       (LOGLDB 2020 CC-SAVED-IR)
		       (LOGLDB 4020 CC-SAVED-IR))
	 (SETQ CC-FULL-SAVE-VALID NIL
	       CC-PASSIVE-SAVE-VALID NIL))))

(DEFUN CC-SAVE-OPCS ()
  (DO I 0 (1+ I) (= I 8)
    (DECLARE (FIXNUM I))
    (STORE (CC-SAVED-OPCS I) (LOGAND 7777 (CNSUBR 764002)))
    (CNSUBW 764006 40)	;CLOCK OPCS
    (CNSUBW 764006 0)))

(DEFUN CC-SAVE-MEM-STATUS ()
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-VMA
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (SETQ CC-SAVED-VMA (CC-READ-OBUS))
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MAP
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (SETQ CC-SAVED-MAP-AND-FAULT-STATUS (CC-READ-OBUS))
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MRD
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (SETQ CC-SAVED-MRD (CC-READ-OBUS))
  (CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-MWD
	      CONS-IR-ALUF CONS-ALU-SETM
	      CONS-IR-OB CONS-OB-ALU)
  (SETQ CC-SAVED-MWD (CC-READ-OBUS)))

(DEFUN CC-RESTORE-MEM-STATUS ()
  (AND CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG
       (CC-WRITE-LEVEL-1-MAP 0 CC-SAVED-LEVEL-1-MAP-LOC-0))
  (SETQ CC-LEVEL-1-MAP-LOC-0-CHANGED-FLAG NIL)
  (COND (CC-VMA-CHANGED-FLAG
	 (CC-WRITE-MRD CC-SAVED-VMA)
	 (CC-EXECUTE (WRITE)
		     CONS-IR-M-SRC CONS-M-SRC-MRD
		     CONS-IR-ALUF CONS-ALU-SETM
		     CONS-IR-OB CONS-OB-ALU
		     CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA)))
  (SETQ CC-VMA-CHANGED-FLAG NIL)
  (COND (CC-MWD-CHANGED-FLAG
	 (CC-WRITE-MRD CC-SAVED-MWD)
	 (CC-EXECUTE (WRITE)
		     CONS-IR-M-SRC CONS-M-SRC-MRD
		     CONS-IR-ALUF CONS-ALU-SETM
		     CONS-IR-OB CONS-OB-ALU
		     CONS-IR-FUNC-DEST CONS-FUNC-DEST-MWD)))
  (SETQ CC-MWD-CHANGED-FLAG NIL)
  (CC-WRITE-MRD CC-SAVED-MRD)
  ;But now, if a page fault was in progress, restore
  (COND ((BIT-TEST 1 CC-SAVED-MAP-AND-FAULT-STATUS)
	 (CC-EXECUTE (WRITE)
		     CONS-IR-M-SRC CONS-M-SRC-VMA
		     CONS-IR-ALUF CONS-ALU-SETM
		     CONS-IR-OB CONS-OB-ALU
		     CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA-START-READ))
	((BIT-TEST 2 CC-SAVED-MAP-AND-FAULT-STATUS)
	 (CC-EXECUTE (WRITE)
		     CONS-IR-M-SRC CONS-M-SRC-VMA
		     CONS-IR-ALUF CONS-ALU-SETM
		     CONS-IR-OB CONS-OB-ALU
		     CONS-IR-FUNC-DEST CONS-FUNC-DEST-VMA-START-WRITE))))

(COMMENT REGISTER ADDRESS INTERFACE)

;CC-REGISTER-EXAMINE
(DEFUN CC-R-E (ADR)
  (COND ((< ADR RAORG)
	 (PRINT ADR) (PRINC "excessively small register address.")
	 0)
	((< ADR RAFSO)  ;RAMS
	 (COND ((< ADR RAM2O)
		(COND ((< ADR RACME)
		       (CC-READ-C-MEM (- ADR RACMO)))
		      ((< ADR RADME)
		       (CC-READ-D-MEM (- ADR RADMO)))
		      ((< ADR RAPBE)
		       (CC-READ-PDL-BUFFER (- ADR RAPBO)))
		      ((CC-READ-LEVEL-1-MAP (- ADR RAM1O)))))
	       ((< ADR RAM2E)
		(CC-READ-LEVEL-2-MAP (- ADR RAM2O)))
	       ((< ADR RAAME)
		(COND ((= (SETQ ADR (- ADR RAAMO)) 0)
		       CC-SAVED-M-MEM-LOC-0) ;M=A
		      ((= ADR 1)
		       CC-SAVED-A-MEM-LOC-1)
		      ((CC-READ-A-MEM ADR))))
	       ((< ADR RAUSE)
		(CC-SAVE-MICRO-STACK)
		(CC-MICRO-STACK (- ADR RAUSO)))
	       ((= (SETQ ADR (- ADR RAMMO)) 0)
		CC-SAVED-M-MEM-LOC-0)
	       ((CC-READ-M-MEM ADR))))
	((< ADR RAFSE)  ;FUNCTIONAL SOURCES
	 (COND ((= (SETQ ADR (- ADR RAFSO)) CONS-M-SRC-MRD) CC-SAVED-MRD)
	       ((= ADR CONS-M-SRC-MWD) CC-SAVED-MWD)
	       ((= ADR CONS-M-SRC-VMA) CC-SAVED-VMA)
	       ((= ADR CONS-M-SRC-MAP) CC-SAVED-MAP-AND-FAULT-STATUS)
	       ((AND (= ADR CONS-M-SRC-PDL-PTR-AND-INDEX)
		     CC-PDL-BUFFER-INDEX-CHANGED-FLAG)
		(CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-PDL-PTR-AND-INDEX
			    CONS-IR-ALUF CONS-ALU-SETM
			    CONS-IR-OB CONS-OB-ALU)
		(LOGDPB-INTO-FIXNUM CC-SAVED-PDL-BUFFER-INDEX CONS-PI-BYTE (CC-READ-OBUS)))
	       ((AND (OR (= ADR CONS-M-SRC-MICRO-STACK)
			 (= ADR CONS-M-SRC-MICRO-STACK-POP))
		     CC-MICRO-STACK-SAVED-FLAG)
		(PROG1 (LOGDPB-INTO-FIXNUM CC-SAVED-MICRO-STACK-PTR CONS-US-POINTER-BYTE
					   (CC-MICRO-STACK CC-SAVED-MICRO-STACK-PTR))
		       (AND (= ADR CONS-M-SRC-MICRO-STACK-POP)
			    (SETQ CC-SAVED-MICRO-STACK-PTR
				  (LOGAND 37 (1- CC-SAVED-MICRO-STACK-PTR))))))
	       ((AND (= ADR CONS-M-SRC-C-PDL-BUFFER-INDEX)
		     CC-PDL-BUFFER-INDEX-CHANGED-FLAG)
		(CC-READ-PDL-BUFFER CC-SAVED-PDL-BUFFER-INDEX))
	       (T (CC-READ-M-MEM ADR))))
	((< ADR RAFDE)  ;FUNCTIONAL DESTINATIONS
	 (COND ((= (SETQ ADR (- ADR RAFDO)) CONS-FUNC-DEST-MWD) CC-SAVED-MWD)
	       ((= ADR CONS-FUNC-DEST-VMA) CC-SAVED-VMA)
	       ((= ADR CONS-FUNC-DEST-PDL-BUFFER-INDEX)
		(OR CC-PDL-BUFFER-INDEX-CHANGED-FLAG (CC-SAVE-PDL-BUFFER-INDEX))
		CC-SAVED-PDL-BUFFER-INDEX)
	       ((= ADR CONS-FUNC-DEST-PDL-BUFFER-POINTER)
		(CC-EXECUTE CONS-IR-M-SRC CONS-M-SRC-PDL-PTR-AND-INDEX
			    CONS-IR-ALUF CONS-ALU-SETM
			    CONS-IR-OB CONS-OB-ALU)
		(LOGLDB-FROM-FIXNUM CONS-PP-BYTE (CC-READ-OBUS)))		
	       (T (PRINT (+ ADR RAFDO)) (PRINC "attempt to examine functional destination")
		  0)))
	((< ADR RARGE)	;INDIVIDUAL REGISTERS
	 (COND ((= ADR RAPC) CC-SAVED-PC)
	       ((= ADR RAUSP)
;		(CC-SAVE-MICRO-STACK)  ;DONT SAVE IT UNLESS REALLY HAVE TO SINCE
				       ; THERE SEEM TO BE SOME BUGS CONNECTED WITH
				       ; THIS AND THAT CONFUSES THINGS.
		(COND (CC-MICRO-STACK-SAVED-FLAG 
		       CC-SAVED-MICRO-STACK-PTR)
		      (T (CC-READ-MICRO-STACK-PTR))))
	       ((= ADR RAIR)
		(CC-READ-IR))  ;HARDWARE IR
	       ((= ADR RASIR) CC-SAVED-IR)   ;PROGRAM IR
	       ((= ADR RAQ)
		(CC-READ-M-MEM CONS-M-SRC-Q))
	       ((= ADR RADC)
		(CC-READ-DISP-CONST))
	       ((= ADR RASTS) CC-ERROR-STATUS)
	       ((= ADR RAOBS) CC-SAVED-OBUS)
	       ((= ADR RAGO)  ;Determine whether the machine is currently running
		(COND (CC-RUNNING (LSH (CNSUBR 764002) -15.)) ;100000 bit is on if no errhalt
		      (T 0)))
	       ((= ADR RAMOD) CC-MODE-REG)
	       (T 0)))
	((< ADR RAOPCO)
	 (PRINT ADR) (PRINC "is among the unimplemented registers.")
	 0)
	((< ADR RAOPCE)
	 (CC-SAVED-OPCS (- ADR RAOPCO)))
	(T (PRINT ADR) (PRINC "is an excessively large register address")
	   0)))

;CC-REGISTER-DEPOSIT
;WHEN TO SAVE & RESTORE STATE OF MACHINE IS FUZZY IN THIS FUNCTION
(DEFUN CC-R-D (ADR VAL)
  (COND ((< ADR RAORG)
	 (PRINT ADR) (PRINC "excessively small register address.  Depositing ") (PRIN1 VAL))
	((< ADR RAFSO)  ;RAMS
	 (COND ((< ADR RAM2O)
		(COND ((< ADR RACME)
		       (CC-WRITE-C-MEM (- ADR RACMO) VAL))
		      ((< ADR RADME)
		       (CC-WRITE-D-MEM (- ADR RADMO) VAL))
		      ((< ADR RAPBE)
		       (CC-WRITE-PDL-BUFFER (- ADR RAPBO) VAL))
		      ((CC-WRITE-LEVEL-1-MAP (- ADR RAM1O) VAL))))
	       ((< ADR RAM2E)
		(CC-WRITE-LEVEL-2-MAP (- ADR RAM2O) VAL))
	       ((< ADR RAAME)
		(COND ((= (SETQ ADR (- ADR RAAMO)) 1)
		       (SETQ CC-SAVED-A-MEM-LOC-1 VAL))
		      ((CC-WRITE-A-MEM ADR VAL))))
	       ((< ADR RAUSE)
		(CC-SAVE-MICRO-STACK)
		(STORE (CC-MICRO-STACK (- ADR RAUSO)) VAL))
	       ((= (SETQ ADR (- ADR RAMMO)) 0)
		(SETQ CC-SAVED-M-MEM-LOC-0 VAL))
	       (T (AND (= ADR 1) (SETQ CC-SAVED-A-MEM-LOC-1 VAL))
		  (CC-WRITE-M-MEM ADR VAL))))
	((< ADR RAFSE)  ;FUNCTIONAL SOURCES
	 (PRINT ADR) (PRINC "attempt to deposit in functional source ignored"))
	((< ADR RAFDE)  ;FUNCTIONAL DESTINATIONS
	 (CC-RESTORE-MEM-STATUS)	;GET PROPER VMA, MWD IN MACHINE
	 (CC-WRITE-MRD VAL)		;** ON NEXT MACHINE, CHANGE THIS!! **
	 (CC-EXECUTE (WRITE)
		     CONS-IR-M-SRC CONS-M-SRC-MRD
		     CONS-IR-ALUF CONS-ALU-SETM
		     CONS-IR-OB CONS-OB-ALU
		     CONS-IR-FUNC-DEST (- ADR RAFDO))
	 (CC-SAVE-MEM-STATUS))		;STUFF IN MACHINE MAY HAVE CHANGED
	((< ADR RARGE)	;INDIVIDUAL REGISTERS
	 (COND ((= ADR RAPC)
		(SETQ CC-SAVED-PC (LOGAND 7777 VAL)))
	       ((= ADR RAUSP)
		(CC-SAVE-MICRO-STACK)
		(SETQ CC-SAVED-MICRO-STACK-PTR (LOGAND 37 VAL)))
	       ((= ADR RAQ)
		(CC-WRITE-MRD VAL)
		(CC-EXECUTE (WRITE)
			    CONS-IR-M-SRC CONS-M-SRC-MRD
			    CONS-IR-ALUF CONS-ALU-SETM
			    CONS-IR-OB CONS-OB-ALU
			    CONS-IR-Q CONS-Q-LOAD))
	       ((= ADR RADC)
		(CC-WRITE-DISP-CONST VAL))
	       ((= ADR RARSET)
		(CC-ZERO-ENTIRE-MACHINE))
	       ((= ADR RARS)
		(CC-RESET-MACH)
		(SETQ CC-PASSIVE-SAVE-VALID NIL CC-FULL-SAVE-VALID NIL)
		(CC-FULL-SAVE))
	       ((= ADR RASTEP)
		(CC-FULL-RESTORE)
		(CC-STEP-MACH VAL)
		(CC-FULL-SAVE))
	       ((= ADR RASTOP)
		(CC-FULL-SAVE)) ;STOP & SAVE
	       ((= ADR RASA)  ;SET START ADDR
		(SETQ CC-SAVED-NOOP-FLAG T
		      CC-SAVED-PC (LOGAND 7777 VAL)))
	       ((= ADR RAGO)
		(CC-START-MACH))
	       ((= ADR RAMOD)
		(CC-WRITE-MODE-REG (SETQ CC-MODE-REG VAL)))
	       (T (PRINT ADR) (PRINC "is an unimplemented register - deposit."))))
	(T (PRINT ADR)
	   (PRINC "is an excessively large or unimplemented register address - deposit."))))
