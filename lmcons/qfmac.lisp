;-*-LISP-*-
;BYTE HACKING ROUTINES

(DECLARE (FIXNUM (LOGLDB-FROM-FIXNUM FIXNUM FIXNUM)
		 (LOGDPB-INTO-FIXNUM FIXNUM FIXNUM FIXNUM)
		 (LOGLDB FIXNUM NOTYPE)
		 (MASK-FIELD-FROM-FIXNUM FIXNUM FIXNUM))
	 (NOTYPE (LOGDPB FIXNUM FIXNUM NOTYPE)))

;FIXNUM DECLARATIONS FOR BASIC LISP FUNCTIONS DEFINED IN QF

(DECLARE (FIXNUM (QF-CAR FIXNUM) (QF-CDR FIXNUM)
		 (QF-CONS FIXNUM FIXNUM)
		 (QF-RPLACA FIXNUM FIXNUM) (QF-RPLACD FIXNUM FIXNUM)
		 (QF-VALUE-CELL-LOCATION FIXNUM)
		 (QF-FUNCTION-CELL-LOCATION FIXNUM)
		 (QF-PROPERTY-CELL-LOCATION FIXNUM)
		 (QF-FUNCTION-CELL-CONTENTS NOTYPE)
		 (QF-VALUE-CELL-CONTENTS NOTYPE)
		 ;(QF-AREA-ORIGIN NOTYPE)
		 (QF-INITIAL-AREA-ORIGIN NOTYPE)	;WORKS FOR AREAS IN COLD-LOAD
		 (QF-AREA-NUMBER NOTYPE)
		 (QF-ARRAY-DISPLACE FIXNUM)
		 (QF-ARRAY-READ FIXNUM)
		 (QF-ARRAY-WRITE FIXNUM FIXNUM)
		 (QF-ARRAY-LENGTH FIXNUM)
		 (QF-ARRAY-ACTIVE-LENGTH FIXNUM)
		 (QF-ARRAY-DIMENSION-N FIXNUM FIXNUM)	;DOESN'T WORK ON THE LAST DIMENSION!
		 (QF-AR-1 FIXNUM FIXNUM)
		 (QF-AS-1 FIXNUM FIXNUM FIXNUM)
		 (QF-AR-2 FIXNUM FIXNUM FIXNUM)
		 (QF-AS-2 FIXNUM FIXNUM FIXNUM FIXNUM)
		 (QF-ARRAY-LEADER FIXNUM FIXNUM)
		 (QF-STORE-ARRAY-LEADER FIXNUM FIXNUM FIXNUM)
		 (QF-ARRAY-PUSH FIXNUM FIXNUM)
		 (QF-MAKE-ARRAY NOTYPE NOTYPE NOTYPE NOTYPE NOTYPE NOTYPE)
		 (QF-SYMBOL NOTYPE)
		 (QF-SYMBOL1 NOTYPE FIXNUM)
		 (QF-SYMBOL2 NOTYPE FIXNUM)
		 (QF-SYMBOL-SEARCH NOTYPE FIXNUM)
		 (QF-SYMBOL-PKG NOTYPE FIXNUM)
		 (QF-SYMBOL-OLD NOTYPE FIXNUM)
		 (QF-PKG-HASH-STRING NOTYPE)
		 (QF-PKG-HASH-LM-STRING FIXNUM)
		 (QF-ROT-24-BIT FIXNUM FIXNUM)
		 (QF-LM-STRING-INTERN FIXNUM FIXNUM NOTYPE)
		 (QF-LM-STRING-INTO-SYMBOL FIXNUM)
		 (QF-SXHASH NOTYPE)
		 (QF-LM-STRING-SXHASH FIXNUM)
		 (QF-MACLISP-SYM-INTERN NOTYPE FIXNUM FIXNUM)
		 (QF-ALLOCATE-BLOCK FIXNUM FIXNUM)
		 (QF-REGION-NUMBER-OF-POINTER FIXNUM)
		 (QF-AREA-NUMBER-OF-POINTER FIXNUM)
)
	 (NOTYPE (QF-CLEAR-CACHE NOTYPE)
		 (QF-ARRAY-SETUP FIXNUM)
		 ;(QF-ADJUST-ARRAY-SIZE FIXNUM FIXNUM NOTYPE)
		 ;(QF-RETURN-ARRAY FIXNUM FIXNUM)
		 ;(QF-RETURN-ARRAY1 FIXNUM FIXNUM)
		 ;(QF-ARRAY-AT-END-OF-AREA-P FIXNUM FIXNUM)
		 (QF-LM-STRING-EQUAL FIXNUM FIXNUM FIXNUM)
		 (QF-SAMEPNAMEP NOTYPE FIXNUM)
))

