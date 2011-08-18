;;; -*-MODE:LISP; BASE:8;-*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **
;;; This file contains all the definitions for the machine instruction set
;;; and some other stuff needed by the compiler.


;;; This section contains various information regarding the misc. instructions
;;; on the Lisp Machine.  Every entry is of the form:
;;; (DEFMIC <name> <opcode> <arglist> <lisp-function-p> <no-QINTCMP>)
;;;   <name> is the name of the instruction.  If the Lisp function name
;;; 		is different from the instruction name, this is a cons
;;;		of the function name and the instruction name (e.g. (CAR . M-CAR))
;;;   <opcode> is the number which appears in the macro-instruction.
;;;   <arglist> is a list resembling a lambda-list for the Lisp function
;;;             corresponding to the instruction.  & keywords not allowed.
;;;   <lisp-function-p> should be either T or NIL.  If T, then there
;;;             will be a Lisp function defined in the initial Lisp
;;;             environment (available in the interpreter) corresponding
;;;             to the instruction.
;;;   <no-QINTCMP> is OPTIONAL.  If it is not present it is taken to be NIL.
;;;             If it is non-NIL, then no QINTCMP property will be created
;;;             for the symbol.  Otherwise the QINTCMP property is created from
;;;             the length of <arglist>.  The QINTCMP property permits the
;;;		compiler to compile calls to this function as a misc instruction.

;240 241 FREE
(DEFMIC (CAR . M-CAR) 242 (X) T T)
(DEFMIC (CDR . M-CDR) 243 (X) T T)
(DEFMIC (CAAR . M-CAAR) 244 (X) T T)
(DEFMIC (CADR . M-CADR) 245 (X) T T)
(DEFMIC (CDAR . M-CDAR) 246 (X) T T)
(DEFMIC (CDDR . M-CDDR) 247 (X) T T)
(DEFMIC CAAAR 250 (X) T)
(DEFMIC CAADR 251 (X) T)
(DEFMIC CADAR 252 (X) T)
(DEFMIC CADDR 253 (X) T)
(DEFMIC CDAAR 254 (X) T)
(DEFMIC CDADR 255 (X) T)
(DEFMIC CDDAR 256 (X) T)
(DEFMIC CDDDR 257 (X) T)
(DEFMIC CAAAAR 260 (X) T)
(DEFMIC CAAADR 261 (X) T)
(DEFMIC CAADAR 262 (X) T)
(DEFMIC CAADDR 263 (X) T)
(DEFMIC CADAAR 264 (X) T)
(DEFMIC CADADR 265 (X) T)
(DEFMIC CADDAR 266 (X) T)
(DEFMIC CADDDR 267 (X) T)
(DEFMIC CDAAAR 270 (X) T)
(DEFMIC CDAADR 271 (X) T)
(DEFMIC CDADAR 272 (X) T)
(DEFMIC CDADDR 273 (X) T)
(DEFMIC CDDAAR 274 (X) T)
(DEFMIC CDDADR 275 (X) T)
(DEFMIC CDDDAR 276 (X) T)
(DEFMIC CDDDDR 277 (X) T)

(DEFMIC %LOAD-FROM-HIGHER-CONTEXT 300 (ENVPTR) T)
(DEFMIC %LOCATE-IN-HIGHER-CONTEXT 301 (ENVPTR) T)
(DEFMIC %STORE-IN-HIGHER-CONTEXT 302 (VALUE ENVPTR) T)
(DEFMIC %DATA-TYPE 303 (X) T)
(DEFMIC %POINTER 304 (X) T)
;305-307 FREE
(DEFMIC %MAKE-POINTER 310 (DTP ADDRESS) T)
(DEFMIC %SPREAD 311 (LIST) NIL T)
(DEFMIC %P-STORE-CONTENTS 312 (POINTER X) T)
(DEFMIC %LOGLDB 313 (PPSS WORD) T)    ;THESE DONT COMPLAIN ABOUT LOADING/CLOBBERING SIGN
(DEFMIC %LOGDPB 314 (VALUE PPSS WORD) T)  ;RESULT IS ALWAYS A FIXNUM
(DEFMIC LDB 315 (PPSS WORD) T)
(DEFMIC DPB 316 (VALUE PPSS WORD) T)
(DEFMIC %P-STORE-TAG-AND-POINTER 317 (POINTER MISC-FIELDS POINTER-FIELD) T)

(DEFMIC GET 320 (SYMBOL INDICATOR) T)
(DEFMIC GETL 321 (SYMBOL INDICATOR-LIST) T)
(DEFMIC ASSQ 322 (X ALIST) T)
(DEFMIC LAST 323 (LIST) T)
(DEFMIC LENGTH 324 (LIST) T)
(DEFMIC 1+ 325 (N) T)
(DEFMIC 1- 326 (N) T)
(DEFMIC RPLACA 327 (CONS X) T)
(DEFMIC RPLACD 330 (CONS X) T)
(DEFMIC ZEROP 331 (NUMBER) T)
(DEFMIC SET 332 (SYMBOL X) T)
(DEFMIC FIXP 333 (X) T)
(DEFMIC FLOATP 334 (X) T)
(DEFMIC EQUAL 335 (X Y) T)
;(DEFMIC STORE 336 )
(DEFMIC XSTORE 337 (NEWDATA ARRAYREF) T)

