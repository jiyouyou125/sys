;;; -*- Mode: Lisp; Package: User; Base: 8.; Patch-File: T -*-
;;; Patch file for System version 78.1
;;; Reason: Fix band transfer server
;;; Written 12/07/81 21:39:32 by MMcM,
;;; while running on Lisp Machine Seven from band 7
;;; with Experimental System 78.0, Experimental ZMail 38.0, microcode 836.



; From file ZMACS 296 ZWEI; AI:
#8R ZWEI:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "ZWEI")))

(DEFUN SAVE-BUFFER (BUFFER &AUX FILE-ID PATHNAME)
  (SETQ FILE-ID (BUFFER-FILE-ID BUFFER)  
	PATHNAME (BUFFER-PATHNAME BUFFER))
  (COND ((NULL FILE-ID)
	 (FS:SET-DEFAULT-PATHNAME (FUNCALL (DEFAULT-PATHNAME) ':NEW-NAME (BUFFER-NAME BUFFER))
				  *PATHNAME-DEFAULTS*)
	 (SETQ PATHNAME (IF *WINDOW* (READ-DEFAULTED-PATHNAME "Save File:" (PATHNAME-DEFAULTS)
							      NIL NIL ':WRITE)
			  (FORMAT QUERY-IO "~&Save file to: ")
			  (MAKE-DEFAULTED-PATHNAME (READLINE) (PATHNAME-DEFAULTS))))
	 (SET-BUFFER-PATHNAME PATHNAME BUFFER)))
  (AND (OR (SYMBOLP FILE-ID)
	   (EQUAL FILE-ID (WITH-OPEN-FILE (S PATHNAME '(:PROBE :ASCII))
			    (AND (NOT (STRINGP S)) (FUNCALL S ':INFO))))
	   (FQUERY '#,`(:SELECT T
			:BEEP T
		        :TYPE READLINE
		        :CHOICES ,FORMAT:YES-OR-NO-P-CHOICES)
		   "~A has been changed on disk since you last read or wrote it.~@
		    Save it anyway? "
		   PATHNAME))
       (WRITE-FILE-INTERNAL PATHNAME BUFFER))
  T)

)

; From file ZMACS 296 ZWEI; AI:
#8R ZWEI:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "ZWEI")))

;;; This can be called from top-level to try to save a bombed ZMACS
(DEFUN SAVE-ALL-FILES ()
  (DOLIST (BUFFER *ZMACS-BUFFER-LIST*)
    (AND (LET ((BUFFER-TICK (BUFFER-TICK BUFFER)))
	   (AND (NUMBERP BUFFER-TICK)
		(> (NODE-TICK BUFFER) BUFFER-TICK)))
	 (FQUERY NIL "Save file ~A ? " (BUFFER-NAME BUFFER))
	 (LET ((*WINDOW* NIL)
	       (*WINDOW-LIST* NIL)
	       (*INTERVAL* NIL)
	       (*TYPEOUT-WINDOW* STANDARD-OUTPUT)
	       (*TYPEIN-WINDOW* STANDARD-OUTPUT)
	       (*NUMERIC-ARG-P* NIL))
	   (SAVE-BUFFER BUFFER)))))

)

; From file SALVAG > ZWEI; AI:
#8R CADR:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "CADR")))

;;;-*- Mode:LISP; Package:CADR -*-

;;; Save all files on the object machine
(DEFUN SALVAGE-EDITOR ()
  (PKG-GOTO "CADR")				;Lots of stuff doesn't work otherwise
  (DO ((BUFFER-LIST (CC-MEM-READ (1+ (QF-POINTER (QF-SYMBOL 'ZWEI:*ZMACS-BUFFER-LIST*))))
		    (QF-CDR BUFFER-LIST))
       BUFFER)
      ((CC-Q-NULL BUFFER-LIST))
    (SETQ BUFFER (QF-CAR BUFFER-LIST))
    (AND (LET ((BUFFER-TICK (QF-AR-1 BUFFER (GET-DEFSTRUCT-INDEX 'ZWEI:BUFFER-TICK 'AREF))))
	   (AND (= DTP-FIX (LOGLDB %%Q-DATA-TYPE BUFFER-TICK))
		(> (LOGLDB %%Q-POINTER
			   (QF-AR-1 BUFFER (GET-DEFSTRUCT-INDEX 'ZWEI:NODE-TICK 'AREF)))
		   (LOGLDB %%Q-POINTER BUFFER-TICK))))
	 (LET ((BUFFER-NAME (WITH-OUTPUT-TO-STRING (CC-OUTPUT-STREAM)
			      (CC-Q-PRINT-STRING
				(QF-AR-1 BUFFER
					 (GET-DEFSTRUCT-INDEX 'ZWEI:BUFFER-NAME 'AREF))))))
	   (AND (FQUERY NIL "Save buffer ~A? " BUFFER-NAME)
		(SALVAGE-INTERVAL BUFFER
				  (IF (NOT (CC-Q-NULL
					     (QF-AR-1 BUFFER
						      (GET-DEFSTRUCT-INDEX
							'ZWEI:BUFFER-FILE-ID 'AREF))))
				      BUFFER-NAME
				    (FORMAT QUERY-IO "~&Write ~A to file: " BUFFER-NAME)
				    (READLINE QUERY-IO))))))))

)

; From file DISK > LMIO; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

;Returns NIL if no such partition, or 3 values (FIRST-BLOCK N-BLOCKS LABEL-LOC) if it exists
(DEFUN FIND-DISK-PARTITION (NAME &OPTIONAL RQB (UNIT 0) (ALREADY-READ-P NIL) CONFIRM-WRITE
			    &AUX (RETURN-RQB NIL))
  (DECLARE (RETURN-LIST FIRST-BLOCK N-BLOCKS LABEL-LOC NAME))
  (IF (AND (CLOSUREP UNIT)
	   (FUNCALL UNIT ':HANDLES-LABEL))
      (FUNCALL UNIT ':FIND-DISK-PARTITION NAME)
      (PROG FIND-DISK-PARTITION ()
	(UNWIND-PROTECT
	  (PROGN
	    (COND ((NULL RQB)
		   (WITHOUT-INTERRUPTS
		     (SETQ RETURN-RQB T
			   RQB (GET-DISK-RQB)))))
	    (OR ALREADY-READ-P (READ-DISK-LABEL RQB UNIT))
	    (DO ((N-PARTITIONS (GET-DISK-FIXNUM RQB 200))
		 (WORDS-PER-PART (GET-DISK-FIXNUM RQB 201))
		 (I 0 (1+ I))
		 (LOC 202 (+ LOC WORDS-PER-PART)))
		((= I N-PARTITIONS) NIL)
	      (COND ((STRING-EQUAL (GET-DISK-STRING RQB LOC 4) NAME)
		     (AND CONFIRM-WRITE
			  (NOT (FQUERY FORMAT:YES-OR-NO-QUIETLY-P-OPTIONS
				"Do you really want to clobber partition ~A ~
				 ~:[~*~;on unit ~D ~](~A)? "
				NAME (NUMBERP UNIT) UNIT				
				(GET-DISK-STRING RQB (+ LOC 3) 16.)))
			  (RETURN-FROM FIND-DISK-PARTITION NIL T))
		     (RETURN-FROM FIND-DISK-PARTITION
				  (GET-DISK-FIXNUM RQB (+ LOC 1))
				  (GET-DISK-FIXNUM RQB (+ LOC 2))
				  LOC
				  NAME)))))
	  (AND RETURN-RQB (RETURN-DISK-RQB RQB))))))

)

; From file EHR > LMWIN; AI:
#8R EH:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "EH")))

(DEFUN ERRORP (THING)
  (STRINGP THING))

)

; From file GLOBAL > LISPM2; AI:
#8R EH:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "EH")))

(GLOBALIZE 'ERRORP)

)