;SPECIAL VARIABLES FOR ARRAY STUFF

(DECLARE (SPECIAL QF-ARRAY-HEADER QF-ARRAY-DISPLACED-P QF-ARRAY-HAS-LEADER-P 
  QF-ARRAY-NUMBER-DIMS QF-ARRAY-HEADER-ADDRESS QF-ARRAY-DATA-ORIGIN QF-ARRAY-LENGTH))

(DECLARE (FIXNUM QF-ARRAY-HEADER QF-ARRAY-NUMBER-DIMS QF-ARRAY-HEADER-ADDRESS
  QF-ARRAY-DATA-ORIGIN QF-ARRAY-LENGTH))

;REDECLARE THIS SO FUNCTION GETS CALLED, INSTEAD OF VALUE FUNCALLED.
(DECLARE (*EXPR QF-ARRAY-LENGTH) (FIXNUM (QF-ARRAY-LENGTH FIXNUM)))


;SYMBOLS FROM CONSOLE

(DECLARE (SPECIAL RAPBO RAM1O RAM2O)
	 (FIXNUM RAPBO RAM1O RAM2O))

;SYMBOLS FROM QCOM

(DECLARE (SPECIAL %%ARRAY-TYPE-FIELD %%ARRAY-LEADER-BIT %%ARRAY-DISPLACED-BIT
		  %%ARRAY-FLAG-BIT %%ARRAY-NUMBER-DIMENSIONS %%ARRAY-LONG-LENGTH-FLAG
		  %%ARRAY-NAMED-STRUCTURE-FLAG
		  %%ARRAY-INDEX-LENGTH-IF-SHORT ARRAY-TYPES ARRAY-ELEMENTS-PER-Q
		  %ARRAY-MAX-SHORT-INDEX-LENGTH HEADER-TYPE-ARRAY-LEADER
		  ARRAY-DIM-MULT ART-32B FSM-LINEAR-ADVANCING
		  %SYS-COM-OBARRAY-PNTR 
		  %SYS-COM-AREA-ORIGIN-PNTR AREA-LIST SIZE-OF-AREA-ARRAYS

		  DTP-TRAP DTP-NULL DTP-FREE 
		  DTP-SYMBOL DTP-SYMBOL-HEADER DTP-FIX DTP-EXTENDED-NUMBER 
		    DTP-HEADER 
		  DTP-GC-FORWARD DTP-EXTERNAL-VALUE-CELL-POINTER DTP-ONE-Q-FORWARD
		  DTP-HEADER-FORWARD DTP-BODY-FORWARD
		  DTP-LOCATIVE 
		  DTP-LIST 
		  DTP-U-ENTRY   
		  DTP-FEF-POINTER DTP-ARRAY-POINTER DTP-ARRAY-HEADER 
		  DTP-STACK-GROUP DTP-CLOSURE DTP-ENTITY
		  %PHT-SWAP-STATUS-NORMAL %PHT-SWAP-STATUS-FLUSHABLE 
		  %PHT-SWAP-STATUS-AGE-TRAP %%PHT1-VIRTUAL-PAGE-NUMBER 
		  %%PHT2-PHYSICAL-PAGE-NUMBER %%PHT1-SWAP-STATUS-CODE 
		  %%PHT2-MAP-STATUS-CODE %PHT-MAP-STATUS-READ-WRITE
		  %%PHT2-ACCESS-STATUS-AND-META-BITS %%PHT1-MODIFIED-BIT
		  %%REGION-MAP-BITS %%REGION-OLDSPACE-META-BIT %%REGION-EXTRA-PDL-META-BIT
		  %%REGION-REPRESENTATION-TYPE %REGION-REPRESENTATION-TYPE-LIST
		  %REGION-REPRESENTATION-TYPE-STRUCTURE %%REGION-COMPACT-CONS-FLAG
		  %%REGION-SPACE-TYPE %REGION-SPACE-FREE %REGION-SPACE-OLD %REGION-SPACE-NEW
		  %REGION-SPACE-STATIC %REGION-SPACE-FIXED %REGION-SPACE-EXITED
		  %REGION-SPACE-EXIT %REGION-SPACE-EXTRA-PDL %REGION-SPACE-WIRED
		  %REGION-SPACE-MAPPED
)
	 (FIXNUM  %%ARRAY-TYPE-FIELD %%ARRAY-LEADER-BIT %%ARRAY-DISPLACED-BIT
		  %%ARRAY-FLAG-BIT %%ARRAY-NUMBER-DIMENSIONS %%ARRAY-LONG-LENGTH-FLAG
		  %%ARRAY-INDEX-LENGTH-IF-SHORT %ARRAY-MAX-SHORT-INDEX-LENGTH
		  ARRAY-DIM-MULT ART-32B HEADER-TYPE-ARRAY-LEADER
		  DTP-TRAP DTP-NULL DTP-FREE 
		  DTP-SYMBOL DTP-SYMBOL-HEADER DTP-FIX DTP-EXTENDED-NUMBER 
		    DTP-HEADER 
		  DTP-GC-FORWARD DTP-EXTERNAL-VALUE-CELL-POINTER DTP-ONE-Q-FORWARD
		  DTP-HEADER-FORWARD DTP-BODY-FORWARD
		  DTP-LOCATIVE 
		  DTP-LIST 
		  DTP-U-ENTRY  
		  DTP-FEF-POINTER DTP-ARRAY-POINTER DTP-ARRAY-HEADER 
		  DTP-STACK-GROUP DTP-CLOSURE))