(DEFMIC FALSE 340 () T)
(DEFMIC TRUE 341 () T)
(DEFMIC NOT 342 (X) T)
(DEFMIC (NULL . NOT) 342 (X) T)
(DEFMIC ATOM 343 (X) T)
(DEFMIC ODDP 344 (NUMBER) T)
(DEFMIC EVENP 345 (NUMBER) T)
(DEFMIC %HALT 346 () T)
(DEFMIC GET-PNAME 347 (SYMBOL) T)
(DEFMIC LSH 350 (N NBITS) T)
(DEFMIC ROT 351 (N NBITS) T)
(DEFMIC *BOOLE 352 (FN ARG1 ARG2) T)
(DEFMIC NUMBERP 353 (X) T)
(DEFMIC PLUSP 354 (NUMBER) T)
(DEFMIC MINUSP 355 (NUMBER) T)
(DEFMIC \ 356 (X Y) T)
(DEFMIC MINUS 357 (NUMBER) T)
(DEFMIC PRINT-NAME-CELL-LOCATION 360 (SYMBOL) T)
(DEFMIC VALUE-CELL-LOCATION 361 (SYMBOL) T)
(DEFMIC FUNCTION-CELL-LOCATION 362 (SYMBOL) T)
(DEFMIC PROPERTY-CELL-LOCATION 363 (SYMBOL) T)
(DEFMIC NCONS 364 (X) T)
(DEFMIC NCONS-IN-AREA 365 (X AREA) T)
(DEFMIC CONS 366 (X Y) T)
(DEFMIC CONS-IN-AREA 367 (X Y AREA) T)
(DEFMIC XCONS 370 (X Y) T)
(DEFMIC XCONS-IN-AREA 371 (X Y AREA) T)
(DEFMIC %SPREAD-N 372 (N) NIL)
(DEFMIC SYMEVAL 373 (SYMBOL) T)
(DEFMIC POP-M-FROM-UNDER-N 374 (NUM-POPS NUM-TO-KEEP) NIL)
(DEFMIC %OLD-MAKE-LIST 375 (AREA LENGTH) T)
(DEFMIC %CALL-MULT-VALUE 376 () NIL T)
(DEFMIC %CALL0-MULT-VALUE 377 () NIL T)
(DEFMIC %RETURN-2 400 () NIL T)
(DEFMIC %RETURN-3 401 () NIL T)
(DEFMIC %RETURN-N 402 () NIL T)
(DEFMIC RETURN-NEXT-VALUE 403 (X) NIL)
(DEFMIC RETURN-LIST 404 (VALUES) NIL T)
(DEFMIC UNBIND-TO-INDEX-UNDER-N 405 (N) NIL)
(DEFMIC BIND 406 (POINTER X) NIL)
(DEFMIC %MAKE-LEXICAL-CLOSURE 407 (LOCALNUM) NIL T)
(DEFMIC MEMQ 410 (X LIST) T)
(DEFMIC (INTERNAL-< . M-<) 411 (NUM1 NUM2) T)
(DEFMIC (INTERNAL-> . M->) 412 (NUM1 NUM2) T)
(DEFMIC (= . M-=) 413 (NUM1 NUM2) T)
(DEFMIC CHAR-EQUAL 414 (CH1 CH2) T)
(DEFMIC %STRING-SEARCH-CHAR 415 (CHAR STRING START END) T)
(DEFMIC %STRING-EQUAL 416 (STRING1 INDEX1 STRING2 INDEX2 COUNT) T)
(DEFMIC NTH 417 (N LIST) T)
(DEFMIC NTHCDR 420 (N LIST) T)
(DEFMIC (*PLUS . M-+) 421 (NUM1 NUM2) T)
(DEFMIC (*DIF . M--) 422 (NUM1 NUM2) T)
(DEFMIC (*TIMES . M-*) 423 (NUM1 NUM2) T)
(DEFMIC (*QUO . M-//) 424 (NUM1 NUM2) T)
(DEFMIC (*LOGAND . M-LOGAND) 425 (NUM1 NUM2) T)
(DEFMIC (*LOGXOR . M-LOGXOR) 426 (NUM1 NUM2) T)
(DEFMIC (*LOGIOR . M-LOGIOR) 427 (NUM1 NUM2) T)
(DEFMIC ARRAY-LEADER 430 (ARRAY INDEX) T)
(DEFMIC STORE-ARRAY-LEADER 431 (X ARRAY INDEX) T)
(DEFMIC GET-LIST-POINTER-INTO-ARRAY 432 (ARRAY) T)
(DEFMIC ARRAY-PUSH 433 (ARRAY X) T)
(DEFMIC APPLY 434 (FN ARGS) T)
(DEFMIC %MAKE-LIST 435 (INITIAL-VALUE AREA LENGTH) T)
(DEFMIC LIST 436 (&REST ELEMENTS) T T)
(DEFMIC LIST* 437 (FIRST &REST ELEMENTS) T T)   ;"(&REST ELEMENTS LAST)"
(DEFMIC LIST-IN-AREA 440 (AREA &REST ELEMENTS) T T)
(DEFMIC LIST*-IN-AREA 441 (AREA FIRST &REST ELEMENTS) T T)   ;"(AREA &REST ELEMENTS LAST)"
(DEFMIC %P-FLAG-BIT 442 (POINTER) T)
(DEFMIC %P-CDR-CODE 443 (POINTER) T)
(DEFMIC %P-DATA-TYPE 444 (POINTER) T)
(DEFMIC %P-POINTER 445 (POINTER) T)
(DEFMIC %PAGE-TRACE 446 (TABLE) T)
(DEFMIC %P-STORE-FLAG-BIT 447 (POINTER FLAG-BIT) T)
(DEFMIC %P-STORE-CDR-CODE 450 (POINTER CDR-CODE) T)
(DEFMIC %P-STORE-DATA-TYPE 451 (POINTER DATA-TYPE) T)
(DEFMIC %P-STORE-POINTER 452 (POINTER POINTER) T)
;453-455 FREE
(DEFMIC %CATCH-OPEN 456 () NIL T)
(DEFMIC %CATCH-OPEN-MV 457 () NIL T)
;461, 462 FREE
(DEFMIC %FEXPR-CALL 462 () NIL T)
(DEFMIC %FEXPR-CALL-MV 463 () NIL T)
(DEFMIC %LEXPR-CALL 464 () NIL T)
(DEFMIC %LEXPR-CALL-MV 465 () NIL T)
(DEFMIC *CATCH 466 (TAG &REST FORMS) T T)
(DEFMIC %BLT 467 (FROM-ADDRESS TO-ADDRESS COUNT INCREMENT) T)
(DEFMIC *THROW 470 (TAG VALUE) T)
(DEFMIC %XBUS-WRITE-SYNC 471 (IO-ADDR WORD DELAY SYNC-LOC SYNC-MASK SYNC-VAL) T)
(DEFMIC %P-LDB 472 (PPSS POINTER) T)
(DEFMIC %P-DPB 473 (VALUE PPSS POINTER) T)
(DEFMIC MASK-FIELD 474 (PPSS FIXNUM) T)
(DEFMIC %P-MASK-FIELD 475  (PPSS POINTER) T)
(DEFMIC DEPOSIT-FIELD 476 (VALUE PPSS FIXNUM) T)
(DEFMIC %P-DEPOSIT-FIELD 477 (VALUE PPSS POINTER) T)
(DEFMIC COPY-ARRAY-CONTENTS 500 (FROM TO) T)
(DEFMIC COPY-ARRAY-CONTENTS-AND-LEADER 501 (FROM TO) T)
(DEFMIC %FUNCTION-INSIDE-SELF 502 () T)
(DEFMIC ARRAY-HAS-LEADER-P 503 (ARRAY) T)
(DEFMIC COPY-ARRAY-PORTION 504 (FROM-ARRAY FROM-START FROM-END TO-ARRAY TO-START TO-END) T)
(DEFMIC FIND-POSITION-IN-LIST 505 (X LIST) T)
;(DEFMIC FIND-POSITION-IN-LIST-EQUAL 506 )
(DEFMIC G-L-P 507 (ARRAY) T)
(DEFMIC FIND-POSITION-IN-VECTOR 510 (X LIST) NIL)
;(DEFMIC FIND-POSITION-IN-VECTOR-EQUAL 511 )
(DEFMIC AR-1 512 (ARRAY SUB) T)
(DEFMIC AR-2 513 (ARRAY SUB1 SUB2) T)
(DEFMIC AR-3 514 (ARRAY SUB1 SUB2 SUB3) T)
(DEFMIC AS-1 515 (VALUE ARRAY SUB) T)
(DEFMIC AS-2 516 (VALUE ARRAY SUB1 SUB2) T)
(DEFMIC AS-3 517 (VALUE ARRAY SUB1 SUB2 SUB3) T)
(DEFMIC %INSTANCE-REF 520 (INSTANCE INDEX) T)
(DEFMIC %INSTANCE-LOC 521 (INSTANCE INDEX) T)
(DEFMIC %INSTANCE-SET 522 (VAL INSTANCE INDEX) T)
(DEFMIC %BINDING-INSTANCES 523 (LIST-OF-SYMBOLS) T)
(DEFMIC %INTERNAL-VALUE-CELL 524 (SYMBOL) T)
(DEFMIC %USING-BINDING-INSTANCES 525 (BINDING-INSTANCES) T)
(DEFMIC %GC-CONS-WORK 526 (NQS) T)
(DEFMIC %P-CONTENTS-OFFSET 527 (POINTER OFFSET) T)
(DEFMIC %DISK-RESTORE 530 (PARTITION-HIGH-16-BITS LOW-16-BITS) T)
(DEFMIC %DISK-SAVE 531 (MAIN-MEMORY-SIZE PARTITION-HIGH-16-BITS LOW-16-BITS) T)
(DEFMIC %ARGS-INFO 532 (FUNCTION) T)
(DEFMIC %OPEN-CALL-BLOCK 533 (FUNCTION ADI-PAIRS DESTINATION) NIL)
(DEFMIC %PUSH 534 (X) NIL)
(DEFMIC %ACTIVATE-OPEN-CALL-BLOCK 535 () NIL)
(DEFMIC %ASSURE-PDL-ROOM 536 (ROOM) NIL)
(DEFMIC STACK-GROUP-RETURN 537 (X) T)
;(DEFMIC %STACK-GROUP-RETURN-MULTI 540 )
;Perhaps the next one should be flushed.
(DEFMIC %MAKE-STACK-LIST 541 (N) NIL)
(DEFMIC STACK-GROUP-RESUME 542 (SG X) T)
(DEFMIC %CALL-MULT-VALUE-LIST 543 () NIL T)
(DEFMIC %CALL0-MULT-VALUE-LIST 544 () NIL T)
(DEFMIC %GC-SCAV-RESET 545 (REGION) T)
(DEFMIC %P-STORE-CONTENTS-OFFSET 546 (X POINTER OFFSET) T)
(DEFMIC %GC-FREE-REGION 547 (REGION) T)
(DEFMIC %GC-FLIP 550 (REGION) T)
(DEFMIC ARRAY-LENGTH 551 (ARRAY) T)
(DEFMIC ARRAY-ACTIVE-LENGTH 552 (ARRAY) T)
(DEFMIC %COMPUTE-PAGE-HASH 553 (ADDR) T)
(DEFMIC GET-LOCATIVE-POINTER-INTO-ARRAY 554 (ARRAY-REF) T)
(DEFMIC %UNIBUS-READ 555 (UNIBUS-ADDR) T)
(DEFMIC %UNIBUS-WRITE 556 (UNIBUS-ADDR WORD) T)
(DEFMIC %GC-SCAVENGE 557 (WORK-UNITS) T)
(DEFMIC %CHAOS-WAKEUP 560 () T)
(DEFMIC %AREA-NUMBER 561 (X) T)
(DEFMIC *MAX 562 (NUM1 NUM2) T)
(DEFMIC *MIN 563 (NUM1 NUM2) T)
(DEFMIC CLOSURE 565 (SYMBOL-LIST FUNCTION) T)
;(DEFMIC DOWNWARD-CLOSURE 566 (SYMBOL-LIST FUNCTION) T)
(DEFMIC LISTP 567 (X) T)
(DEFMIC NLISTP 570 (X) T)
(DEFMIC SYMBOLP 571 (X) T)
(DEFMIC NSYMBOLP 572 (X) T)
(DEFMIC ARRAYP 573 (X) T)
(DEFMIC FBOUNDP 574 (SYMBOL) T)
(DEFMIC STRINGP 575 (X) T)
(DEFMIC BOUNDP 576 (SYMBOL) T)
(DEFMIC INTERNAL-\\ 577 (NUM1 NUM2) T)
(DEFMIC FSYMEVAL 600 (SYMBOL) T)
(DEFMIC AP-1 601 (ARRAY SUB) T)
(DEFMIC AP-2 602 (ARRAY SUB1 SUB2) T)
(DEFMIC AP-3 603 (ARRAY SUB1 SUB2 SUB3) T)
(DEFMIC AP-LEADER 604 (ARRAY SUB) T)
(DEFMIC %P-LDB-OFFSET 605 (PPSS POINTER OFFSET) T)
(DEFMIC %P-DPB-OFFSET 606 (VALUE PPSS POINTER OFFSET) T)
(DEFMIC %P-MASK-FIELD-OFFSET 607 (PPSS POINTER OFFSET) T)
(DEFMIC %P-DEPOSIT-FIELD-OFFSET 610 (VALUE PPSS POINTER OFFSET) T)
(DEFMIC %MULTIPLY-FRACTIONS 611 (NUM1 NUM2) T)
(DEFMIC %DIVIDE-DOUBLE 612 (HIGH-DIVIDEND LOW-DIVIDEND DIVISOR) T)
(DEFMIC %REMAINDER-DOUBLE 613 (HIGH-DIVIDEND LOW-DIVIDEND DIVISOR) T)
(DEFMIC HAULONG 614 (NUM) T)
(DEFMIC %ALLOCATE-AND-INITIALIZE 615 (RETURN-DTP HEADER-DTP HEADER WORD2 AREA NQS) T)
(DEFMIC %ALLOCATE-AND-INITIALIZE-ARRAY 616 (HEADER INDEX-LENGTH LEADER-LENGTH AREA NQS) T)
(DEFMIC %MAKE-POINTER-OFFSET 617 (NEW-DTP POINTER OFFSET) T)
(DEFMIC ^ 620 (NUM EXPT) T)
(DEFMIC %CHANGE-PAGE-STATUS 621 (VIRT-ADDR SWAP-STATUS ACCESS-AND-META) T)
(DEFMIC %CREATE-PHYSICAL-PAGE 622 (PHYS-ADDR) T)
(DEFMIC %DELETE-PHYSICAL-PAGE 623 (PHYS-ADDR) T)
(DEFMIC %24-BIT-PLUS 624 (NUM1 NUM2) T)
(DEFMIC %24-BIT-DIFFERENCE 625 (NUM1 NUM2) T)
(DEFMIC %24-BIT-TIMES 626 (NUM1 NUM2) T)
(DEFMIC ABS 627 (NUM) T)
(DEFMIC %POINTER-DIFFERENCE 630 (PTR1 PTR2) T)
(DEFMIC %P-CONTENTS-AS-LOCATIVE 631 (POINTER) T)
(DEFMIC %P-CONTENTS-AS-LOCATIVE-OFFSET 632 (POINTER OFFSET) T)
(DEFMIC (EQ . M-EQ) 633 (X Y) T)
(DEFMIC %STORE-CONDITIONAL 634 (POINTER OLD NEW) T)
(DEFMIC %STACK-FRAME-POINTER 635 () NIL)
(DEFMIC *UNWIND-STACK 636 (TAG VALUE FRAME-COUNT ACTION) T)
(DEFMIC %XBUS-READ 637 (IO-ADDR) T)
(DEFMIC %XBUS-WRITE 640 (IO-ADDR WORD) T)
(DEFMIC PACKAGE-CELL-LOCATION 641 (SYMBOL) T)
(DEFMIC MOVE-PDL-TOP 642 NIL NIL T)
(DEFMIC SHRINK-PDL-SAVE-TOP 643 (VALUE-TO-MOVE N-SLOTS) NIL T)
(DEFMIC SPECIAL-PDL-INDEX 644 NIL NIL T)
(DEFMIC UNBIND-TO-INDEX 645 (SPECIAL-PDL-INDEX) NIL T)
(DEFMIC UNBIND-TO-INDEX-MOVE 646 (SPECIAL-PDL-INDEX VALUE-TO-MOVE) NIL T)
(DEFMIC FIX 647 (NUMBER) T)
(DEFMIC FLOAT 650 (NUMBER) T)
(DEFMIC SMALL-FLOAT 651 (NUMBER) T)
(DEFMIC %FLOAT-DOUBLE 652 (NUMBER NUMBER) T)
(DEFMIC BIGNUM-TO-ARRAY 653 (BIGNUM BASE) T)
(DEFMIC ARRAY-TO-BIGNUM 654 (ARRAY BASE SIGN) T)
(DEFMIC %UNWIND-PROTECT-CONTINUE 655 (VALUE TAG COUNT ACTION) NIL T)
(DEFMIC %WRITE-INTERNAL-PROCESSOR-MEMORIES 656 (CODE ADR D-HI D-LOW) T)
(DEFMIC %PAGE-STATUS 657 (PTR) T)
(DEFMIC %REGION-NUMBER 660 (PTR) T)
(DEFMIC %FIND-STRUCTURE-HEADER 661 (PTR) T)
(DEFMIC %STRUCTURE-BOXED-SIZE 662 (PTR) T)
(DEFMIC %STRUCTURE-TOTAL-SIZE 663 (PTR) T)
(DEFMIC %MAKE-REGION 664 (BITS SIZE) T)
(DEFMIC BITBLT 665 (ALU WIDTH HEIGHT FROM-ARRAY FROM-X FROM-Y TO-ARRAY TO-X TO-Y) T)
(DEFMIC %DISK-OP 666 (RQB) T)
(DEFMIC %PHYSICAL-ADDRESS 667 (PTR) T)
(DEFMIC POP-OPEN-CALL 670 NIL NIL T)
(DEFMIC %BEEP 671 (HALF-WAVELENGTH DURATION) T)
(DEFMIC %FIND-STRUCTURE-LEADER 672 (PTR) T)
(DEFMIC BPT 673 NIL T)
(DEFMIC %FINDCORE 674 () T)
(DEFMIC %PAGE-IN 675 (PFN VPN) T)
(DEFMIC ASH 676 (N NBITS) T)
(DEFMIC %MAKE-EXPLICIT-STACK-LIST 677 (LENGTH) T)
(DEFMIC %DRAW-CHAR 700 (FONT-ARRAY CHAR-CODE X-BITPOS Y-BITPOS ALU-FUNCTION SHEET) T)
(DEFMIC %DRAW-RECTANGLE 701 (WIDTH HEIGHT X-BITPOS Y-BITPOS ALU-FUNCTION SHEET) T)
(DEFMIC %DRAW-LINE 702 (X0 Y0 X Y ALU DRAW-END-POINT SHEET) T)
(DEFMIC %DRAW-TRIANGLE 703 (X1 Y1 X2 Y2 X3 Y3 ALU SHEET) T)
(DEFMIC %COLOR-TRANSFORM 704 (N17 N16 N15 N14 N13 N12 N11 N10 N7 N6 N5 N4 N3 N2 N1 N0
			      WIDTH HEIGHT ARRAY START-X START-Y) T)
(DEFMIC %RECORD-EVENT 705 (DATA-4 DATA-3 DATA-2 DATA-1 STACK-LEVEL EVENT MUST-BE-4) T)
(DEFMIC %AOS-TRIANGLE 706 (X1 Y1 X2 Y2 X3 Y3 INCREMENT SHEET) T)
(DEFMIC %SET-MOUSE-SCREEN 707 (SHEET) T)
(DEFMIC %OPEN-MOUSE-CURSOR 710 () T)
(defmic %ether-wakeup 711 (reset-p) t)
(defmic %checksum-pup 712 (art-16b-pup start length) t)
(defmic %decode-pup 713 (art-byte-pup start length state super-image-p) t)
	

; FROM HERE TO 777 FREE

;;; The ARGDESC properties, telling the compiler special things about
;;; a few functions whose arguments would otherwise be compiled wrong.

;AN ARGDESC PROPERTY IS A LIST OF 2-LISTS.  THE FIRST ELEMENT OF EA
;2-LIST IS A REPEAT COUNT. THE SECOND IS A LIST OF ADL SPECIFIER TYPE TOKENS.

;The following are commented out since we no longer attempt to run the
;compiler in Maclisp and therefore no longer get confused by SUBR/FSUBR/LSUBR properties.
;;MAKE SURE CALLS TO DEFPROP GET COMPILED RIGHT (IE SPREAD ARGS).  OTHERWISE,
;; WOULD LOSE BECAUSE ITS A MACLISP FSUBR.
;
;  (DEFPROP DEFPROP ((3 (FEF-ARG-REQ FEF-QT-QT))) ARGDESC)
;  (DEFPROP FASLOAD ((1 (FEF-ARG-REQ FEF-QT-EVAL)) (1 (FEF-ARG-OPT FEF-QT-EVAL))) ARGDESC)
;	;Likewise FASLOAD which is a SUBR in LISPM since strings self-evaluate.

;These remain here because the compiler loses on QUOTE-HAIR functions.
  (DEFPROP BREAK ((1 (FEF-ARG-OPT FEF-QT-QT))
		  (1 (FEF-ARG-OPT FEF-QT-EVAL))) ARGDESC)

  (DEFPROP SIGNP ((1 (FEF-ARG-REQ FEF-QT-QT)) (1 (FEF-ARG-REQ FEF-QT-EVAL))) ARGDESC)

  (DEFPROP STATUS ((1 (FEF-ARG-REQ FEF-QT-QT))
                   (1 (FEF-ARG-OPT FEF-QT-QT))) ARGDESC)
  (DEFPROP SSTATUS ((2 (FEF-ARG-REQ FEF-QT-QT))) ARGDESC)

;MAKE SURE FUNCTIONAL ARGS TO MAPPING FUNCTIONS GET BROKEN OFF AND COMPILED
; EVEN IF QUOTE USED INSTEAD OF FUNCTION.  (HOWEVER, A POINTER TO THE 
;  BROKEN-OFF SYMBOL INSTEAD OF THE CONTENTS OF ITS FUNCTION CELL WILL BE PASSED
;  IF QUOTE IS USED).

  (DEFPROP MAP    ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		   (1 (FEF-ARG-REQ FEF-QT-EVAL))
		   (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP MAPC   ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		   (1 (FEF-ARG-REQ FEF-QT-EVAL))
		   (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP MAPCAR ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		   (1 (FEF-ARG-REQ FEF-QT-EVAL))
		   (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP MAPLIST ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		    (1 (FEF-ARG-REQ FEF-QT-EVAL))
		    (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP MAPCAN ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		   (1 (FEF-ARG-REQ FEF-QT-EVAL))
		   (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP MAPCON ((1 (FEF-ARG-REQ FEF-QT-EVAL FEF-FUNCTIONAL-ARG))
		   (1 (FEF-ARG-REQ FEF-QT-EVAL))
		   (105 (FEF-ARG-OPT FEF-QT-EVAL)) ) ARGDESC)
  (DEFPROP APPLY ((2 (FEF-ARG-REQ FEF-QT-EVAL))) ARGDESC)
	;Because LSUBR in Maclisp?

;;; Instructions and other symbols for LAP

(DEFPROP CALL 0 QLVAL) 

(DEFPROP CALL0 1000 QLVAL) 

(DEFPROP MOVE 2000 QLVAL) 

(DEFPROP CAR 3000 QLVAL) 

(DEFPROP CDR 4000 QLVAL) 

(DEFPROP CADR 5000 QLVAL) 

(DEFPROP CDDR 6000 QLVAL) 

(DEFPROP CDAR 7000 QLVAL) 

(DEFPROP CAAR 10000 QLVAL) 

;ND1
;(DEFPROP UNUSED 11000 QLVAL) ;NOT USED
(DEFPROP *PLUS 31000 QLVAL)  ;THESE USED TO BE CALLED +, -, ETC. BUT THOSE ARE NOW N-ARG
(DEFPROP *DIF 51000 QLVAL)   ;WHILE THESE SEVEN ARE TWO-ARGUMENTS-ONLY (INSTRUCTIONS).
(DEFPROP *TIMES 71000 QLVAL) 
(DEFPROP *QUO 111000 QLVAL) 
(DEFPROP *LOGAND 131000 QLVAL)
(DEFPROP *LOGXOR 151000 QLVAL)
(DEFPROP *LOGIOR 171000 QLVAL)

;ND2
(DEFPROP = 12000 QLVAL) 
(DEFPROP INTERNAL-> 32000 QLVAL) 
(DEFPROP INTERNAL-< 52000 QLVAL) 
(DEFPROP EQ 72000 QLVAL)
;;; SETE CDR 112000
;;; SETE CDDR 132000
;;; SETE 1+ 152000
;;; SETE 1- 172000

;ND3
;;; 13000 unused, used to be BIND.
(DEFPROP BINDNIL 33000 QLVAL) 
(DEFPROP BINDPOP 53000 QLVAL) 
(DEFPROP SETNIL 73000 QLVAL) 
(DEFPROP SETZERO 113000 QLVAL) 
(DEFPROP PUSH-E 133000 QLVAL)
(DEFPROP MOVEM 153000 QLVAL) 
(DEFPROP POP 173000 QLVAL)

;;; 14 BRANCH
(DEFPROP MISC 15000 QLVAL)

;;; - MISCELLANEOUS FUNCTIONS -
;These two are no longer used
;(DEFPROP LIST 0 QLVAL)
;(DEFPROP LIST-IN-AREA 100 QLVAL)
(DEFPROP UNBIND 200 QLVAL)
 (DEFMIC UNBIND-0 200 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-1 201 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-2 202 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-3 203 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-4 204 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-5 205 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-6 206 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-7 207 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-10 210 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-11 211 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-12 212 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-13 213 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-14 214 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-15 215 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-16 216 NIL NIL T)	;FOR UCONS
 (DEFMIC UNBIND-17 217 NIL NIL T)	;FOR UCONS
(DEFPROP POPPDL 220 QLVAL)
 (DEFMIC POPPDL-0 220 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-1 221 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-2 222 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-3 223 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-4 224 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-5 225 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-6 226 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-7 227 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-10 230 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-11 231 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-12 232 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-13 233 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-14 234 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-15 235 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-16 236 NIL NIL T)	;FOR UCONS
 (DEFMIC POPPDL-17 237 NIL NIL T)	;FOR UCONS
;The rest of these come from the DEFMIC table above.

;"BASE REGISTERS"
(DEFPROP FEF 0 QLVAL) 

(DEFPROP CONST-PAGE 400 QLVAL) 

(DEFPROP LOCBLOCK 500 QLVAL) 

(DEFPROP ARG 600 QLVAL) 

(DEFPROP LPDL 700 QLVAL) 

;DESTINATIONS
(DEFPROP D-IGNORE 0 QLVAL) 

(DEFPROP D-INDS 0 QLVAL) 

(DEFPROP D-PDL 20000 QLVAL) 

(DEFPROP D-NEXT 40000 QLVAL) 

(DEFPROP D-LAST  60000 QLVAL) 

(DEFPROP D-RETURN 100000 QLVAL) 

;(DEFPROP DEST-ARG-QTD 60000 QLVAL) 		;ADDED TO D-NEXT,D-LAST

(DEFPROP D-NEXT-LIST 160000 QLVAL) 

;;; Properties for the micro-compiler

(DEFPROP M-CAR QMA LAST-ARG-IN-T-ENTRY)
(DEFPROP M-CDR QMD LAST-ARG-IN-T-ENTRY)
(DEFPROP M-CAAR QMAA LAST-ARG-IN-T-ENTRY)
(DEFPROP M-CADR QMAD LAST-ARG-IN-T-ENTRY)
(DEFPROP M-CDAR QMDA LAST-ARG-IN-T-ENTRY)
(DEFPROP M-CDDR QMDD LAST-ARG-IN-T-ENTRY)
(DEFPROP CAAAR QMAAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CAADR QMAAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CADAR QMADA LAST-ARG-IN-T-ENTRY)
(DEFPROP CADDR QMADD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDAAR QMDAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDADR QMDAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDAR QMDDA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDDR QMDDD LAST-ARG-IN-T-ENTRY)
(DEFPROP CAAAAR QMAAAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CAAADR QMAAAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CAADAR QMAADA LAST-ARG-IN-T-ENTRY)
(DEFPROP CAADDR QMAADD LAST-ARG-IN-T-ENTRY)
(DEFPROP CADAAR QMADAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CADADR QMADAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CADDAR QMADDA LAST-ARG-IN-T-ENTRY)
(DEFPROP CADDDR QMADDD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDAAAR QMDAAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDAADR QMDAAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDADAR QMDADA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDADDR QMDADD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDAAR QMDDAA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDADR QMDDAD LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDDAR QMDDDA LAST-ARG-IN-T-ENTRY)
(DEFPROP CDDDDR QMDDDD LAST-ARG-IN-T-ENTRY)

(DEFPROP M-+ XTCADD LAST-ARG-IN-T-ENTRY)	;CHECKS INPUT D.T. TO ASSURE FIXED
(DEFPROP M-- XTCSUB LAST-ARG-IN-T-ENTRY)
(DEFPROP M-* XTCMUL LAST-ARG-IN-T-ENTRY)
(DEFPROP M-// XTCDIV LAST-ARG-IN-T-ENTRY)
(DEFPROP M-LOGAND XTCAND LAST-ARG-IN-T-ENTRY)
(DEFPROP M-LOGXOR XTCXOR LAST-ARG-IN-T-ENTRY)
(DEFPROP M-LOGIOR XTCIOR LAST-ARG-IN-T-ENTRY)

;(DEFPROP XTCADD XTADD NO-TYPE-CHECKING-ENTRY)	;ONE ARG IN T, ONE ON PDL
;(DEFPROP XTCSUB XTSUB NO-TYPE-CHECKING-ENTRY)
;(DEFPROP XTCMUL XTMUL NO-TYPE-CHECKING-ENTRY)
;(DEFPROP XTCDIV XTDIV NO-TYPE-CHECKING-ENTRY)
;(DEFPROP XTCAND XTAND NO-TYPE-CHECKING-ENTRY)
;(DEFPROP XTCXOR XTXOR NO-TYPE-CHECKING-ENTRY)
;(DEFPROP XTCIOR XTIOR NO-TYPE-CHECKING-ENTRY)

;(DEFPROP M-+ XTADD UNBOXED-NUM-IN-T-ENTRY)	;THESE GUYS DONT REALLY CHECK ANYWAY
;(DEFPROP M-- XTSUB UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP M-* XTMUL UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP M-// XTDIV UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP M-LOGAND XTAND UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP M-LOGXOR XTXOR UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP M-LOGIOR XTIOR UNBOXED-NUM-IN-T-ENTRY)

;(DEFPROP M-+ XMADD NO-TYPE-CHECKING-ENTRY)	;THESE ARE A BIT FASTER
;(DEFPROP M-- XMSUB NO-TYPE-CHECKING-ENTRY)	;TAKE 2 ARGS ON PDL
;(DEFPROP M-* XMMUL NO-TYPE-CHECKING-ENTRY)
;(DEFPROP M-// XMDIV NO-TYPE-CHECKING-ENTRY)
;(DEFPROP M-LOGAND XMAND NO-TYPE-CHECKING-ENTRY)
;(DEFPROP M-LOGXOR XMXOR NO-TYPE-CHECKING-ENTRY)
;(DEFPROP M-LOGIOR XMIOR NO-TYPE-CHECKING-ENTRY)

;(DEFPROP ATOM XTATOM LAST-ARG-IN-T-ENTRY)
;(DEFPROP ZEROP XTZERO LAST-ARG-IN-T-ENTRY)
(DEFPROP NUMBERP XTNUMB LAST-ARG-IN-T-ENTRY)
(DEFPROP FIXP XTFIXP LAST-ARG-IN-T-ENTRY)
(DEFPROP FLOATP XTFLTP LAST-ARG-IN-T-ENTRY)
;(DEFPROP PLUSP XTPLUP LAST-ARG-IN-T-ENTRY)
;(DEFPROP MINUSP XTMNSP LAST-ARG-IN-T-ENTRY)
;(DEFPROP MINUS XTMNS LAST-ARG-IN-T-ENTRY)
;(DEFPROP 1+ XT1PLS LAST-ARG-IN-T-ENTRY)
;(DEFPROP 1- XT1MNS LAST-ARG-IN-T-ENTRY)
;(DEFPROP SYMEVAL XTSYME LAST-ARG-IN-T-ENTRY)
(DEFPROP LENGTH XTLENG LAST-ARG-IN-T-ENTRY)

;(DEFPROP ZEROP XBZERO UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP PLUSP XBPLUP UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP MINUSP XBMNSP UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP MINUS XBMNS UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP 1+ XB1PLS UNBOXED-NUM-IN-T-ENTRY)
;(DEFPROP 1- XB1MNS UNBOXED-NUM-IN-T-ENTRY)

;;; Certain MISC-instructions make assumptions about what destinations
;;; they are used with.  Some require D-IGNORE, because they assume that
;;; there is no return address on the micro-stack.  Some do not allow D-IGNORE,
;;; because they popj and start a memory cycle.  Some are really random.
(DEFVAR MISC-INSTRUCTION-REQUIRED-DESTINATION-ALIST
	'( (%ALLOCATE-AND-INITIALIZE D-PDL D-NEXT D-LAST D-RETURN D-NEXT-LIST)
	   (%ALLOCATE-AND-INITIALIZE-ARRAY D-PDL D-NEXT D-LAST D-RETURN D-NEXT-LIST)
	   (%SPREAD D-NEXT D-LAST)
	   (RETURN-LIST D-RETURN)
	   (%OPEN-CALL-BLOCK D-IGNORE D-INDS)
	   (%ACTIVATE-OPEN-CALL-BLOCK D-IGNORE D-INDS)
	   (%RETURN-2 D-IGNORE D-INDS)
	   (%RETURN-3 D-IGNORE D-INDS)
	   (%RETURN-N D-IGNORE D-INDS)
	   (%RETURN-NEXT-VALUE D-IGNORE D-INDS)))
