;;; -*- Mode: LISP; Package: TV; Base: 8 -*-
;;;	** (c) Copyright 1980 Massachusetts Institute of Technology **

;;; This file contains:  IO buffers, keyboard process

;;; IO buffers (definition in NTVDEF)

(DEFUN (IO-BUFFER NAMED-STRUCTURE-INVOKE) (OP BUFFER &REST ARGS)
  "Printer for IO-BUFFER named structures"
  (SELECTQ OP
    (:WHICH-OPERATIONS '(:PRINT-SELF))
    ((:PRINT-SELF)
     (SI:PRINTING-RANDOM-OBJECT (BUFFER (CAR ARGS) :NO-POINTER)
       (FORMAT (CAR ARGS) "IO-BUFFER ~O: " (%POINTER BUFFER))
       (COND ((= (IO-BUFFER-INPUT-POINTER BUFFER)
		 (IO-BUFFER-OUTPUT-POINTER BUFFER))
	      (PRINC "empty, " (CAR ARGS)))
	     (T (FORMAT (CAR ARGS) "~D entr~:@P, "
			(LET ((DIFF (- (IO-BUFFER-INPUT-POINTER BUFFER)
				       (IO-BUFFER-OUTPUT-POINTER BUFFER))))
			  (IF (< DIFF 0)
			      (+ DIFF (IO-BUFFER-SIZE BUFFER))
			      DIFF)))))
	    (FORMAT (CAR ARGS) "State: ~A" (IO-BUFFER-STATE BUFFER))))
    (OTHERWISE (FERROR NIL "I don't know about ~S" OP))))


(DEFUN MAKE-IO-BUFFER (SIZE &OPTIONAL IN-FUN OUT-FUN PLIST STATE &AUX BUFFER)
  "Create a new IO buffer of specified size"
  (SETQ BUFFER (MAKE-ARRAY NIL 'ART-Q SIZE NIL IO-BUFFER-LEADER-SIZE NIL T))
  (STORE-ARRAY-LEADER 'IO-BUFFER BUFFER 1)
  (SETF (IO-BUFFER-FILL-POINTER BUFFER) 0)
  (SETF (IO-BUFFER-SIZE BUFFER) SIZE)
  (SETF (IO-BUFFER-INPUT-POINTER BUFFER) 0)
  (SETF (IO-BUFFER-OUTPUT-POINTER BUFFER) 0)
  (SETF (IO-BUFFER-INPUT-FUNCTION BUFFER) IN-FUN)
  (SETF (IO-BUFFER-OUTPUT-FUNCTION BUFFER) OUT-FUN)
  (SETF (IO-BUFFER-STATE BUFFER) STATE)
  (SETF (IO-BUFFER-PLIST BUFFER) PLIST)
  BUFFER)

(DEFUN MAKE-DEFAULT-IO-BUFFER ()
  (MAKE-IO-BUFFER 100 NIL 'KBD-DEFAULT-OUTPUT-FUNCTION))

(DEFUN IO-BUFFER-PUT (BUFFER ELT &OPTIONAL (NO-HANG-P NIL))
  "Store a new element in an IO buffer"
  (DO ((INHIBIT-SCHEDULING-FLAG T T)
       (IGNORE-P)
       (INPUT-POINTER)
       (IN-FUN (IO-BUFFER-INPUT-FUNCTION BUFFER)))
      (())
    (COND ((OR (NULL (IO-BUFFER-STATE BUFFER))
	       (EQ (IO-BUFFER-STATE BUFFER) ':INPUT))
	   (COND (IN-FUN
		  ;; Call function with INHIBIT-SCHEDULING-FLAG turned on and bound.
		  ;; Since this function may change the state of the buffer either directly
		  ;; or indirectly, loop in order to check the state.  Set the function to
		  ;; NIL, though, so it won't be run again
		  (MULTIPLE-VALUE (ELT IGNORE-P)
		    (FUNCALL IN-FUN BUFFER ELT))
		  (AND IGNORE-P (RETURN T))
		  (SETQ IN-FUN NIL))
		 (T
		  (COND ((NOT (IO-BUFFER-FULL-P BUFFER))
			 (SETF (IO-BUFFER-LAST-INPUT-PROCESS BUFFER) CURRENT-PROCESS)
			 (SETQ INPUT-POINTER (IO-BUFFER-INPUT-POINTER BUFFER))
			 (ASET ELT BUFFER INPUT-POINTER)
			 (SETF (IO-BUFFER-INPUT-POINTER BUFFER)
			       (\ (1+ INPUT-POINTER) (IO-BUFFER-SIZE BUFFER)))
			 (RETURN T))
			(NO-HANG-P (RETURN NIL))
			(T
			  (SETQ INHIBIT-SCHEDULING-FLAG NIL)
			  (PROCESS-WAIT "Buffer full" #'(LAMBDA (BUF)
							  (NOT (IO-BUFFER-FULL-P BUF)))
					BUFFER))))))
	  (NO-HANG-P (RETURN NIL))
	  (T
	   (SETQ INHIBIT-SCHEDULING-FLAG NIL)
	   (PROCESS-WAIT "Buffer state" #'(LAMBDA (BUF)
					    (OR (NULL (IO-BUFFER-STATE BUF))
						(EQ (IO-BUFFER-STATE BUF) ':INPUT)))
			 BUFFER)))))

(DEFUN IO-BUFFER-GET (BUFFER &OPTIONAL (NO-HANG-P NIL))
  "Get an element from an IO buffer.  First value is ele, second is T if got one, else NIL"
  (SETF (IO-BUFFER-LAST-OUTPUT-PROCESS BUFFER) CURRENT-PROCESS)
  (DO ((INHIBIT-SCHEDULING-FLAG T T)
       (ELT)
       (IGNORE-P)
       (OUTPUT-POINTER)
       (OUT-FUN (IO-BUFFER-OUTPUT-FUNCTION BUFFER)))
      (())
    (COND ((OR (NULL (IO-BUFFER-STATE BUFFER))
	       (EQ (IO-BUFFER-STATE BUFFER) ':OUTPUT))
	   (COND ((NOT (IO-BUFFER-EMPTY-P BUFFER))
		  (SETQ OUTPUT-POINTER (IO-BUFFER-OUTPUT-POINTER BUFFER))
		  (SETQ ELT (AREF BUFFER OUTPUT-POINTER))
		  (SETF (IO-BUFFER-OUTPUT-POINTER BUFFER)
			(\ (1+ OUTPUT-POINTER) (IO-BUFFER-SIZE BUFFER)))
		  (COND ((AND OUT-FUN
			      ;; Call function with INHIBIT-SCHEDULING-FLAG on and bound.
			      ;; If element is to be ignored, loop back, else return element
			      (PROG2
			        (MULTIPLE-VALUE (ELT IGNORE-P)
				  (FUNCALL OUT-FUN BUFFER ELT))
				IGNORE-P)))
			(T (RETURN ELT T))))
		 (NO-HANG-P (RETURN NIL NIL))
		 (T
		  (SETQ INHIBIT-SCHEDULING-FLAG NIL)
		  (PROCESS-WAIT "Buffer empty" #'(LAMBDA (BUF)
						   (NOT (IO-BUFFER-EMPTY-P BUF)))
				BUFFER))))
	  (NO-HANG-P (RETURN NIL NIL))
	  (T
	   (SETQ INHIBIT-SCHEDULING-FLAG NIL)
	   (PROCESS-WAIT "Buffer state" #'(LAMBDA (BUF)
					    (OR (NULL (IO-BUFFER-STATE BUF))
						(EQ (IO-BUFFER-STATE BUF) ':OUTPUT)))
			 BUFFER)))))

(DEFUN IO-BUFFER-UNGET (BUFFER ELT)
  "Return ELT to the IO-BUFFER by backing up the pointer.  ELT should be the last thing
read from the buffer."
  (WITHOUT-INTERRUPTS
    (LET ((OUTPUT-POINTER (1- (IO-BUFFER-OUTPUT-POINTER BUFFER))))
      (AND (< OUTPUT-POINTER 0)
	   (SETQ OUTPUT-POINTER (1- (IO-BUFFER-SIZE BUFFER))))
      (OR (EQ ELT (AREF BUFFER OUTPUT-POINTER))
	  (FERROR NIL
	    "Attempt to un-get something different then last element gotten from IO-BUFFER"))
      (SETF (IO-BUFFER-OUTPUT-POINTER BUFFER) OUTPUT-POINTER))))

(DEFUN IO-BUFFER-CLEAR (BUFFER)
  "Clears out an IO buffer"
  (WITHOUT-INTERRUPTS
    (SETF (IO-BUFFER-INPUT-POINTER BUFFER) 0)
    (SETF (IO-BUFFER-OUTPUT-POINTER BUFFER) 0)
    T))

(DEFUN PROCESS-TYPEAHEAD (IO-BUFFER FUNCTION)
  (DO ((INPUT-POINTER (IO-BUFFER-INPUT-POINTER IO-BUFFER))
       (CH))
      ((= INPUT-POINTER (IO-BUFFER-OUTPUT-POINTER IO-BUFFER)))
    (AND (SETQ CH (FUNCALL FUNCTION (IO-BUFFER-GET IO-BUFFER T)))
	 (IO-BUFFER-PUT IO-BUFFER CH T))))

(DEFVAR KBD-IO-BUFFER (MAKE-IO-BUFFER 1000))	;Intermediate buffer so char is read out of
						; hardware immediatly
(DEFVAR KBD-ESC-HAPPENED NIL)			;An escape was typed
(DEFVAR KBD-ESC-TIME NIL)	;If non-NIL, this is the time we started processing
				;an escape (Terminal or System) which is still in process.
				;We try not to look at the keyboard while one is still
				;in process to provide more predictable behavior with
				;typeahead.  However, we don't wait forever so that if
				;the process hangs forever the system doesn't "die".

(DEFUN KBD-PROCESS-MAIN-LOOP ()
  "This function runs in the keyboard process.  It is responsible for reading characters
from the hardware, and performing any immediate processing associated with the character."
  (DO () (NIL)
    (*CATCH 'SYS:COMMAND-LEVEL
      (PROGN
	(IO-BUFFER-CLEAR KBD-IO-BUFFER)
	(SETQ KBD-ESC-HAPPENED NIL)
	(DO () (NIL)
	  (PROCESS-WAIT "Keyboard"
			#'(LAMBDA ()
			    (OR KBD-ESC-HAPPENED
				(AND (NOT (IO-BUFFER-FULL-P KBD-IO-BUFFER))
				     (KBD-HARDWARE-CHAR-AVAILABLE)))))
	  (COND (KBD-ESC-HAPPENED
		  (FUNCALL KBD-ESC-HAPPENED)
		  (PROCESS-WAIT "ESC Finish"
				#'(LAMBDA () (LET ((X KBD-ESC-TIME))
					       (OR (NULL X)	;Wait at most 10 seconds
						   (> (TIME-DIFFERENCE (TIME) X) 600.)))))
		  (SETQ KBD-ESC-HAPPENED NIL)))
	  (KBD-PROCESS-MAIN-LOOP-INTERNAL))))))

;Note that KBD-CONVERT-TO-SOFTWARE-CHAR must be called in order,
;since for the new keyboards it does shifts and keeps state.

(DEFUN KBD-PROCESS-MAIN-LOOP-INTERNAL (&AUX BUFFER PLIST RAW-P)
  (WITHOUT-INTERRUPTS
    (COND ((SETQ BUFFER (KBD-GET-IO-BUFFER))
	   (SETQ PLIST (LOCF (IO-BUFFER-PLIST BUFFER)))
	   (SETQ RAW-P (GET PLIST ':RAW))))
    (DO ((CHAR)
	 (SOFT-CHAR))
	((OR KBD-ESC-HAPPENED
	     (NOT (KBD-HARDWARE-CHAR-AVAILABLE))))
      (SETQ CHAR (KBD-GET-HARDWARE-CHAR))
      (COND (RAW-P
	     (OR (IO-BUFFER-FULL-P BUFFER)
		 (IO-BUFFER-PUT BUFFER CHAR)))
	    (T
	     (SETQ SOFT-CHAR (KBD-CONVERT-TO-SOFTWARE-CHAR CHAR))
	     (COND ((NULL SOFT-CHAR))			;Unreal char
		   (T (SETQ CHAR (LDB %%KBD-CHAR SOFT-CHAR)	;No bucky bits
			    KBD-LAST-ACTIVITY-TIME (TIME)
			    SI:WHO-LINE-JUST-COLD-BOOTED-P NIL)
		      (COND ((= SOFT-CHAR #\ESC)	;Must have no bucky bits--for supdup
			     (SETQ KBD-ESC-HAPPENED #'KBD-ESC))
			    ((= SOFT-CHAR #\SYSTEM)
			     (SETQ KBD-ESC-HAPPENED #'KBD-SYS))
			    ((AND (= CHAR #\CALL)
				  (NOT (GET PLIST ':SUPER-IMAGE)))
			     (KBD-CALL BUFFER))
			    ((AND (MEMQ SOFT-CHAR '(#\ABORT #\ABORT #\BREAK #\BREAK))
				  (NOT (GET PLIST ':SUPER-IMAGE)))
			     (KBD-ASYNCHRONOUS-INTERCEPT-CHARACTER SOFT-CHAR))
			    ((NOT (IO-BUFFER-FULL-P KBD-IO-BUFFER))
			     (IO-BUFFER-PUT KBD-IO-BUFFER SOFT-CHAR))))))))))

(DEFUN KBD-IO-BUFFER-GET (BUFFER &OPTIONAL (NO-HANG-P NIL) (WHOSTATE "TYI"))
  (DO ((INHIBIT-SCHEDULING-FLAG T T)
       (UPDATE-STATE-P (NEQ CURRENT-PROCESS (IO-BUFFER-LAST-OUTPUT-PROCESS BUFFER)))
       (OK)
       (ELT))
      (())
    (MULTIPLE-VALUE (ELT OK)
      (IO-BUFFER-GET BUFFER T))
    ;; If new process reading, better update wholine run state
    (AND UPDATE-STATE-P (EQ BUFFER SELECTED-IO-BUFFER)
	 (WHO-LINE-RUN-STATE-UPDATE))
    ;; Got something from the normal buffer, just return it
    (AND OK (RETURN ELT))
    ;; OK is NIL here.  If we aren't selected, don't look at system's io buffer
    (AND (EQ BUFFER SELECTED-IO-BUFFER)
	 (MULTIPLE-VALUE (ELT OK)
	   (IO-BUFFER-GET KBD-IO-BUFFER T)))
    (COND (OK
	   ;; Got something from the kbd buffer, put it into the normal buffer and loop
	   (IO-BUFFER-PUT BUFFER ELT T))	;Can't hang, but...
	  ;; Nothing for baby!!!  What should we do?
	  (T
	   (AND (NOT (IO-BUFFER-FULL-P KBD-IO-BUFFER))
		(KBD-HARDWARE-CHAR-AVAILABLE)
		;; If there is a possibility that a character of interest exists in
		;; the hardware, get it
		(KBD-PROCESS-MAIN-LOOP-INTERNAL))
	   (IF (OR (NOT (IO-BUFFER-EMPTY-P BUFFER))
		   (AND (EQ BUFFER (KBD-GET-IO-BUFFER))
			(NOT (IO-BUFFER-EMPTY-P KBD-IO-BUFFER))))
	       NIL				;Have a character, so loop and get it
	       (AND NO-HANG-P (RETURN NIL))
	       (SETQ INHIBIT-SCHEDULING-FLAG NIL)
	       (PROCESS-WAIT WHOSTATE #'(LAMBDA (BUFFER)
					  (OR (NOT (IO-BUFFER-EMPTY-P BUFFER))
					      (AND (EQ BUFFER (KBD-GET-IO-BUFFER))
						   (NOT (IO-BUFFER-EMPTY-P KBD-IO-BUFFER)))))
			     BUFFER))))))

(DEFUN KBD-SNARF-INPUT (BUFFER &OPTIONAL NO-HARDWARE-CHARS-P)
  (WITHOUT-INTERRUPTS
    (COND ((NULL BUFFER))			;This can happen due to timing error
	  ((EQ BUFFER (KBD-GET-IO-BUFFER))
	   ;; There is potentially input for us
	   (OR NO-HARDWARE-CHARS-P (KBD-PROCESS-MAIN-LOOP-INTERNAL))
	   (DO ((OK)
		(ELT))
	       ((IO-BUFFER-EMPTY-P KBD-IO-BUFFER))
	     (MULTIPLE-VALUE (ELT OK)
	       (IO-BUFFER-GET KBD-IO-BUFFER T))
	     (OR OK (RETURN NIL))		;Some ignored characters, we are done
	     (AND ELT (IO-BUFFER-PUT BUFFER ELT T)))))))

(DEFVAR KBD-TYI-HOOK NIL)  ;This is a crock, but I suppose someone might want to...
(DEFCONST KBD-STANDARD-INTERCEPTED-CHARACTERS '(#\ABORT #\ABORT #\BREAK #\BREAK))
(DEFVAR KBD-INTERCEPTED-CHARACTERS KBD-STANDARD-INTERCEPTED-CHARACTERS)
(ADD-INITIALIZATION "Don't Ignore Abort"
		    '(SETQ KBD-INTERCEPTED-CHARACTERS KBD-STANDARD-INTERCEPTED-CHARACTERS)
		    '(SYSTEM))

(DEFUN KBD-DEFAULT-OUTPUT-FUNCTION (IGNORE CHAR)
  "System standard IO-BUFFER output function.
Intercepts those characters in KBD-INTERCEPTED-CHARACTERS.
Must be called with INHIBIT-SCHEDULING-FLAG bound to T, and this may SETQ it to NIL."
  (IF (AND KBD-TYI-HOOK (FUNCALL KBD-TYI-HOOK CHAR))
      (VALUES CHAR T)
      ;; Note, this must not use =, since the character may not be a number
      (COND ((MEMQ CHAR KBD-INTERCEPTED-CHARACTERS)
	     (KBD-INTERCEPT-CHARACTER CHAR)
	     (VALUES CHAR T))		;If returns, ignore the char and retry
	    (T CHAR))))

;;; This function knows what to do in response to each of the standard intercepted
;;; characters.  It is called by other functions besides KBD-DEFAULT-OUTPUT-FUNCTION
(DEFUN KBD-INTERCEPT-CHARACTER (CHAR)
  (SETQ INHIBIT-SCHEDULING-FLAG NIL)		;It was T in the IO-BUFFER-OUTPUT-FUNCTION
  (SELECTQ CHAR
    (#\ABORT
     (IF (NOT (AND (TYPEP TERMINAL-IO 'SHEET)	;Kludge to avoid being unable to abort
		   (SHEET-OUTPUT-HELD-P TERMINAL-IO)))
	 (FUNCALL TERMINAL-IO ':STRING-OUT "[Abort]"))
     (*THROW 'SYS:COMMAND-LEVEL NIL))
    (#\ABORT
     (IF (NOT (AND (TYPEP TERMINAL-IO 'SHEET)	;Kludge to avoid being unable to abort
		   (SHEET-OUTPUT-HELD-P TERMINAL-IO)))
	 (FUNCALL TERMINAL-IO ':STRING-OUT "[Abort all]"))
     (FUNCALL CURRENT-PROCESS ':RESET ':ALWAYS))
    (#\BREAK (BREAK BREAK))
    (#\BREAK (FUNCALL %ERROR-HANDLER-STACK-GROUP '(:BREAK))
     NIL)	;This NIL is here for a reason!
    (OTHERWISE (FERROR NIL "~:@C is not a standard intercepted character" CHAR))))

;;; This function is called, possibly in the keyboard process, when one of the
;;; standard asynchronous intercepted characters, of the sort that mungs over the
;;; process, is typed.  Scheduling is inhibited.
;;; This does the actual munging of the process in a separate process, in case
;;; it has to wait for the process' stack-group to get out of some weird state.
(DEFUN KBD-ASYNCHRONOUS-INTERCEPT-CHARACTER (CHAR &AUX P)
  (KBD-ESC-CLEAR NIL)  ;Forget chars typed before "CTRL-abort", even those inside window's iob
  (AND (SETQ P SELECTED-WINDOW)			;Find process to be hacked
       (SETQ P (FUNCALL P ':PROCESS))
       (SELECTQ CHAR
	 ((#\ABORT #\ABORT)
	  (PROCESS-RUN-FUNCTION '(:NAME "Abort" :PRIORITY 50.) P ':INTERRUPT
				#'KBD-INTERCEPT-CHARACTER (DPB 0 %%KBD-CONTROL CHAR)))
	 (#\BREAK
	  (PROCESS-RUN-FUNCTION '(:NAME "Break" :PRIORITY 40.) P ':INTERRUPT 'BREAK 'BREAK))
	 (#\BREAK
	  (PROCESS-RUN-FUNCTION '(:NAME "Break" :PRIORITY 40.)
				P ':INTERRUPT %ERROR-HANDLER-STACK-GROUP
				'(:BREAK))))))

(DEFVAR KBD-PROCESS)
(DEFUN INSTALL-MY-KEYBOARD ()
  (OR (BOUNDP 'KBD-PROCESS)
      (SETQ KBD-PROCESS (PROCESS-RUN-FUNCTION "Keyboard" 'KBD-PROCESS-MAIN-LOOP)))
  (SI:PROCESS-RESET-AND-ENABLE KBD-PROCESS))

(DEFUN KBD-GET-SOFTWARE-CHAR (&OPTIONAL (WHOSTATE "Keyboard"))
  "Returns the next char from the hardware converted to software codes.  This
is meant to be used only by things that run in the keyboard process, and not by
any user code."
  (DO ((CH)) (NIL)
    (PROCESS-WAIT WHOSTATE #'KBD-HARDWARE-CHAR-AVAILABLE)
    (AND (SETQ CH (KBD-CONVERT-TO-SOFTWARE-CHAR (KBD-GET-HARDWARE-CHAR)))
	 (RETURN CH))))

(DEFUN KBD-CHAR-TYPED-P (&AUX (BUFFER (KBD-GET-IO-BUFFER)))
  "Kludge to return T when a character has been typed.  First checks the selected window's
IO buffer, and if it is empty then checks the microcode's buffer.  This is useful for
programs which want to stop when a character is typed, but don't want to allow
interrupts and scheduling."
  (OR (AND BUFFER (NOT (IO-BUFFER-EMPTY-P BUFFER)))
      (KBD-HARDWARE-CHAR-AVAILABLE)))

(DEFUN KBD-CLEAR-IO-BUFFER ()
  "Clear the keyboard buffer and the hardware buffer"
  (IO-BUFFER-CLEAR KBD-IO-BUFFER)
  (DO () ((NOT (KBD-HARDWARE-CHAR-AVAILABLE)))
    ;; Call this to process shifts
    (KBD-CONVERT-TO-SOFTWARE-CHAR (KBD-GET-HARDWARE-CHAR))))

(DEFUN KBD-CLEAR-SELECTED-IO-BUFFER ()
  "Flush the selected io buffer"
  (SETQ SELECTED-IO-BUFFER NIL))

(DEFUN KBD-GET-IO-BUFFER ()
  "Returns the current IO buffer.  If there is no current buffer, the selected window
is interrogated.  If there is no selected window, or the window has no buffer, returns NIL."
  (COND ((NULL SELECTED-WINDOW)
	 ;; This shouldn't be necessary, but try not to lose too big
	 (KBD-CLEAR-SELECTED-IO-BUFFER))
	(SELECTED-IO-BUFFER SELECTED-IO-BUFFER)
	(T (PROG1 (SETQ SELECTED-IO-BUFFER (FUNCALL SELECTED-WINDOW ':IO-BUFFER))
		  (WHO-LINE-RUN-STATE-UPDATE)))))	;May have just switched processes

(DEFUN KBD-CALL (BUFFER)
  BUFFER					;Not used
  (IO-BUFFER-CLEAR KBD-IO-BUFFER)		;Forget chars typed before "call"
  (PROCESS-RUN-TEMPORARY-FUNCTION "Call" #'(LAMBDA (WINDOW)
					     (IF WINDOW
						 (FUNCALL WINDOW ':CALL)
						 (SETQ WINDOW (KBD-DEFAULT-CALL-WINDOW))
						 (FUNCALL WINDOW ':MOUSE-SELECT)))
				  SELECTED-WINDOW))

(DEFUN KBD-DEFAULT-CALL-WINDOW (&OPTIONAL (SCREEN DEFAULT-SCREEN) &AUX PREVIOUS-WINDOW)
  (IF (AND (SETQ PREVIOUS-WINDOW (AREF PREVIOUSLY-SELECTED-WINDOWS 0))
	   (EQ (FUNCALL PREVIOUS-WINDOW ':LISP-LISTENER-P) ':IDLE))
      ;; CALL should always get a Lisp Listener, but try to be smart about
      ;; the one that it really gets
      PREVIOUS-WINDOW
      (FUNCALL SCREEN ':IDLE-LISP-LISTENER)))

;Return the state of a key, T if it is depressed, NIL if it is not.
;This only works on new keyboards; on old keyboards it always returns NIL.
;A key is specified by either a number which is the ascii code of the
;key (the character you get when you type that key with no shifts),
;or a symbol which is the symbolic name of a shift key (see below).
(DEFUN KEY-STATE (KEY &AUX TEM)
  (KBD-PROCESS-MAIN-LOOP-INTERNAL)
  (COND ((NUMBERP KEY) (NOT (ZEROP (AREF SI:KBD-KEY-STATE-ARRAY KEY))))
	((SETQ TEM (ASSQ KEY '((:SHIFT 100) (:LEFT-SHIFT 0) (:RIGHT-SHIFT 40)
			       (:GREEK 101) (:LEFT-GREEK 1) (:RIGHT-GREEK 41)
			       (:TOP 102) (:LEFT-TOP 2) (:RIGHT-TOP 42)
			       (:CONTROL 104) (:LEFT-CONTROL 4) (:RIGHT-CONTROL 44)
			       (:META 105) (:LEFT-META 5) (:RIGHT-META 45)
			       (:SUPER 106) (:LEFT-SUPER 6) (:RIGHT-SUPER 46)
			       (:HYPER 107) (:LEFT-HYPER 7) (:RIGHT-HYPER 47)
			       (:CAPS-LOCK 3) (:ALT-LOCK 10) (:MODE-LOCK 11)
			       (:REPEAT 12))))
	 (BIT-TEST (LSH 1 (LOGAND (SETQ TEM (CADR TEM)) 37))
		   (COND ((< TEM 40) SI:KBD-LEFT-SHIFTS)
			 ((< TEM 100) SI:KBD-RIGHT-SHIFTS)
			 (T (LOGIOR SI:KBD-LEFT-SHIFTS SI:KBD-RIGHT-SHIFTS)))))
	(T (FERROR NIL "~S illegal key; must be character or symbol for shift key" KEY))))

;;; "Escape key"

; A list of elements (char function documentation . options).
; Typing [terminal] char activates this element.  If function is a list it is
; evaluated, otherwise it is a function to be applied to one argument, which
; is NIL or the numeric-arg typed by the user.  In either case it happens
; in a separate process.  documentation is a form to evaluate to get the
; documentation, a string or NIL to leave this key undocumented.
; Documentation can be a list of strings to go on separate lines.
; The following options in the CDDDR of the list are:
;    :TYPEAHEAD - copy the contents of the
;	software buffer into the currently selected IO-BUFFER.  This has the
;	effect of treating everything typed before the ESC as typeahead to
;	the currently selected window.  Useful for ESC commands that
;	change the selected window.  These commands should set KBD-ESC-TIME to NIL
;       as soon as they change the selected window, unless they complete quickly
;       (input should never be done with KBD-ESC-TIME non-NIL).
;    :KEYBOARD-PROCESS - run the function in the keyboard process instead of starting
;	a new process for it.

; Unknown or misspelled keywords are ignored.
(DEFVAR *ESCAPE-KEYS*
     '( (#\CLEAR KBD-ESC-CLEAR "Discard type-ahead" :KEYBOARD-PROCESS)
	(#\FORM (KBD-SCREEN-REDISPLAY)
		"Clear and redisplay all windows (Page = Clear Screen)")
	(#/A KBD-ESC-ARREST
	     "Arrest process in who-line (minus means unarrest)" :KEYBOARD-PROCESS)
	(#/B KBD-BURY
	     "Bury the selected window" :TYPEAHEAD)
	(#/C KBD-COMPLEMENT
	     '("Complement video black-on-white state"
	       "With an argument, complement the who-line documentation window")
	      :KEYBOARD-PROCESS)
	(#/D (SI:BUZZ-DOOR) (AND (SI:TECH-SQUARE-FLOOR-P 9) "Open the door"))
	(#/E (SI:CALL-ELEVATOR) (AND (OR (SI:TECH-SQUARE-FLOOR-P 8)
					 (SI:TECH-SQUARE-FLOOR-P 9))
				     "Call the elevator"))
	(#/F KBD-FINGER (FINGER-ARG-PROMPT)
			:TYPEAHEAD)
	(#/H (KBD-HOSTAT) "Show status of CHAOSnet hosts" :TYPEAHEAD)
	(#/M KBD-ESC-MORE "**MORE** enable (complement, or arg=1:on, 0 off)"
			  :KEYBOARD-PROCESS)
	(#/O KBD-OTHER-EXPOSED-WINDOW "Select another exposed window" :TYPEAHEAD)
	(#/Q KBD-ESC-Q
	     (AND *SCREEN-HARDCOPY-MODE*
		  (FORMAT NIL "Hardcopy the screen on the ~A" *SCREEN-HARDCOPY-MODE*)))
	(#/S KBD-SWITCH-WINDOWS
	 '("Select the most recently selected window.  With an argument, select the nth"
	   "previously selected window and rotate the top n windows.  (Default arg is 2)."
	   "With an arg of 1, rotate through all the windows.  With a negative arg rotate"
	   "in the other direction.  With an argument of 0, select a window that wants"
	   "attention, e.g. to report an error.")
	   :TYPEAHEAD)
	(#/T KBD-ESC-T
	 '("Control the selected window's notification properties."
	   "Toggle output notification, and make input the same as output."
	   "0 Turn both off; 1 turn both on; 2 output on, input off; 3 output off, input on."
	   "4 Let output proceed with with window deexposed, input on; 5 Same, input off."
	   "(You can also use the Attribute command in the Screen Editor.)"))
	(#/W KBD-ESC-W
	 '("Switch which process the wholine looks at.  Default is just to refresh it"
	   " 1 means selected-window's process, 2 means freeze on this process,"
	   " 3 means rotate among all processes, 4 means rotate other direction,"
	   " 0 gives a menu of all processes"))
	(#\HOLD-OUTPUT KBD-ESC-OUTPUT-HOLD "Expose window on which we have /"Output Hold/"")
	(#/? KBD-ESC-HELP NIL :TYPEAHEAD)
	(#\HELP KBD-ESC-HELP NIL :TYPEAHEAD)
	(NIL) ;Ones after here are "for wizards"
	(#\CALL (KBD-USE-COLD-LOAD-STREAM) "Get to cold-load stream" :TYPEAHEAD)
	(#/T KBD-CLEAR-TEMPORARY-WINDOWS "Flush temporary windows")
	(#\CLEAR KBD-CLEAR-LOCKS "Clear window-system locks")
	(#/G (BEEP) "Beep the beeper")))  ;Should this be flushed now?
	
(DEFUN KBD-ESC (&AUX CH ARG MINUS FCN ENT)
  "Handle ESC typed on keyboard"
  (LET-GLOBALLY ((WHO-LINE-PROCESS CURRENT-PROCESS))
    (WHO-LINE-RUN-STATE-UPDATE)  ;Necessary to make above take effect
    (DO () (NIL)
      (SETQ CH (CHAR-UPCASE (KBD-GET-SOFTWARE-CHAR "Terminal-")))
      (COND ((= CH #\ESC)					;Typed another ESC, reset
	     (SETQ ARG NIL MINUS NIL))
	    ((AND ( CH #/0) ( CH #/9))
	     (SETQ ARG (+ (* (OR ARG 0) 8.) (- CH #/0))))
	    ((= CH #/-) (SETQ MINUS T))
	    (T (RETURN)))))
  (WHO-LINE-RUN-STATE-UPDATE)	;Switch LAST-WHO-LINE-PROCESS back
  (AND MINUS (SETQ ARG (MINUS (OR ARG 1))))
  (COND ((SETQ ENT (ASSQ CH *ESCAPE-KEYS*))
	 (WITHOUT-INTERRUPTS
	   (COND ((MEMQ ':TYPEAHEAD (CDDDR ENT))
		  (KBD-GET-IO-BUFFER)
		  (KBD-SNARF-INPUT SELECTED-IO-BUFFER T)
		  (SETQ KBD-ESC-TIME (TIME)))))
	 (SETQ FCN (SECOND ENT))
	 (AND (LISTP FCN) (SETQ ARG FCN FCN #'EVAL))
	 (COND ((MEMQ ':KEYBOARD-PROCESS (CDDDR ENT))
		(FUNCALL FCN ARG)
		(SETQ KBD-ESC-TIME NIL))
	       (T (PROCESS-RUN-TEMPORARY-FUNCTION "KBD ESC"
						  #'(LAMBDA (FCN ARG)
						      (FUNCALL FCN ARG)
						      (SETQ KBD-ESC-TIME NIL))
						  FCN ARG))))
	((MEMQ (LDB %%KBD-CHAR CH) '(#\ABORT #\BREAK))	;Override :SUPER-IMAGE
	 (KBD-ASYNCHRONOUS-INTERCEPT-CHARACTER (DPB 1 %%KBD-CONTROL CH)))))

(DEFUN KBD-COMPLEMENT (ARG) ;esc C
  (IF ARG
      (FUNCALL WHO-LINE-DOCUMENTATION-WINDOW ':SET-REVERSE-VIDEO-P
	       (NOT (FUNCALL WHO-LINE-DOCUMENTATION-WINDOW ':REVERSE-VIDEO-P)))
      (COMPLEMENT-BOW-MODE)))

(DEFUN KBD-ESC-MORE (ARG) ;esc M
  (SETQ MORE-PROCESSING-GLOBAL-ENABLE
	(COND ((NULL ARG) (NOT MORE-PROCESSING-GLOBAL-ENABLE))
	      ((< ARG 1) NIL)			;ESC 0 M, ESC - M, MORE PROC OFF
	      (T T))))				;ESC 1 M, MORE PROC ON

(DEFUN KBD-ESC-CLEAR (TEM) ;esc clear-input
  (AND (SETQ TEM (KBD-GET-IO-BUFFER))
       (IO-BUFFER-CLEAR TEM))
  (IO-BUFFER-CLEAR KBD-IO-BUFFER))

(DEFUN KBD-ESC-ARREST (ARG &AUX P)
  (COND ((NULL (SETQ P LAST-WHO-LINE-PROCESS)) (BEEP))
	((AND ARG (MINUSP ARG))
	 (DOLIST (R (FUNCALL P ':ARREST-REASONS))
	   (FUNCALL P ':REVOKE-ARREST-REASON R)))
	(T (FUNCALL P ':ARREST-REASON ':USER))))

(DEFUN KBD-BURY (ARG) ;esc B
  ARG ;unused for now
  (COND (SELECTED-WINDOW
	 (FUNCALL (FUNCALL SELECTED-WINDOW ':ALIAS-FOR-SELECTED-WINDOWS) ':BURY)))
  (SETQ KBD-ESC-TIME NIL))

(DEFUN KBD-OTHER-EXPOSED-WINDOW (IGNORE)
  ;; ESC O selects the least recently-selected window that is exposed.
  ;; Thus repeated esc O cycles among all the selectable exposed windows 
  ;; on all the screens.  Real useful with split-screen!
  (DO ((I 0 (1+ I))
       (N (ARRAY-LENGTH PREVIOUSLY-SELECTED-WINDOWS))
       (TEM)
       (WINDOW NIL))
      (( I N)
       (IF WINDOW (FUNCALL WINDOW ':MOUSE-SELECT)
	   (BEEP)))
    (AND (SETQ TEM (AREF PREVIOUSLY-SELECTED-WINDOWS I))
	 (EQ (FUNCALL TEM ':STATUS) ':EXPOSED)
	 (NOT (NULL (FUNCALL TEM ':NAME-FOR-SELECTION)))
	 (SETQ WINDOW TEM))))

(DEFUN KBD-SWITCH-WINDOWS (ARG &AUX TEM) ;esc S
  ;; ESC n S rotates the n most recently selected windows, selecting the nth
  ;; ESC S = ESC 2 S
  ;; ESC 1 S selects the next most recent window but rotates all the windows
  ;; ESC -n S rotates the same set of windows in the other direction
  ;; ESC 0 S selects a window which has an error pending (or otherwise wants attention)
  (OR ARG (SETQ ARG 2))
  (COND ((= ARG 0) (COND ((SETQ TEM (FIND-INTERESTING-WINDOW))
			  (FUNCALL TEM ':MOUSE-SELECT)
			  (SETQ BACKGROUND-INTERESTING-WINDOWS
				(DELQ TEM BACKGROUND-INTERESTING-WINDOWS)))))
	(T (DELAYING-SCREEN-MANAGEMENT		;Inhibit auto-selection
	     (COND ((SETQ TEM SELECTED-WINDOW)	;Put current window on front of array
		    (FUNCALL TEM ':DESELECT NIL)
		    (AND (SETQ TEM (FUNCALL TEM ':IO-BUFFER))
			 (KBD-SNARF-INPUT TEM T))))
	     (WITHOUT-INTERRUPTS		;Get rid of any non-mouse-selectable ones
	       (DOTIMES (I (ARRAY-LENGTH PREVIOUSLY-SELECTED-WINDOWS))
		 (OR (SETQ TEM (AREF PREVIOUSLY-SELECTED-WINDOWS I)) (RETURN))
		 (COND ((NOT (FUNCALL TEM ':NAME-FOR-SELECTION))
			(REMOVE-FROM-PREVIOUSLY-SELECTED-WINDOWS TEM)
			(SETQ I (1- I)))))
	       (ROTATE-TOP-OF-ARRAY PREVIOUSLY-SELECTED-WINDOWS ARG))
	     (AND (SETQ TEM (AREF PREVIOUSLY-SELECTED-WINDOWS 0))
		  (FUNCALL TEM ':MOUSE-SELECT))))))

;This is like ZWEI:ROTATE-TOP-OF-LIST but for a NIL-padded array
;Rotate nth (1-origin!) element to the front of the array, rotating the
;part of the array before it.  With a negative arg rotate the same amount
;backwards.  With an arg of 1 rotate the whole array BACKWARDS, i.e. bring
;up the same element as with an arg of 2 but store the old front at the back.
;Zero arg is undefined, do nothing I guess.  Note that 2 and -2 do the same thing.
;Doesn't barf if N is too big.
(DEFUN ROTATE-TOP-OF-ARRAY (ARRAY N &AUX (LENGTH (ARRAY-LENGTH ARRAY)))
  (DO () ((ZEROP LENGTH))
    (AND (AREF ARRAY (1- LENGTH)) (RETURN))
    (SETQ LENGTH (1- LENGTH)))
  (AND (= (ABS N) 1) (SETQ N (* N -1 LENGTH)))
  (COND ((PLUSP N)
	 (SETQ N (MIN LENGTH N))
	 (DO ((I 0 (1+ I))
	      (NTH (AREF ARRAY (1- N)) OLD)
	      (OLD))
	     (( I N))
	   (SETQ OLD (AREF ARRAY I))
	   (ASET NTH ARRAY I)))
	((MINUSP N)
	 (SETQ N (MIN LENGTH (MINUS N)))
	 (DO ((I 1 (1+ I))
	      (FRONT (AREF ARRAY 0)))
	     (( I N) (ASET FRONT ARRAY (1- I)))
	   (ASET (AREF ARRAY I) ARRAY (1- I)))))
  ARRAY)

(DEFUN KBD-SCREEN-REDISPLAY ()
  "Like SCREEN-REDISPLAY, but goes over windows by hand, and never waits for a lock."
  (DOLIST (SCREEN ALL-THE-SCREENS)
    (COND ((SHEET-EXPOSED-P SCREEN)
	   (DOLIST (I (SHEET-EXPOSED-INFERIORS SCREEN))
	     (AND (SHEET-CAN-GET-LOCK I)
		  (FUNCALL I ':REFRESH)))
	   (FUNCALL SCREEN ':SCREEN-MANAGE))))
  (WHO-LINE-CLOBBERED))

(DEFUN KBD-CLEAR-LOCKS (IGNORE) ;esc c-clear
  (KBD-CLEAR-TEMPORARY-WINDOWS NIL)		;First flush any temporary windows
  (SHEET-CLEAR-LOCKS))

(DEFUN KBD-CLEAR-TEMPORARY-WINDOWS (IGNORE) ;esc c-T
  (MAP-OVER-SHEETS #'(LAMBDA (SHEET)
		       (AND (SHEET-TEMPORARY-P SHEET)
			    (SHEET-EXPOSED-P SHEET)
			    (SHEET-CAN-GET-LOCK SHEET)
			    (CATCH-ERROR (FUNCALL SHEET ':DEEXPOSE) NIL)))))

(DEFUN KBD-USE-COLD-LOAD-STREAM ()
  (FUNCALL COLD-LOAD-STREAM ':HOME-CURSOR)
  (FUNCALL COLD-LOAD-STREAM ':CLEAR-EOL)
  (*CATCH 'SYS:COMMAND-LEVEL
    (LET ((INHIBIT-SCHEDULING-FLAG NIL)		;NIL or BREAK would complain
	  (TERMINAL-IO COLD-LOAD-STREAM))
      (PRINT PACKAGE COLD-LOAD-STREAM)
      (BREAK COLD-LOAD-STREAM))))

(DEFUN KBD-ESC-OUTPUT-HOLD (IGNORE)
  (PROG (P W LOCKED ANS)
    (COND ((AND (SETQ P LAST-WHO-LINE-PROCESS)
		(MEMBER (PROCESS-WHOSTATE P) '("Output Hold" "Lock"))
		(TYPEP (SETQ W (CAR (PROCESS-WAIT-ARGUMENT-LIST P))) 'SHEET)
		(SHEET-OUTPUT-HELD-P W))
	   ;; Bludgeon our way past any deadlocks, e.g. due to the process P holding
	   ;; the lock on the window we are trying to expose, or on something we need
	   ;; to de-expose in order to expose it.  This code probably doesn't do a good
	   ;; enough job explaining what is going on to the user.
	   (COND ((AND (LISTP (SHEET-LOCK W))	;Only temp-locked?
		       (ZEROP (SHEET-LOCK-COUNT W))
		       (LOOP FOR TW IN (SHEET-LOCK W)
			     ALWAYS (SHEET-CAN-GET-LOCK TW)))
		  (SHEET-FREE-TEMPORARY-LOCKS W))
		 ((OR (NOT (SHEET-CAN-GET-LOCK (SETQ LOCKED W)))
		      (AND (SHEET-SUPERIOR W)
			   (LOOP FOR I IN (SHEET-EXPOSED-INFERIORS (SHEET-SUPERIOR W))
				 THEREIS (AND (SHEET-OVERLAPS-SHEET-P W I)
					      (NOT (SHEET-CAN-GET-LOCK (SETQ LOCKED I)))))))
		  (FUNCALL COLD-LOAD-STREAM ':HOME-CURSOR)
		  (SETQ ANS (LET ((QUERY-IO COLD-LOAD-STREAM))
			      (FQUERY '(:CHOICES (((T "Yes.") #/Y #\SP #/T)
						  ((NIL "No.") #/N #\RUBOUT)
						  ((EH "To error-handler.") #/E))
					:BEEP T)
				      "Cannot expose ~S because~@
				       ~:[~S~;~*it~] is locked by ~S.~@
				       Forcibly unlock all window-system locks? "
				      W (EQ W LOCKED) LOCKED (SHEET-LOCK LOCKED))))
		  (COND ((EQ ANS 'EH)
			 (SETQ EH:ERROR-HANDLER-IO COLD-LOAD-STREAM)
			 (FUNCALL P ':INTERRUPT %ERROR-HANDLER-STACK-GROUP '(:BREAK))
			 (RETURN NIL))		;Don't try to expose
			(ANS (SHEET-CLEAR-LOCKS))))
		 ((AND (SHEET-EXPOSED-P W)	;This can happen, I don't know how
		       (NOT (SHEET-LOCK W)))
		  (FUNCALL COLD-LOAD-STREAM ':HOME-CURSOR)
		  (IF (LET ((QUERY-IO COLD-LOAD-STREAM))
			(FQUERY '(:BEEP T)
				"~S is output-held for no apparent reason.~@
				 If you know the circumstances that led to this, please~@
				 mail in a bug report describing them.  ~
				 Do you want to forcibly clear output-hold? "
				W))
		      (SETF (SHEET-OUTPUT-HOLD-FLAG W) 0))))
	   (FUNCALL W ':EXPOSE))
	  ((BEEP)))))

(DEFINE-SITE-VARIABLE *FINGER-ARG-ALIST* :ESC-F-ARG-ALIST)

(DEFUN KBD-FINGER (ARG &AUX MODE HOSTS)
  (USING-RESOURCE (WINDOW POP-UP-FINGER-WINDOW)
    (SETF (SHEET-TRUNCATE-LINE-OUT-FLAG WINDOW) 1)
    (SETQ MODE (OR (CDR (ASSQ ARG *FINGER-ARG-ALIST*))
		   (CDR (ASSQ 'T *FINGER-ARG-ALIST*))
		   ':LOGIN)
	  HOSTS (COND ((MEMQ MODE '(:LOGIN :ASSOCIATED))
		       (LIST (IF (EQ MODE ':LOGIN)
				 FS:USER-LOGIN-MACHINE
				 SI:ASSOCIATED-MACHINE)))
		      (T MODE)))
    (IF (LISTP HOSTS)
	(SETQ HOSTS (MAPCAR #'(LAMBDA (X) (STRING (SI:PARSE-HOST X))) HOSTS)))
    (FUNCALL WINDOW ':SET-LABEL
	     (IF (EQ MODE ':READ) "Finger"
		 (WITH-OUTPUT-TO-STRING (STREAM)
		   (FUNCALL STREAM ':STRING-OUT "Who's on ")
		   (IF (EQ HOSTS ':LISP-MACHINES)
		       (FUNCALL STREAM ':STRING-OUT "Lisp Machines")
		       (LOOP FOR HOST IN HOSTS
			     WITH AND-P = NIL
			     DO (IF AND-P (FUNCALL STREAM ':STRING-OUT " and ")
					  (SETQ AND-P T))
			     DO (FUNCALL STREAM ':STRING-OUT HOST))))))
    (FUNCALL WINDOW ':SET-PROCESS CURRENT-PROCESS)
    (WINDOW-CALL (WINDOW :DEACTIVATE)
      (LET ((TERMINAL-IO WINDOW))	;In case of [Abort] printout and the like
	(SETQ KBD-ESC-TIME NIL)	;Window configuration stable now, let kbd process proceed
	(COND ((EQ HOSTS ':LISP-MACHINES)
	       (CHAOS:FINGER-ALL-LMS WINDOW T))
	      ((EQ HOSTS ':READ)
	       (FORMAT WINDOW
		       "~&Finger (type NAME@HOST or just @HOST, followed by Return):~%")
	       (CHAOS:FINGER (READLINE WINDOW) WINDOW))
	      (T
	       (LOOP FOR HOSTS ON HOSTS
		     WITH FIRST-P = T
		     DO (IF FIRST-P (SETQ FIRST-P NIL) (TERPRI WINDOW))
		     DO (CHAOS:FINGER (STRING-APPEND #/@ (CAR HOSTS)) WINDOW))))
	(FORMAT WINDOW "~&~%Type a space to flush: ")
	(FUNCALL WINDOW ':TYI)))))

(DEFUN FINGER-ARG-PROMPT ()
  (WITH-OUTPUT-TO-STRING (STREAM)
    (FUNCALL STREAM ':STRING-OUT "Finger (")
    (LOOP FOR (ARG . VAL) IN *FINGER-ARG-ALIST*
	  WITH ARG-PRINTED = NIL AND COMMA-P = NIL
	  DO (IF COMMA-P (FUNCALL STREAM ':STRING-OUT ", ") (SETQ COMMA-P T))
	  WHEN ARG
	  DO (COND ((NOT ARG-PRINTED)
		    (FUNCALL STREAM ':STRING-OUT "or arg=")
		    (SETQ ARG-PRINTED T)))
	     (PRIN1-THEN-SPACE ARG STREAM)
	  DO (IF (SYMBOLP VAL)
		 (FUNCALL STREAM ':STRING-OUT (SELECTQ VAL
						(:LOGIN
						 (SI:HOST-SHORT-NAME FS:USER-LOGIN-MACHINE))
						(:ASSOCIATED
						 (SI:HOST-SHORT-NAME SI:ASSOCIATED-MACHINE))
						(:LISP-MACHINES
						 "Lisp machines")
						(:READ
						 "ask")))
		 (LOOP FOR HOST IN VAL
		       WITH PLUS-P = NIL
		       DO (IF PLUS-P (FUNCALL STREAM ':TYO #/+) (SETQ PLUS-P T))
		          (FUNCALL STREAM ':STRING-OUT (SI:HOST-SHORT-NAME HOST)))))
    (FUNCALL STREAM ':STRING-OUT ")")))

(DEFUN KBD-HOSTAT ()
  (USING-RESOURCE (WINDOW POP-UP-FINGER-WINDOW)
    (SETF (SHEET-TRUNCATE-LINE-OUT-FLAG WINDOW) 1)
    (FUNCALL WINDOW ':SET-LABEL "Hostat")
    (FUNCALL WINDOW ':SET-PROCESS CURRENT-PROCESS)
    (WINDOW-CALL (WINDOW :DEACTIVATE)
      (LET ((TERMINAL-IO WINDOW))
	(SETQ KBD-ESC-TIME NIL)			;Window configuration stable.
	(HOSTAT)
	(FORMAT WINDOW "~&Type a space to flush: ")
	(FUNCALL WINDOW ':TYI)))))

(DEFUN KBD-ESC-T (ARG)
  "Control the selected window's notification properties.
Toggle output notification and set input notification to the same thing.
 0 Turn off output and input notification.
 1 Turn on output and input notification.
 2 Turn output notification on and input notification off.
 3 Turn output notification off and input notification on.
 4 Let output proceed with window deexposed and turn input notification on.
 5 Let output proceed with window deexposed and turn input notification off."
  (COND ((NOT (OR (NULL ARG) ( ARG 5)))
	 (TV:BEEP))
	((NOT (NULL SELECTED-WINDOW))				     
	 (LET ((CURRENT-OUT-ACTION (FUNCALL SELECTED-WINDOW ':DEEXPOSED-TYPEOUT-ACTION)))
	   (FUNCALL SELECTED-WINDOW ':SET-DEEXPOSED-TYPEOUT-ACTION
		    (COND ((OR (MEMQ ARG '(0 3))
			       (AND (NULL ARG)
				    (NOT (EQ CURRENT-OUT-ACTION ':NORMAL))))
			   ':NORMAL)
			  ((OR (MEMQ ARG '(1 2))
			       (AND (NULL ARG)
				    (NOT (EQ CURRENT-OUT-ACTION ':NOTIFY))))
			   ':NOTIFY)
			  ((MEMQ ARG '(4 5))
			   ':PERMIT)))
	   (FUNCALL SELECTED-WINDOW ':SET-DEEXPOSED-TYPEIN-ACTION
		    (COND ((NULL ARG) (IF (EQ CURRENT-OUT-ACTION ':NORMAL) ':NOTIFY ':NORMAL))
			  ((MEMQ ARG '(0 2 5)) ':NORMAL)
			  (T ':NOTIFY)))))
	(T (TV:BEEP))))

(DEFUN KBD-ESC-W (ARG &AUX PROC)
  (SETQ PROC LAST-WHO-LINE-PROCESS)
  (SELECTQ ARG
    (NIL (FUNCALL WHO-LINE-SCREEN ':REFRESH))
    (0 (SETQ WHO-LINE-PROCESS
	     (LET ((ALIST (MAPCAR #'(LAMBDA (P) (CONS (PROCESS-NAME P) P)) ALL-PROCESSES)))
	       (MENU-CHOOSE ALIST "Who-line process:" '(:MOUSE) (RASSOC PROC ALIST)))))
    (1 (SETQ WHO-LINE-PROCESS NIL))
    (2 (SETQ WHO-LINE-PROCESS PROC))
    (3 (SETQ WHO-LINE-PROCESS (DO ((L ALL-PROCESSES (CDR L)))
				  ((NULL L) (CAR ALL-PROCESSES))
				(AND (EQ (CAR L) PROC)
				     (RETURN (OR (CADR L) (CAR ALL-PROCESSES)))))))
    (4 (SETQ WHO-LINE-PROCESS (OR (DO ((L ALL-PROCESSES (CDR L))
				       (OL NIL L))
				      ((NULL L) NIL)
				    (AND (EQ (CAR L) PROC)
					 (RETURN (CAR OL))))
				  (CAR (LAST ALL-PROCESSES))))))
  (WHO-LINE-RUN-STATE-UPDATE)
  (WHO-LINE-UPDATE))

(DEFINE-SITE-VARIABLE *SCREEN-HARDCOPY-MODE* :HARDCOPY-SCREEN-MODE)

(DEFRESOURCE HARDCOPY-BIT-ARRAY ()
  :CONSTRUCTOR (MAKE-ARRAY '(1400 1730) ':TYPE 'ART-1B)	;Big enough for
  :INITIAL-COPIES 0)				; for (SET-TV-SPEED 60.)

;;; ESC 0 Q copies without wholine, ESC 1 Q copies just selected window.
(DEFUN KBD-ESC-Q (ARG &AUX FUN)
  (IF (AND *SCREEN-HARDCOPY-MODE*
	   (SETQ FUN (GET *SCREEN-HARDCOPY-MODE* 'KBD-ESC-Q-FUNCTION)))
      (USING-RESOURCE (ARRAY HARDCOPY-BIT-ARRAY)
	(MULTIPLE-VALUE-BIND (NIL WIDTH HEIGHT)
	    (SNAPSHOT-SCREEN (SELECTQ ARG
			       (1 SELECTED-WINDOW)
			       (0 DEFAULT-SCREEN)
			       (OTHERWISE (MAIN-SCREEN-AND-WHO-LINE)))
			     ARRAY)
	  (BEEP)
	  (FUNCALL FUN ARRAY WIDTH HEIGHT)))
      (TV:NOTIFY NIL "I don't know how to hardcopy the screen at your site")))

(DEFUN SNAPSHOT-SCREEN (FROM-ARRAY TO-ARRAY &OPTIONAL WIDTH HEIGHT)
  (WITHOUT-INTERRUPTS
    (COND ((ARRAYP FROM-ARRAY)
	   (OR WIDTH (SETQ WIDTH (ARRAY-DIMENSION-N 1 FROM-ARRAY)))
	   (OR HEIGHT (SETQ HEIGHT (ARRAY-DIMENSION-N 2 FROM-ARRAY))))
	  (T
	   (OR WIDTH (SETQ WIDTH (SHEET-WIDTH FROM-ARRAY)))
	   (OR HEIGHT (SETQ HEIGHT (SHEET-HEIGHT FROM-ARRAY)))
	   (SETQ FROM-ARRAY (OR (SHEET-SCREEN-ARRAY FROM-ARRAY)
				(FERROR NIL "Window ~S does not have an array" FROM-ARRAY)))))
    (WHO-LINE-UPDATE)
    (BITBLT ALU-SETZ (ARRAY-DIMENSION-N 1 TO-ARRAY) (ARRAY-DIMENSION-N 2 TO-ARRAY)
	    TO-ARRAY 0 0 TO-ARRAY 0 0)
    (BITBLT ALU-SETA WIDTH HEIGHT FROM-ARRAY 0 0 TO-ARRAY 0 0))
  (VALUES TO-ARRAY WIDTH HEIGHT))

(DEFUN KBD-ESC-HELP (IGNORE &AUX DOC (INDENT 15.))
  (USING-RESOURCE (WINDOW POP-UP-FINGER-WINDOW)
    (SETF (SHEET-TRUNCATE-LINE-OUT-FLAG WINDOW) 0)
    (FUNCALL WINDOW ':SET-LABEL "Keyboard documentation")
    (WINDOW-MOUSE-CALL (WINDOW :DEACTIVATE)
      (SETQ KBD-ESC-TIME NIL)
      (FORMAT WINDOW "~25TType Terminal//Escape followed by:

Rubout~VTDo nothing. (Use this if you typed Terminal by accident and want to cancel it.)
0-9, -~VTNumeric argument to following command~%" INDENT INDENT)
      (DOLIST (X *ESCAPE-KEYS*)
	(COND ((NULL (CAR X))
	       (SETQ INDENT 20.)
	       (FORMAT WINDOW "~%~5XThese are for wizards:~2%"))
	      ((SETQ DOC (EVAL (CADDR X)))
	       (FORMAT WINDOW "~:C~VT~A~%" (CAR X) INDENT
		       (IF (ATOM DOC) DOC (CAR DOC)))
	       (OR (ATOM DOC) (DOLIST (LINE (CDR DOC))
				(FORMAT WINDOW "~VT~A~%" INDENT LINE))))))
      (FORMAT WINDOW "~3%~25TNew-keyboard function keys:

Abort		Throw to command level		Break		Get read-eval-print loop
Control-Abort	To command level immediately	Control-Break	BREAK immediately
Meta-Abort	Throw out of all levels		Meta-Break	Get to error-handler
C-M-Abort	Out of all levels immediately	C-M-Break	Error-handler immediately
Macro		Keyboard macros (ed)		Stop-Output	(not used)
Terminal	The above commands		Resume		Continue from break//error
System		Select a Program		Call		Stop program, get a Lisp
Network		Supdup//Telnet commands		Status		(not used)
Quote		(not used)			Delete		(not used)
Overstrike	/"backspace/"			End		Terminate input
Clear-Input	Forget typein			Help		Print documentation
Clear-Screen	Refresh screen			Return		Carriage return
Hold-Output	(not used)			Line		Next line and indent (ed)
")
      (FORMAT WINDOW "~%Type a space to flush: ")
      (FUNCALL WINDOW ':TYI))))

;Keys you can type after SYSTEM.
;Each element is a list (character flavor documentation-string create-flavor)
;If create-p is NIL if can only select existing ones.  create-p is list of
;form to evaluate to create one.  If create-flavor is T, window is created from flavor,
;any other symbol is the name of the flavor.
;In place of the flavor you may also have the window itself.
(DEFVAR *SYSTEM-KEYS*
     '(	(#/E ZWEI:ZMACS-FRAME "Editor" T)
	(#/I INSPECT-FRAME "Inspector" (PROGN (SETQ KBD-ESC-TIME NIL) (TV:INSPECT)))
	(#/L LISTENER-MIXIN "Lisp" LISP-LISTENER)
	(#/P PEEK "Peek" T)
	;(#/R EH:ERROR-HANDLER-FRAME "Window error-handler" NIL)  ;not a program!
	(#/S (PROGN SUPDUP:SUPDUP-FLAVOR) "Supdup" T)
	(#/T SUPDUP:TELNET "Telnet" T) ))

(DEFUN KBD-SYS (&AUX CH)
  (LET-GLOBALLY ((WHO-LINE-PROCESS CURRENT-PROCESS))
    (WHO-LINE-RUN-STATE-UPDATE)  ;Necessary to make above take effect
    (SETQ CH (CHAR-UPCASE (KBD-GET-SOFTWARE-CHAR "System-"))))
  (WHO-LINE-RUN-STATE-UPDATE)	;Switch LAST-WHO-LINE-PROCESS back
  ;; Anything typed before the System belongs to the currently selected window
  ;; Anything typed after this belongs to the new window we are going to get to.
  (WITHOUT-INTERRUPTS
    (AND (KBD-GET-IO-BUFFER)
	 (KBD-SNARF-INPUT SELECTED-IO-BUFFER T)))
  (SETQ KBD-ESC-TIME (TIME))
  (PROCESS-RUN-TEMPORARY-FUNCTION "KBD SYS" #'KBD-SYS-1 CH))

(DEFUN KBD-SYS-1 (CH &AUX E W SW MAKENEW FLAVOR-OR-WINDOW)
  (SETQ MAKENEW (LDB-TEST %%KBD-CONTROL CH)
	CH (LDB %%KBD-CHAR CH))
  (COND ((OR (= CH #/?) (= CH #\HELP))
	 (USING-RESOURCE (WINDOW POP-UP-FINGER-WINDOW)
	   (SETF (SHEET-TRUNCATE-LINE-OUT-FLAG WINDOW) 0)
	   (FUNCALL WINDOW ':SET-LABEL "Keyboard system commands")
	   (WINDOW-CALL (WINDOW :DEACTIVATE)
	     (FORMAT WINDOW
		     "Type ~:@C followed by one of these letters to select the corresponding ~
		    program:~2%~:{~C~8T~*~A~%~}"
		     #\SYSTEM *SYSTEM-KEYS*)
	     (FORMAT
	       WINDOW
	       "~%Hold down control to create a new one.~@
                Type Rubout after System to do nothing (if you typed System by accident).~%~@
		Type a space to flush: ")
	     (SETQ KBD-ESC-TIME NIL)		;Let kbd process proceed before we TYI.
	     (FUNCALL WINDOW ':TYI))))
	((SETQ E (ASSQ CH *SYSTEM-KEYS*))
	 ;; Find the most recently selected window of the desired type.
	 ;; If it is the same type as the selected window, make that the
	 ;; least recently selected so as to achieve the cycling-through effect.
	 ;; Otherwise the currently selected window becomes the most recently
	 ;; selected as usual, and esc S will return to it.
	 ;; In any case, we must fake out :MOUSE-SELECT's typeahead action since
	 ;; that has already been properly taken care of and we don't want to snarf
	 ;; any characters already typed after the [SYSTEM] command.
	 (SETQ FLAVOR-OR-WINDOW
	       (COND ((LISTP (SECOND E)) (EVAL (SECOND E)))
		     (T (SECOND E))))
	 (DELAYING-SCREEN-MANAGEMENT	;Inhibit auto selection
	   (COND ((= (%DATA-TYPE FLAVOR-OR-WINDOW) DTP-INSTANCE)
		  ;; If the *SYSTEM-KEYS* list has a specific window indicated, use that.
		  (AND (SETQ SW SELECTED-WINDOW) (FUNCALL SW ':DESELECT NIL))
		  (FUNCALL FLAVOR-OR-WINDOW ':MOUSE-SELECT))
		 ((AND (NOT MAKENEW)
		       (SETQ W (FIND-WINDOW-OF-FLAVOR FLAVOR-OR-WINDOW)))
		  ;; Cycle through other windows of this flavor.
		  (COND ((SETQ SW SELECTED-WINDOW)
			 (FUNCALL SW ':DESELECT NIL)
			 (AND (TYPEP SW FLAVOR-OR-WINDOW)
			      (ADD-TO-PREVIOUSLY-SELECTED-WINDOWS SW T))))
		  (FUNCALL W ':MOUSE-SELECT))
		 ((AND (NOT MAKENEW)
		       (SETQ SW SELECTED-WINDOW)
		       (TYPEP (FUNCALL SW ':ALIAS-FOR-SELECTED-WINDOWS) FLAVOR-OR-WINDOW))
		  ;; There is only one window of this flavor, and this is it.
		  (BEEP))
		 ((NULL (FOURTH E)) (BEEP))	;Cannot create
		 ((NLISTP (FOURTH E))
		  ;; Create a new window of this flavor.
		  (AND (SETQ SW SELECTED-WINDOW) (FUNCALL SW ':DESELECT NIL))
		  (FUNCALL (MAKE-WINDOW (IF (EQ (FOURTH E) T) FLAVOR-OR-WINDOW (FOURTH E)))
			   ':MOUSE-SELECT))
		 (T (EVAL (FOURTH E))))))
	(( CH #\RUBOUT) (BEEP)))
  (SETQ KBD-ESC-TIME NIL))

(DEFUN FIND-WINDOW-OF-FLAVOR (FLAVOR)
  ;; Only looks at PREVIOUSLY-SELECTED-WINDOWS, but that should have all the ones
  ;; of any interest.
  (DOTIMES (I (ARRAY-LENGTH PREVIOUSLY-SELECTED-WINDOWS))
    (LET ((W (AREF PREVIOUSLY-SELECTED-WINDOWS I)))
      (AND W (TYPEP W FLAVOR) (FUNCALL W ':NAME-FOR-SELECTION)
	   (RETURN W)))))

;;; Notification (call side)

(DEFVAR NOTIFICATION-HISTORY NIL)	;Each entry is list of time and string
(ADD-INITIALIZATION "Forget old notifications"
		    '(SETQ NOTIFICATION-HISTORY NIL)
		    '(:BEFORE-COLD))

;Reprint notifications, newest first
(DEFUN PRINT-NOTIFICATIONS ()
  (FORMAT T "~&~:[No notifications.~;Notifications, most recent first:~]~%"
	    NOTIFICATION-HISTORY)
  (DOLIST (N NOTIFICATION-HISTORY)
    (TIME:PRINT-BRIEF-UNIVERSAL-TIME (FIRST N))
    (FORMAT T " ~A~%" (SECOND N))))

(DEFUN NOTIFY (WINDOW-OF-INTEREST FORMAT-CONTROL &REST FORMAT-ARGS)
  "Notify the user with an unsolicited message.
The message is generated from FORMAT-CONTROL and FORMAT-ARGS.
If WINDOW-OF-INTEREST is non-NIL, it is a window to be made available to
Terminal-0-S and maybe another way depending on who prints the notification"
  (LEXPR-FUNCALL #'CAREFUL-NOTIFY WINDOW-OF-INTEREST NIL FORMAT-CONTROL FORMAT-ARGS))

(DEFUN CAREFUL-NOTIFY (WINDOW-OF-INTEREST CAREFUL-P FORMAT-CONTROL &REST FORMAT-ARGS)
  "Like NOTIFY but will not hang up waiting for locks if CAREFUL-P is T.
If locks are locked or there is no selected-window, returns NIL.  If succeeds
in printing the notification, returns T."
  (LET ((TIME (TIME:GET-UNIVERSAL-TIME))
	(MESSAGE (LEXPR-FUNCALL #'FORMAT NIL FORMAT-CONTROL FORMAT-ARGS)))
    (PUSH (LIST TIME MESSAGE) NOTIFICATION-HISTORY)
    (COND (WINDOW-OF-INTEREST			;Make this window "interesting"
	   (WITHOUT-INTERRUPTS
	     (OR (MEMQ WINDOW-OF-INTEREST BACKGROUND-INTERESTING-WINDOWS)
		 (PUSH WINDOW-OF-INTEREST BACKGROUND-INTERESTING-WINDOWS)))
	   (IF (SHEET-CAN-GET-LOCK WINDOW-OF-INTEREST)	   ;Try to make available to sys menu
	       (FUNCALL WINDOW-OF-INTEREST ':ACTIVATE))))  ;but don't bother if locked
    ;Get a selected-window to which to send the :print-notification message
    (IF (NOT CAREFUL-P)
	;; What this piece of hair is all about is that we don't want to pick a window
	;; to print the notification on and then have that window deexposed out from
	;; under us, causing us to hang forever.  So we lock the window while printing
	;; the notification, which is assumed is going to be on either the window itself
	;; or one of its direct or indirect inferiors.  Any windows which don't print
	;; their notification this way must spawn a separate process to do the printing.
	(LOOP AS INHIBIT-SCHEDULING-FLAG = T AS SW = SELECTED-WINDOW
	      WHEN (AND (NOT (NULL SW))
			(SHEET-CAN-GET-LOCK SW))
	        RETURN (LOCK-SHEET (SW)
			 (SETQ INHIBIT-SCHEDULING-FLAG NIL)
			 (FUNCALL SW ':PRINT-NOTIFICATION TIME MESSAGE WINDOW-OF-INTEREST))
	      DO (SETQ INHIBIT-SCHEDULING-FLAG NIL)
	         (PROCESS-WAIT "A selected window"
			       #'(LAMBDA (SW) (OR (NEQ SELECTED-WINDOW SW)
						  (AND SW (SHEET-CAN-GET-LOCK SW))))
			       SW))
	;; In this case, we simply want to punt if we don't seem to be able to acquire
	;; the necessary locks.  This doesn't use WITHOUT-INTERRUPTS and has a timing
	;; window which I don't think it is possible to close.
	(LET ((SW SELECTED-WINDOW))
	  (COND ((OR (NULL SW)			;No one in charge
		     (SHEET-OUTPUT-HELD-P SW)	;Guy in charge locked or broken
		     (NOT (SHEET-CAN-GET-LOCK	;Anything locked, even by this process,
			    (SHEET-GET-SCREEN SW) T)))	; that would hang Terminal-0-S
		 NIL)				;Lose, don't try to notify
		(T				;Win, go ahead
		 (FUNCALL SW ':PRINT-NOTIFICATION TIME MESSAGE WINDOW-OF-INTEREST)
		 T))))))

;;; Background stream

;(DEFVAR DEFAULT-BACKGROUND-STREAM 'BACKGROUND-STREAM)  ;in COLD
(DEFVAR PROCESS-IS-IN-ERROR NIL)
(DEFVAR BACKGROUND-INTERESTING-WINDOWS NIL)

(DEFFLAVOR BACKGROUND-LISP-INTERACTOR () (LISP-INTERACTOR)
  (:DEFAULT-INIT-PLIST :DEEXPOSED-TYPEOUT-ACTION ':NOTIFY
		       :DEEXPOSED-TYPEIN-ACTION ':NOTIFY))

(DEFMETHOD (BACKGROUND-LISP-INTERACTOR :BEFORE :INIT) (PLIST)
  (PUTPROP PLIST T ':SAVE-BITS))

(DEFMETHOD (BACKGROUND-LISP-INTERACTOR :SET-PROCESS) (NP)
  (SETF (IO-BUFFER-LAST-OUTPUT-PROCESS IO-BUFFER) NP)
  (SETQ PROCESS NP))

(DEFMETHOD (BACKGROUND-LISP-INTERACTOR :AFTER :SELECT) (&REST IGNORE)
  (WITHOUT-INTERRUPTS
    (SETQ BACKGROUND-INTERESTING-WINDOWS (DELQ SELF BACKGROUND-INTERESTING-WINDOWS))))

(DEFMETHOD (BACKGROUND-LISP-INTERACTOR :AFTER :DEACTIVATE) (&REST IGNORE)
  (WITHOUT-INTERRUPTS
    (SETQ BACKGROUND-INTERESTING-WINDOWS (DELQ SELF BACKGROUND-INTERESTING-WINDOWS))))

(DEFMETHOD (BACKGROUND-LISP-INTERACTOR :WAIT-UNTIL-SEEN) ()
  ;; If we have typed out since we were selected last, then wait until we get seen
  (COND ((MEMQ SELF BACKGROUND-INTERESTING-WINDOWS)
	 (PROCESS-WAIT "Seen" #'(LAMBDA (S)
				  (NOT (MEMQ S BACKGROUND-INTERESTING-WINDOWS)))
		       SELF)
	 ;; Then wait until we are deselected
	 (PROCESS-WAIT "No Longer Seen" #'(LAMBDA (S) (NEQ S SELECTED-WINDOW)) SELF))))

(DEFVAR BACKGROUND-STREAM-WHICH-OPERATIONS)

(DEFUN BACKGROUND-STREAM (OP &REST ARGS)
  "This function is defaultly used as TERMINAL-IO for all processes.  If it gets called
at all, it turns TERMINAL-IO into a lisp listener window, and notifies the user that
the process wants the terminal."
  (IF (EQ TERMINAL-IO DEFAULT-BACKGROUND-STREAM)
      (SELECTQ OP
	(:WHICH-OPERATIONS 
	  ;; Get the which-operations once, but after the flavor has been compiled
	  (OR (BOUNDP 'BACKGROUND-STREAM-WHICH-OPERATIONS)
	      (USING-RESOURCE (WINDOW BACKGROUND-LISP-INTERACTORS)
		(LET ((WO (FUNCALL WINDOW ':WHICH-OPERATIONS)))
		  (SETQ BACKGROUND-STREAM-WHICH-OPERATIONS
			(IF (MEMQ ':BEEP WO) WO (CONS ':BEEP WO))))))
	  BACKGROUND-STREAM-WHICH-OPERATIONS)
	  ;; If the stream hasn't changed since the process was started, do default action
	(:BEEP
	 (LET ((W (WITHOUT-INTERRUPTS
		    (IF SELECTED-WINDOW
			(SHEET-GET-SCREEN SELECTED-WINDOW)
			DEFAULT-SCREEN))))
	   (LEXPR-FUNCALL W ':BEEP ARGS)))
	(OTHERWISE
	  (SETQ TERMINAL-IO (ALLOCATE-RESOURCE 'BACKGROUND-LISP-INTERACTORS))
	  (SHEET-FORCE-ACCESS (TERMINAL-IO :NO-PREPARE)
	    (FUNCALL TERMINAL-IO ':SET-LABEL (STRING-APPEND (PROCESS-NAME CURRENT-PROCESS)
							    " Background Stream"))
	    (FUNCALL TERMINAL-IO ':SET-PROCESS CURRENT-PROCESS)
	    (FUNCALL TERMINAL-IO ':CLEAR-SCREEN))
	  (FUNCALL TERMINAL-IO ':ACTIVATE)
	  (LEXPR-FUNCALL TERMINAL-IO OP ARGS)))
      (SETQ TERMINAL-IO DEFAULT-BACKGROUND-STREAM)
      (LEXPR-FUNCALL TERMINAL-IO OP ARGS)))

(DEFUN FIND-PROCESS-IN-ERROR (&AUX WINDOW SG)
  (WITHOUT-INTERRUPTS
    (DOLIST (P ACTIVE-PROCESSES)
      (AND (SETQ P (CAR P))
	   (TYPEP (SETQ SG (PROCESS-STACK-GROUP P)) ':STACK-GROUP)
	   (SETQ WINDOW (SYMEVAL-IN-STACK-GROUP 'PROCESS-IS-IN-ERROR SG))
	   (RETURN P WINDOW)))))

(DEFUN FIND-INTERESTING-WINDOW ()
  (MULTIPLE-VALUE-BIND (NIL W)
      (FIND-PROCESS-IN-ERROR)
    (OR W (CAR BACKGROUND-INTERESTING-WINDOWS))))

;;; More or less innocuous functions from the old window system that are called all over the
;;; place.
(DEFUN KBD-TYI (&REST IGNORE) (FUNCALL TERMINAL-IO ':TYI))

(DEFUN KBD-TYI-NO-HANG (&REST IGNORE) (FUNCALL TERMINAL-IO ':TYI-NO-HANG))

(DEFUN KBD-CHAR-AVAILABLE (&REST IGNORE) (FUNCALL TERMINAL-IO ':LISTEN))