;FIXNUM BOOLEAN FUNCTIONS

(DEFMACRO LOGAND (&REST X) `(BOOLE 1 ,@X))
(DEFMACRO LOGIOR (&REST X) `(BOOLE 7 ,@X))
(DEFMACRO LOGXOR (&REST X) `(BOOLE 6 ,@X))

;FIXNUM LOGLDB WITH CONSTANT 1ST ARG, IN-LINE
(DEFUN LOGLDB* MACRO (X)
  ((LAMBDA (BYTE)
    ((LAMBDA (P S W)
       (LIST 'BOOLE 1 (1- (LSH 1 S))
	     (LIST 'LSH W (- P))))
     (LSH BYTE -6)
     (BOOLE 1 BYTE 77)
     (CADDR X)))
   (COND ((NUMBERP (CADR X)) (CADR X))
	 (T (EVAL (CADR X))))))

;FIXNUM LOGDPB WITH CONSTANT 2ND ARG, IN-LINE
(DEFUN LOGDPB* MACRO (X)
  ((LAMBDA (BYTE)
     ((LAMBDA (P S D W)
        ((LAMBDA (M)
    	   (LIST 'BOOLE 7 (LIST 'BOOLE 1 (BOOLE 6 -1 (LSH M P)) W)
		          (LIST 'LSH (LIST 'BOOLE 1 M D) P)))
	 (1- (LSH 1 S))))
      (LSH BYTE -6)
      (BOOLE 1 BYTE 77)
      (CADR X)
      (CADDDR X)))
   (COND ((NUMBERP (CADDR X)) (CADDR X))
	 (T (EVAL (CADDR X))))))

;FUNCTIONS TO EXAMINE AND DEPOSIT FIELDS OF A Q

;BUILD A Q, GIVEN THE CONTENTS OF ITS FIELDS.
;THE CDR-CODE DEFAULTS TO CDR-ERROR.
(DEFMACRO QF-MAKE-Q (POINTER DATA-TYPE &OPTIONAL CDR-CODE)
     (COND (CDR-CODE
	    `(QF-SMASH-CDR-CODE (QF-SMASH-DATA-TYPE ,POINTER ,DATA-TYPE) ,CDR-CODE))
	   (T `(QF-SMASH-DATA-TYPE ,POINTER ,DATA-TYPE))))

(DEFMACRO QF-DATA-TYPE (Q) `(LOGLDB* 3005 ,Q))

(DEFMACRO QF-POINTER (Q) `(BOOLE 1 77777777 ,Q))

(DEFMACRO QF-CDR-CODE (Q) `(LOGLDB* 3602 ,Q))

