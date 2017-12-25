;;; Mouse commands for ZWEI -*-Mode:LISP;Package:ZWEI-*-
;;; ** (c) Copyright 1980 Massachusetts Institute of Technology **
;;; Note: some screen system primitives live in SCREEN

;;; Proposed mouse command table for ZWEI windows:
;;;  [1] Mark some characters.
;;;  [11] No region -> Select window, Region -> You are moving it.
;;;  [2] Mark some things.
;;;  [22] Kill, Yank, Yank-pop
;;;  [3] Put ZWEI menu here.
;;;  [33] Call system menu

(DEFVAR *MOUSE-P*)
(DEFVAR *MOUSE-BLINKER*)
(DEFVAR *MOUSE-CHAR-BLINKER*)
(DEFVAR *MOUSE-BOX-BLINKER*)
(DEFVAR *GLOBAL-MOUSE-CHAR-BLINKER*)
(DEFVAR *GLOBAL-MOUSE-CHAR-BLINKER-HANDLER*)
(DEFVAR *GLOBAL-MOUSE-CHAR-BLINKER-DOCUMENTATION-STRING*)

;;; Called by the editor to initialize the mouse
(DEFUN INITIALIZE-MOUSE (&AUX (INHIBIT-SCHEDULING-FLAG T))
  (AND (BOUNDP '*MOUSE-CHAR-BLINKER*)
       (TV:OPEN-BLINKER *MOUSE-CHAR-BLINKER*))
  (SETQ *MOUSE-P* NIL
	*MOUSE-CHAR-BLINKER* (TV:MAKE-BLINKER TV:MOUSE-SHEET 'TV:CHARACTER-BLINKER
					      ':VISIBILITY NIL
					      ':HALF-PERIOD 4
					      ':FONT TV:(SCREEN-DEFAULT-FONT DEFAULT-SCREEN)
					      ':CHAR #/?)
	*MOUSE-BOX-BLINKER* (TV:MAKE-BLINKER TV:MOUSE-SHEET 'TV:HOLLOW-RECTANGULAR-BLINKER
					     ':VISIBILITY NIL)
	*MOUSE-BLINKER* *MOUSE-BOX-BLINKER*
	*GLOBAL-MOUSE-CHAR-BLINKER* (TV:MAKE-BLINKER TV:MOUSE-SHEET
						     'TV:HOLLOW-RECTANGULAR-BLINKER
						     ':VISIBILITY NIL
						     ':HALF-PERIOD 4)
	*GLOBAL-MOUSE-CHAR-BLINKER-HANDLER* NIL
	*GLOBAL-MOUSE-CHAR-BLINKER-DOCUMENTATION-STRING* NIL))

;;;Wait for the mouse to do something, return non-nil if released buttons or left window
;;;LAST-X, LAST-Y are relative to the inside of the window (like *MOUSE-X*, *MOUSE-Y*).
(DEFUN WAIT-FOR-MOUSE (LAST-X LAST-Y &OPTIONAL MAX-SPEED)
  (LET ((SHEET (WINDOW-SHEET *WINDOW*)))
    (MULTIPLE-VALUE-BIND (XOFF YOFF) (TV:SHEET-CALCULATE-OFFSETS SHEET TV:MOUSE-SHEET)
      (PROCESS-WAIT "MOUSE"
		    #'(LAMBDA (LX LY MS)
			(OR (AND (OR ( TV:MOUSE-X LX) ( TV:MOUSE-Y LY))
				 (OR (NULL MS) ( TV:MOUSE-SPEED MS)))
			    (ZEROP (TV:MOUSE-BUTTONS T))
			    (NOT *MOUSE-P*)))
		    (+ LAST-X (TV:SHEET-INSIDE-LEFT SHEET) XOFF)
		    (+ LAST-Y (TV:SHEET-INSIDE-TOP SHEET) YOFF)
		    MAX-SPEED)))
  (AND (NOT (ZEROP (TV:MOUSE-BUTTONS T))) *MOUSE-P*))

(DEFUN MOUSE-POSITION (&OPTIONAL (WINDOW *WINDOW*))
  (LET ((SHEET (WINDOW-SHEET WINDOW)))
    (MULTIPLE-VALUE-BIND (XOFF YOFF) (TV:SHEET-CALCULATE-OFFSETS SHEET TV:MOUSE-SHEET)
      (VALUES (- TV:MOUSE-X XOFF (TV:SHEET-INSIDE-LEFT SHEET))
	      (- TV:MOUSE-Y YOFF (TV:SHEET-INSIDE-TOP SHEET))))))

;;; Call MOUSE-CHAR so we can be sure that the BP points the thing that's blinking
;;; If X and Y are supplied, they are the coordinates to use, otherwise
;;; we use the coordinates of where the mouse is now.
(DEFUN MOUSE-BP (WINDOW &OPTIONAL X Y &AUX CHAR LINE CHAR-POS)
  (MULTIPLE-VALUE (CHAR X Y LINE CHAR-POS)
    (MOUSE-CHAR WINDOW T X Y))
  (COND ((NULL CHAR)      ;Couldn't anything, use end of buffer for want of anything better
         (COPY-BP (INTERVAL-LAST-BP (WINDOW-INTERVAL WINDOW))))
        (T
	 (CREATE-BP LINE CHAR-POS))))

;;; The mouse must be in the selected window's area of the screen
;;; Returns the character at which the mouse points, and the X and Y positions
;;; of that character relative to its sheet.  If the mouse is not at a character,
;;; returns NIL.
(DEFUN MOUSE-CHAR (WINDOW &OPTIONAL FIXUP-P X Y)
  (PROG (SHEET LINE PLINE CHAR-POS LH REAL-PLINE START END)
    (SETQ SHEET (WINDOW-SHEET WINDOW))
    (COND ((NULL Y)
	   (MULTIPLE-VALUE (X Y) (MOUSE-POSITION WINDOW))))
    (SETQ LH (TV:SHEET-LINE-HEIGHT SHEET)
	  PLINE (SETQ REAL-PLINE (// Y LH)))
    ;; If mouse moves to out of range, protect against error and return
    (AND (OR (MINUSP PLINE) ( PLINE (WINDOW-N-PLINES WINDOW)))
	 (IF FIXUP-P
	     (SETQ PLINE (MAX 0 (MIN PLINE (1- (WINDOW-N-PLINES WINDOW)))))
	     (RETURN NIL)))
    (DO NIL ((SETQ LINE (PLINE-LINE WINDOW PLINE)))
      (AND (ZEROP PLINE) (RETURN))
      (SETQ PLINE (1- PLINE)))
    (OR LINE (RETURN))
    (SETQ START (PLINE-FROM-INDEX WINDOW PLINE))
    (LET ((BP (INTERVAL-FIRST-BP (WINDOW-INTERVAL WINDOW))))
      (AND (EQ LINE (BP-LINE BP)) (SETQ START (MAX START (BP-INDEX BP)))))
    (LET ((BP (INTERVAL-LAST-BP (WINDOW-INTERVAL WINDOW))))
      (AND (EQ LINE (BP-LINE BP)) (SETQ END (BP-INDEX BP))))
    (MULTIPLE-VALUE (X Y CHAR-POS)         ;Find character to right of mouse
      (TV:SHEET-COMPUTE-MOTION SHEET 0 (* PLINE LH) LINE START END NIL
			       (MAX 0 X) (* REAL-PLINE LH)))
    (COND ((NULL CHAR-POS)			;Mouse is off end of line, pointing at the CR
	   (RETURN #\CR X Y LINE (OR END (LINE-LENGTH LINE))))
	  (T
	   ;; X, Y, CHAR-POS are for char to right of mouse
	   ;; Find the character which is just over the mouse
	   (SETQ CHAR-POS (MAX 0 (1- CHAR-POS)))
	   (LET ((CHAR (IF (= CHAR-POS (LINE-LENGTH LINE)) #\CR
			   (AREF LINE CHAR-POS)))
		 (FONT-MAP (TV:SHEET-FONT-MAP SHEET)))
	      (LET ((CH (LDB %%CH-CHAR CHAR))
		    (FONT (LDB %%CH-FONT CHAR))
		    CHAR-X CHAR-WIDTH)
		(SETQ FONT (AREF FONT-MAP (IF ( FONT (ARRAY-ACTIVE-LENGTH FONT-MAP))
					      0 FONT)))
		(IF (= CH #\TAB)
		    (SETQ CHAR-X (TV:SHEET-COMPUTE-MOTION SHEET 0 0 LINE START CHAR-POS)
			  CHAR-WIDTH (- X CHAR-X))
		    (SETQ CHAR-WIDTH (TV:SHEET-CHARACTER-WIDTH SHEET CH FONT)
			  CHAR-X (MAX 0 (- X CHAR-WIDTH))))
		(RETURN CHAR
			CHAR-X
			(+ Y (- (TV:SHEET-BASELINE SHEET) (FONT-BASELINE FONT)))
			LINE CHAR-POS CHAR-WIDTH)))))))

;;; This returns the name of a function, either from the buffer with the mouse, or the
;;; mini-buffer.
;;; STRINGP of T means return a string if one is typed, don't intern it now.
;;; STRINGP of ALWAYS-READ means always return a newly read symbol, even if a completion
;;; was typed.
(DEFUN READ-FUNCTION-NAME (PROMPT &OPTIONAL DEFAULT MUST-BE-DEFINED STRINGP
				  &AUX TEM CH STR)
  (AND (EQ MUST-BE-DEFINED T) (SETQ STRINGP 'ALWAYS-READ))
  (SETQ PROMPT (FORMAT NIL "~A~:[:~; (Default: ~S)~]" PROMPT DEFAULT DEFAULT))
  (COND ((OR *MINI-BUFFER-REPEATED-COMMAND* (FUNCALL STANDARD-INPUT ':LISTEN))
	 (SETQ TEM 0 CH NIL))			;C-X , no opportunity for mouse
	(T
	 (LET ((*MODE-LINE-LIST* (LIST PROMPT '(:RIGHT-FLUSH " (Completion)"))))
	   (REDISPLAY-MODE-LINE))		;Make correct for later
	 (DELETE-INTERVAL (WINDOW-INTERVAL *MINI-BUFFER-WINDOW*))
	 (MUST-REDISPLAY *MINI-BUFFER-WINDOW* DIS-ALL)
	 (SELECT-WINDOW *MINI-BUFFER-WINDOW*)
	 ;;KLUDGE, position blinker
	 (DO L (WINDOW-SPECIAL-BLINKER-LIST *MINI-BUFFER-WINDOW*) (CDR L) (NULL L)
	     (TV:BLINKER-SET-VISIBILITY (CDAR L) NIL))
	 (LET ((BL (WINDOW-POINT-BLINKER *MINI-BUFFER-WINDOW*)))
	   (TV:BLINKER-SET-CURSORPOS BL 0 0)
	   (TV:BLINKER-SET-VISIBILITY BL ':BLINK))
	 (UNWIND-PROTECT
	   (LET-GLOBALLY ((*GLOBAL-MOUSE-CHAR-BLINKER-HANDLER* (IF MUST-BE-DEFINED
								   #'BLINK-FUNCTION
								 #'BLINK-ATOM))
			  (*GLOBAL-MOUSE-CHAR-BLINKER-DOCUMENTATION-STRING*
			    "Click left on highlighted name to select it.")
			  (*MOUSE-FONT-CHAR* 0)
			  (*MOUSE-X-OFFSET* 4)
			  (*MOUSE-Y-OFFSET* 0))
	     (SETQ TV:MOUSE-RECONSIDER T)
	     (WITHOUT-IO-BUFFER-OUTPUT-FUNCTION
	       (MULTIPLE-VALUE (TEM CH)
		 (FUNCALL STANDARD-INPUT ':MOUSE-OR-KBD-TYI))))
	   (TV:BLINKER-SET-VISIBILITY *GLOBAL-MOUSE-CHAR-BLINKER* NIL)
	   (SETQ TV:MOUSE-RECONSIDER T))))
  (COND ((AND (= TEM #\MOUSE-1-1)
	      (MULTIPLE-VALUE-BIND (FCTN LINE START END)
		  (ATOM-UNDER-MOUSE (CADR CH))
		(COND ((OR (FBOUNDP (SETQ TEM FCTN))
			   (STRING-IN-AARRAY-P TEM *ZMACS-COMPLETION-AARRAY*)
			   (GET TEM ':SOURCE-FILE-NAME)
			   (AND (NOT MUST-BE-DEFINED) TEM))
		       (SETQ STR (SUBSTRING LINE START END))
		       T))))
	 (SELECT-WINDOW *WINDOW*)
	 (DISAPPEAR-MINI-BUFFER-WINDOW)	 
	 (OR *MINI-BUFFER-COMMAND*
	     (MINI-BUFFER-RING-PUSH (SETQ *MINI-BUFFER-COMMAND*
					  `((,*CURRENT-COMMAND*
					     ,*NUMERIC-ARG-P* ,*NUMERIC-ARG*)))))
	 (RPLACD (LAST *MINI-BUFFER-COMMAND*) (NCONS STR))
	 TEM)
	(T
	 (FUNCALL STANDARD-INPUT ':UNTYI CH)
	 (LET ((NAME (COMPLETING-READ-FROM-MINI-BUFFER PROMPT *ZMACS-COMPLETION-AARRAY*
						       (OR (NEQ STRINGP 'ALWAYS-READ)
							   'ALWAYS-STRING)))
	       SYM ERROR-P)
	   (COND ((EQUAL NAME "")
		  (OR DEFAULT (BARF))
		  (SETQ SYM DEFAULT NAME (STRING DEFAULT)))
		 ((LISTP NAME)
		  (SETQ SYM (CDR NAME)
			NAME (CAR NAME))
		  (AND (LISTP SYM) (NEQ STRINGP 'MULTIPLE-OK)
		       (SETQ SYM (CAR SYM))))
		 ((EQ STRINGP T)		;If returning a string, don't intern it
		  (SETQ SYM NAME))
		 (T
		  (MULTIPLE-VALUE (SYM NAME ERROR-P)
		    (SYMBOL-FROM-STRING NAME NIL T))
		  (AND (LISTP SYM) (EQ STRINGP 'MULTIPLE-OK)
		       (SETQ SYM (NCONS SYM)))
		  (AND ERROR-P (BARF "Read error"))))
	   (AND (EQ MUST-BE-DEFINED T) (NOT (FDEFINEDP SYM)) (BARF "~S is not defined" SYM))
	   (VALUES SYM NAME)))))

;;; This finds the atom the mouse is pointing to
(DEFUN ATOM-UNDER-MOUSE (WINDOW &OPTIONAL CHAR X Y LINE INDEX &AUX SYMBOL END)
  (OR CHAR (MULTIPLE-VALUE (CHAR X Y LINE INDEX)
	       (MOUSE-CHAR WINDOW)))
  (AND CHAR
       ( CHAR #\CR)
       (DO ((I INDEX (1- I)))
	   ((OR (ZEROP I)
		( (ATOM-WORD-SYNTAX (AREF LINE I)) WORD-ALPHABETIC))
	    (AND ( I INDEX)
		 (CATCH-ERROR (LET ((PACKAGE PACKAGE)
				    (READ-PRESERVE-DELIMITERS T)
				    (INTERVAL (WINDOW-INTERVAL WINDOW)))
				(AND (TYPEP INTERVAL 'FILE-BUFFER)
				     (COMPUTE-BUFFER-PACKAGE INTERVAL))
				(MULTIPLE-VALUE (SYMBOL END)
				  (READ-FROM-STRING LINE NIL (SETQ I (1+ I))))
				(SETQ END (MIN (ARRAY-ACTIVE-LENGTH LINE) END)))
			      NIL)
		 (SYMBOLP SYMBOL)
		 (VALUES SYMBOL LINE I END))))))

;;; This blinks functions that you point to
;;; This maximum speed thing is a crock, since the mouse can be moving fast
;;; and at the same time have come to rest, such that another :MOUSE-MOVES
;;; message is not going to be sent.  I guess I'll just set the number very high.
;;; This was probably put in to make mouse tracking smoother, and hence is no
;;; longer needed.
(DEFVAR *BLINKING-FUNCTION-MAXIMUM-MOUSE-SPEED* 50.)
(DEFUN BLINK-FUNCTION (BLINKER WINDOW CHAR X Y LINE INDEX &OPTIONAL NOT-DEFINED-OK
							  &AUX SYMBOL BEG END SHEET)
  (COND ((> TV:MOUSE-SPEED *BLINKING-FUNCTION-MAXIMUM-MOUSE-SPEED*)
	 (TV:BLINKER-SET-VISIBILITY BLINKER NIL))	;Moving too fast, forget it
	(T
	 (MULTIPLE-VALUE (SYMBOL NIL BEG END)
	   (ATOM-UNDER-MOUSE WINDOW CHAR X Y LINE INDEX))
	 (COND ((AND (NOT (NULL BEG))
		     (OR (FBOUNDP SYMBOL)
			 (STRING-IN-AARRAY-P SYMBOL *ZMACS-COMPLETION-AARRAY*)
			 (GET SYMBOL ':SOURCE-FILE-NAME)
			 NOT-DEFINED-OK))
		(SETQ SHEET (WINDOW-SHEET WINDOW))
		(TV:BLINKER-SET-SHEET BLINKER SHEET)
		(SHEET-SET-BLINKER-CURSORPOS SHEET BLINKER
					     (- X (TV:SHEET-STRING-LENGTH SHEET LINE BEG
									  INDEX))
					     Y)
		(TV:BLINKER-SET-SIZE BLINKER
				     (TV:SHEET-STRING-LENGTH SHEET LINE BEG END)
				     (FONT-CHAR-HEIGHT (AREF (TV:SHEET-FONT-MAP SHEET)
							     (LDB %%CH-FONT CHAR))))
		(TV:BLINKER-SET-VISIBILITY BLINKER T))
	       (T
		(TV:BLINKER-SET-VISIBILITY BLINKER NIL))))))

(DEFUN BLINK-ATOM (BLINKER WINDOW CHAR X Y LINE INDEX)
  (BLINK-FUNCTION BLINKER WINDOW CHAR X Y LINE INDEX T))

;;; The commands themselves

;;; Single click on the left button.
(DEFPROP COM-MOUSE-MARK-REGION "Move point" :MOUSE-SHORT-DOCUMENTATION)
(DEFCOM COM-MOUSE-MARK-REGION "Jump point and mark to where the mouse is.
Then as the mouse is moved with the button held down point follows the mouse." (KM)
  (REDISPLAY *WINDOW* ':NONE)
  (LET ((POINT (POINT))
	(MARK (MARK))
	(OLD-REGION-P (WINDOW-MARK-P *WINDOW*))
	(BP (MOUSE-BP *WINDOW* *MOUSE-X* *MOUSE-Y*)))
    (MOVE-BP MARK BP)
    (SETF (WINDOW-MARK-P *WINDOW*) T)
    (DO ((LAST-X *MOUSE-X*)
	 (LAST-Y *MOUSE-Y*))
	(NIL)
      (MOVE-BP POINT BP)
      (MUST-REDISPLAY *WINDOW* DIS-BPS)
      (REDISPLAY *WINDOW* ':POINT)
      (OR (WAIT-FOR-MOUSE LAST-X LAST-Y) (RETURN NIL))
      (MULTIPLE-VALUE (LAST-X LAST-Y) (MOUSE-POSITION))
      (SETQ BP (MOUSE-BP *WINDOW* LAST-X LAST-Y)))
    (AND (BP-= POINT MARK)
	 (SETF (WINDOW-MARK-P *WINDOW*) OLD-REGION-P)))
    DIS-NONE)

(DEFPROP COM-MOUSE-MOVE-REGION "Move to point" :MOUSE-SHORT-DOCUMENTATION)
(DEFCOM COM-MOUSE-MOVE-REGION "Select window, or adjust the region.
If there is a region, jump the mouse to point or mark (whichever
is closer), and move it with the mouse as long as the button is
held down.  If there is no region, select the window without
affecting point (or mark)." (KM)
  (LET ((SHEET (WINDOW-SHEET *WINDOW*))
	PX PY MX MY BP BP1 LAST-X LAST-Y)
    (MULTIPLE-VALUE (MX MY)
        (FIND-BP-IN-WINDOW-COORDS (MARK) *WINDOW*))
    (MULTIPLE-VALUE (PX PY)
        (FIND-BP-IN-WINDOW-COORDS (POINT) *WINDOW*))
    (MULTIPLE-VALUE (LAST-X LAST-Y) (MOUSE-POSITION))
    (SETQ BP (COND ((NOT (AND (WINDOW-MARK-P *WINDOW*) MX)) (POINT))
                   ((< (+ (^ (- LAST-X PX) 2) (^ (- LAST-Y PY) 2))
		       (+ (^ (- LAST-X MX) 2) (^ (- LAST-Y MY) 2)))
                    (POINT))
                   (T
                    (SETQ PX MX PY MY)
                    (MARK))))
    (FUNCALL SHEET ':SET-MOUSE-CURSORPOS
		   (+ PX (// (TV:SHEET-CHAR-WIDTH SHEET) 2))
		   (+ PY (// (* 3 (TV:SHEET-LINE-HEIGHT SHEET)) 4)))
    (DO ()
        (NIL)
      (OR (WAIT-FOR-MOUSE LAST-X LAST-Y) (RETURN NIL))
      (MULTIPLE-VALUE (LAST-X LAST-Y) (MOUSE-POSITION))
      (SETQ BP1 (MOUSE-BP *WINDOW* LAST-X LAST-Y))
      (MOVE-BP BP BP1)
      (MUST-REDISPLAY *WINDOW* DIS-BPS)
      (REDISPLAY *WINDOW* ':POINT)))
  DIS-NONE)

(DEFPROP COM-MOUSE-MARK-THING "Mark thing" :MOUSE-SHORT-DOCUMENTATION)
(DEFCOM COM-MOUSE-MARK-THING "Mark the thing you are pointing at." (SM)
  (DO ((POINT (POINT))
       (MARK (MARK))
       (LAST-X *MOUSE-X*)
       (LAST-Y *MOUSE-Y*)
       (X) (Y) (CHAR) (LINE) (CHAR-POS) (OL) (OCP))
      (NIL)
    (MULTIPLE-VALUE (CHAR X Y LINE CHAR-POS)
	(MOUSE-CHAR *WINDOW* NIL LAST-X LAST-Y))	;Figure out where mouse is
    (COND ((AND CHAR (OR (NEQ LINE OL) ( CHAR-POS OCP)))
	   (SETQ OL LINE OCP CHAR-POS)
	   (MOVE-BP POINT LINE CHAR-POS)
	   (FUNCALL (SELECTQ *MAJOR-MODE*
		      ((LISP-MODE ZTOP-MODE) 'LISP-MARK-THING)
		      ((TEXT-MODE FUNDAMENTAL-MODE BOLIO-MODE) 'TEXT-MARK-THING)
		      (OTHERWISE 'DEFAULT-MARK-THING))
		    POINT MARK CHAR LINE CHAR-POS)
	   (MUST-REDISPLAY *WINDOW* DIS-BPS)
	   (REDISPLAY *WINDOW* ':POINT)))
    (OR (WAIT-FOR-MOUSE LAST-X LAST-Y) (RETURN NIL))
    (MULTIPLE-VALUE (LAST-X LAST-Y) (MOUSE-POSITION)))
  DIS-NONE)

(DEFUN LISP-MARK-THING (POINT MARK CHAR LINE CHAR-POS)
  (ATOM-WORD-SYNTAX-BIND
    (SELECT (LIST-SYNTAX CHAR)
      ((LIST-OPEN LIST-SINGLE-QUOTE)
       (MOVE-BP MARK (FORWARD-SEXP POINT 1 T)))
      (LIST-CLOSE
       (MOVE-BP POINT (FORWARD-CHAR POINT 1))
       (MOVE-BP MARK (FORWARD-SEXP POINT -1 T 0 NIL NIL)))
      (LIST-DOUBLE-QUOTE
       (COND ((LISP-BP-SYNTACTIC-CONTEXT POINT)
	      (MOVE-BP POINT (FORWARD-CHAR POINT 1 T))
	      (MOVE-BP MARK (FORWARD-SEXP POINT -1)))
	     (T
	      (MOVE-BP MARK (FORWARD-SEXP POINT 1 T)))))
      (LIST-COMMENT
       (MOVE-BP POINT (BACKWARD-OVER *BLANKS* POINT))
       (MOVE-BP MARK LINE (LINE-LENGTH LINE)))
      (OTHERWISE
       (DEFAULT-MARK-THING POINT MARK CHAR LINE CHAR-POS)))))

(DEFUN TEXT-MARK-THING (POINT MARK CHAR LINE CHAR-POS)
  (COND ((MEMQ CHAR '(#/. #/? #/!))
         (MOVE-BP POINT (FORWARD-CHAR POINT 1))
         (MOVE-BP MARK (FORWARD-SENTENCE POINT -1 T)))
        ((MEMQ CHAR '(#/: #/; #/,))
         (MOVE-BP MARK (FORWARD-OVER *BLANKS* (FORWARD-CHAR
                                               (SEARCH-SET POINT
                                                           (IF (= CHAR #/,)
                                                               '(#/. #/? #/! #/: #/; #/,)
                                                               '(#/, #/? #/! #/: #/;))
                                                           T T)
                                               1 T)))
         (MOVE-BP POINT (FORWARD-CHAR POINT 1)))
        (T
         (DEFAULT-MARK-THING POINT MARK CHAR LINE CHAR-POS))))

(DEFUN DEFAULT-MARK-THING (POINT MARK CHAR LINE CHAR-POS &AUX TEM)
  (COND ((= CHAR #\FF)
         (MOVE-BP MARK (FORWARD-PAGE POINT -1 T)))
        ((MEMQ CHAR '(#\SP #\TAB))
         (COND ((STRING-REVERSE-SEARCH-NOT-SET *BLANKS* LINE CHAR-POS)
                (MOVE-BP MARK (FORWARD-WORD POINT 1 T)))
               (T
                (MOVE-BP POINT LINE 0)
                (MOVE-BP MARK LINE (LINE-LENGTH LINE)))))
        ((= CHAR #\CR)
         (MOVE-BP MARK LINE 0))
        ((SETQ TEM (ASSOC CHAR '((#/( . #/)) (#/[ . #/]) (#/< . #/>) (#/{ . #/}))))
         (MOVE-BP MARK (SEARCH POINT (CDR TEM) NIL T)))
        ((SETQ TEM (RASSOC CHAR '((#/( . #/)) (#/[ . #/]) (#/< . #/>) (#/{ . #/}))))
         (MOVE-BP POINT (FORWARD-CHAR POINT 1 T))
         (MOVE-BP MARK (SEARCH POINT (CAR TEM) T T)))
        (T
         (MOVE-BP MARK (FORWARD-WORD POINT 1 T))
         (MOVE-BP POINT (FORWARD-WORD MARK -1 T))
         ;; Now try to attach the right whitespace to the word
	 (OR *KILL-INTERVAL-SMARTS*
	     (LET ((BP (FORWARD-OVER *BLANKS* MARK)))
	       (COND ((NOT (BP-= BP MARK))
		      (MOVE-BP MARK BP))
		     (T
		      (SETQ BP (BACKWARD-OVER *BLANKS* POINT))
		      (OR (ZEROP (BP-INDEX BP)) (MOVE-BP POINT BP)))))))))

(DEFPROP COM-MOUSE-KILL-YANK "Save//Kill//Yank" :MOUSE-SHORT-DOCUMENTATION)
(DEFCOM COM-MOUSE-KILL-YANK "Kill region, unkill, or unkill pop.
If there is a region, save it; if it was saved last time, kill it;
else if the last command was an unkill, do unkill-pop, else unkill." ()
  (COND ((EQ *LAST-COMMAND-TYPE* 'SAVE)
         (DELETE-INTERVAL (POINT) (MARK))
         DIS-TEXT)
        ((WINDOW-MARK-P *WINDOW*)
         (SETQ *CURRENT-COMMAND-TYPE* 'SAVE)
         (COM-SAVE-REGION))
	((EQ *LAST-COMMAND-TYPE* 'YANK)
	 (COM-YANK-POP))
	(T
	 (COM-YANK))))

;;; This is on mouse-left in the mini-buffer, exit if you are pointing in it, else
;;; do the standard thing
(DEFPROP COM-MOUSE-END-OF-MINI-BUFFER "Exit" :MOUSE-SHORT-DOCUMENTATION)
(DEFCOM COM-MOUSE-END-OF-MINI-BUFFER "Finish up the mini-buffer command" ()
  (COND ((NEQ *WINDOW* *MINI-BUFFER-WINDOW*)
	 (COMMAND-EXECUTE (COMMAND-LOOKUP #\MOUSE-1-2 *STANDARD-COMTAB*) #\MOUSE-1-2))
	(T
	 (KEY-EXECUTE #\CR))))

;;; This is on mouse-right in the completing-reader, give a menu of the possibilities
(DEFCOM COM-MOUSE-LIST-COMPLETIONS "Give a menu of possible completions" ()
  (MULTIPLE-VALUE-BIND (NIL POSS)
      (COMPLETE-STRING (BP-LINE (POINT)) *COMPLETING-ALIST* *COMPLETING-DELIMS*)
    (OR POSS (BARF))
    (MULTIPLE-VALUE-BIND (CHOICE ITEM)
	(TV:MENU-CHOOSE POSS)
      (IF CHOICE
	  (*THROW 'RETURN-FROM-COMMAND-LOOP ITEM)
	  DIS-NONE))))

(DEFCOM COM-MOUSE-INDENT-RIGIDLY "Track indentation with the mouse.
If there is a region, moves the whole region, else the current line.  Continues until the
mouse is released." (KM)
  (LET ((POINT (POINT))
        (SHEET (WINDOW-SHEET *WINDOW*))
        (START-LINE)
        (END-LINE))
    (COND ((WINDOW-MARK-P *WINDOW*)		;If there is a region, use it
           (REGION (BP1 BP2)
		   (SETQ START-LINE (BP-LINE BP1)
			 END-LINE (BP-LINE BP2))
		   (OR (ZEROP (BP-INDEX BP2))
		       (SETQ END-LINE (LINE-NEXT END-LINE)))))
          (T
	   (SETQ START-LINE (BP-LINE POINT)
		 END-LINE (LINE-NEXT START-LINE))))
    (MULTIPLE-VALUE-BIND (X Y)
        (FIND-BP-IN-WINDOW-COORDS (FORWARD-OVER *BLANKS* (BEG-OF-LINE START-LINE)) *WINDOW*)
    (FUNCALL SHEET ':SET-MOUSE-CURSORPOS X Y))
    (PROCESS-WAIT "MOUSE" #'(LAMBDA () (OR (ZEROP TV:MOUSE-LAST-BUTTONS) *MOUSE-P*)))
    (DO ((LAST-X)
	 (LAST-Y)
	 (BP (COPY-BP POINT))
         (DELTA))
	(NIL)
      (MULTIPLE-VALUE (LAST-X LAST-Y) (MOUSE-POSITION))
      (SETQ DELTA (LINE-INDENTATION START-LINE SHEET))
      (MOVE-BP BP START-LINE 0)
      (INDENT-LINE BP (MAX 0 LAST-X) SHEET)
      (SETQ DELTA (- (LINE-INDENTATION START-LINE SHEET) DELTA))
      (OR (= DELTA 0)
          (DO ((LINE START-LINE (LINE-NEXT LINE)))
              ((EQ LINE END-LINE))
            (AND (NEQ LINE START-LINE)
                 (INDENT-LINE (MOVE-BP BP LINE 0)
                              (MAX 0 (+ DELTA (LINE-INDENTATION LINE SHEET))) SHEET))))
      (MUST-REDISPLAY *WINDOW* DIS-TEXT)
      (REDISPLAY *WINDOW* ':POINT)
      (OR (WAIT-FOR-MOUSE LAST-X LAST-Y 5) (RETURN NIL))))
  DIS-TEXT)

;;; *** This should figure out some other kind of mouse-blinker ***
(DEFCOM COM-MOUSE-INDENT-UNDER "Indent the current line as selected by the mouse." (KM)
  (LET ((CH (FUNCALL STANDARD-INPUT ':MOUSE-OR-KBD-TYI)))
    (COND ((= CH #\MOUSE-1-1)
	   (INDENT-LINE (POINT) (BP-INDENTATION (MOUSE-BP *WINDOW*)))
	   (INDENT-BP-ADJUSTMENT (POINT))
	   DIS-TEXT)
	  (T
	   (FUNCALL STANDARD-INPUT ':UNTYI CH)
           (COM-INDENT-UNDER)))))