(DEFMACRO QF-FLAG-BIT (Q) `(LOGLDB* 3501 ,Q))

(DEFMACRO QF-TYPED-POINTER (Q) `(LOGLDB* 0035 ,Q))

;SMASH VAL INTO POINTER AND DATA-TYPE OF Q
(DEFMACRO QF-SMASH-TYPED-POINTER (Q VAL) `(LOGDPB* ,VAL 0035 ,Q))

(DEFMACRO QF-SMASH-CDR-CODE (Q VAL) `(LOGDPB* ,VAL 3602 ,Q))

(DEFMACRO QF-SMASH-FLAG-BIT (Q VAL) `(LOGDPB* ,VAL 3501 ,Q))

(DEFMACRO QF-SMASH-POINTER (Q VAL) `(LOGDPB* ,VAL 0030 ,Q))

(DEFMACRO QF-SMASH-DATA-TYPE (Q VAL) `(LOGDPB* ,VAL 3005 ,Q))

(DECLARE (SPECIAL QF-NIL))
(SETQ QF-NIL (QF-MAKE-Q 0 DTP-SYMBOL))		;******* NIL KNOWN TO BE AT ZERO *******

;;;; ANALOGUES OF %P-POINTER, %P-STORE-POINTER, ETC.

(DEFMACRO QF-P-POINTER (LOC) `(QF-POINTER (QF-MEM-READ ,LOC)))

(DEFMACRO QF-P-DATA-TYPE (LOC) `(QF-DATA-TYPE (QF-MEM-READ ,LOC)))

(DEFMACRO QF-P-FLAG-BIT (LOC) `(QF-FLAG-BIT (QF-MEM-READ ,LOC)))

(DEFMACRO QF-P-CDR-CODE (LOC) `(QF-CDR-CODE (QF-MEM-READ ,LOC)))

(DEFMACRO QF-P-CONTENTS (LOC) `(QF-TYPED-POINTER (QF-MEM-READ ,LOC)))

(DEFMACRO QF-P-STORE-POINTER (LOC VAL)
     `(LET ((ADDR* ,LOC))
	   (QF-MEM-WRITE (QF-SMASH-POINTER (QF-MEM-READ ADDR*)
					   ,VAL)
			 ADDR*)))

(DEFMACRO QF-P-STORE-CONTENTS (LOC VAL)
     `(LET ((ADDR* ,LOC))
	   (QF-MEM-WRITE (QF-SMASH-TYPED-POINTER (QF-MEM-READ ADDR*)
						 ,VAL)
			 ADDR*)))

(DEFMACRO QF-P-STORE-DATA-TYPE (LOC VAL)
     `(LET ((ADDR* ,LOC))
	   (QF-MEM-WRITE (QF-SMASH-DATA-TYPE (QF-MEM-READ ADDR*)
					     ,VAL)
			 ADDR*)))

(DEFMACRO QF-P-STORE-FLAG-BIT (LOC VAL)
     `(LET ((ADDR* ,LOC))
	   (QF-MEM-WRITE (QF-SMASH-FLAG-BIT (QF-MEM-READ ADDR*)
					    ,VAL)
			 ADDR*)))

(DEFMACRO QF-P-STORE-CDR-CODE (LOC VAL)
     `(LET ((ADDR* ,LOC))
	   (QF-MEM-WRITE (QF-SMASH-CDR-CODE (QF-MEM-READ ADDR*)
					    ,VAL)
			 ADDR*)))

(DEFMACRO QF-NULL (X) `(= ,X QF-NIL))

(DEFMACRO SELECTN (ITEM . BODY)
   `((LAMBDA (*SELECTN-ITEM*)
	(COND . ,(MAPCAR
		  '(LAMBDA (CLAUSE)
		       (COND ((EQ (CAR CLAUSE) 'OTHERWISE)
			      `(T . ,(CDR CLAUSE)))
			     ((ATOM (CAR CLAUSE))
			      `((= *SELECTN-ITEM* ,(CAR CLAUSE)) . ,(CDR CLAUSE)))
			     (T `((OR . ,(MAPCAR '(LAMBDA (ITEM) `(= *SELECTN-ITEM* ,ITEM))
						 (CAR CLAUSE))) . ,(CDR CLAUSE)))))
			 BODY)))
     ,ITEM))

