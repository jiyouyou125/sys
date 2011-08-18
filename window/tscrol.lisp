;;; -*- Mode: LISP; Package: TV; Base: 8 -*-
;;;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(DEFFLAVOR TEXT-SCROLL-WINDOW
       ((ITEMS NIL)				;An array of all items
	(TOP-ITEM 0)				;The index of the topmost displayed item
	)
       ()
  (:INCLUDED-FLAVORS BASIC-SCROLL-BAR)
  :GETTABLE-INSTANCE-VARIABLES
  (:DEFAULT-INIT-PLIST :BLINKER-P NIL)
  (:DOCUMENTATION :MIXIN "Scrolling of lines all of one type"))

(DEFMETHOD (TEXT-SCROLL-WINDOW :BEFORE :INIT) (PLIST)
  (OR (ARRAYP ITEMS)
      (SETQ ITEMS (MAKE-ARRAY NIL 'ART-Q (OR ITEMS 100.) NIL '(0))))
  (PUTPROP PLIST NIL ':MORE-P))

(DEFMETHOD (TEXT-SCROLL-WINDOW :SET-ITEMS) (NEW-ITEMS)
  (SETQ ITEMS NEW-ITEMS)
  (SHEET-FORCE-ACCESS (SELF T)
    (FUNCALL-SELF ':CLEAR-SCREEN)
    (FUNCALL-SELF ':REDISPLAY 0 (SHEET-NUMBER-OF-INSIDE-LINES))))

(DEFMETHOD (TEXT-SCROLL-WINDOW :LAST-ITEM) ()
  (AND ITEMS (> (ARRAY-ACTIVE-LENGTH ITEMS) 0)
       (AREF ITEMS (1- (ARRAY-ACTIVE-LENGTH ITEMS)))))

(DEFMETHOD (TEXT-SCROLL-WINDOW :PUT-LAST-ITEM-IN-WINDOW) ()
  (OR ( (ARRAY-ACTIVE-LENGTH ITEMS)
	 (+ TOP-ITEM (SHEET-NUMBER-OF-INSIDE-LINES) -1))
      ;; Last item not on screen -- put it on bottom line
      (FUNCALL-SELF ':SCROLL-TO (- (ARRAY-ACTIVE-LENGTH ITEMS)
				   (SHEET-NUMBER-OF-INSIDE-LINES))
		    		':ABSOLUTE)))

(DEFMETHOD (TEXT-SCROLL-WINDOW :PUT-ITEM-IN-WINDOW) (ITEM)
  ;; If item not visible, put it in the window; if off the top, bring it to the
  ;; top.  If off the bottom, bring it to the bottom.
  (LET ((ITEM-NO (DOTIMES (I (ARRAY-ACTIVE-LENGTH ITEMS))
		   (AND (EQ (AREF ITEMS I) ITEM) (RETURN I))))
	(BOTTOM-ITEM (+ TOP-ITEM (SHEET-NUMBER-OF-INSIDE-LINES) -1)))
    (COND ((NULL ITEM-NO))
	  ((< ITEM-NO TOP-ITEM)
	   (FUNCALL-SELF ':SCROLL-TO ITEM-NO ':ABSOLUTE))
	  ((> ITEM-NO BOTTOM-ITEM)
	   (FUNCALL-SELF ':SCROLL-TO (- ITEM-NO (- BOTTOM-ITEM TOP-ITEM)) ':ABSOLUTE)))))

(DEFMETHOD (TEXT-SCROLL-WINDOW :APPEND-ITEM) (NEW-ITEM)
  (FUNCALL-SELF ':INSERT-ITEM (ARRAY-ACTIVE-LENGTH ITEMS) NEW-ITEM))

(DEFMETHOD (TEXT-SCROLL-WINDOW :DELETE-ITEM) (ITEM-NO &AUX I)
  (STORE-ARRAY-LEADER (1- (ARRAY-LEADER ITEMS 0)) ITEMS 0)
  (DO ((I ITEM-NO (1+ I)))
      (( I (ARRAY-ACTIVE-LENGTH ITEMS)))
    (ASET (AREF ITEMS (1+ I)) ITEMS I))
  (COND ((< ITEM-NO TOP-ITEM)
	 (SETQ TOP-ITEM (1- TOP-ITEM))
	 (FUNCALL-SELF ':NEW-SCROLL-POSITION))
	((< ITEM-NO (+ TOP-ITEM (SHEET-NUMBER-OF-INSIDE-LINES)))
	 ;; Old item was on the screen -- flush it
	 (SHEET-FORCE-ACCESS (SELF :NO-PREPARE)
	   (SHEET-SET-CURSORPOS SELF 0 (* LINE-HEIGHT (- ITEM-NO TOP-ITEM)))
	   (FUNCALL-SELF ':DELETE-LINE 1)
	   (FUNCALL-SELF ':REDISPLAY
			 (SETQ I (1- (SHEET-NUMBER-OF-INSIDE-LINES)))
			 (1+ I))))
	(T (FUNCALL-SELF ':NEW-SCROLL-POSITION)))
  ITEM-NO)

(DEFMETHOD (TEXT-SCROLL-WINDOW :INSERT-ITEM) (ITEM-NO NEW-ITEM)
  "Inserts an item before ITEM-NO"
  (LET ((NO-ITEMS (ARRAY-LEADER ITEMS 0)))
    (SETQ ITEM-NO (MIN (MAX ITEM-NO 0) NO-ITEMS))
    (ARRAY-PUSH-EXTEND ITEMS NIL)
    (DOTIMES (I (- NO-ITEMS ITEM-NO))
      ;; Bubble items up
      (ASET (AREF ITEMS (- NO-ITEMS I 1)) ITEMS (- NO-ITEMS I)))
    (ASET NEW-ITEM ITEMS ITEM-NO)
    (COND ((< ITEM-NO TOP-ITEM)
	   (SETQ TOP-ITEM (1+ TOP-ITEM))
	   (FUNCALL-SELF ':NEW-SCROLL-POSITION))
	  ((< ITEM-NO (+ TOP-ITEM (SHEET-NUMBER-OF-INSIDE-LINES)))
	   ;; New item is on screen, insert a line then redisplay it
	   (SHEET-FORCE-ACCESS (SELF :NO-PREPARE)
	     (SHEET-SET-CURSORPOS SELF 0 (* LINE-HEIGHT (SETQ ITEM-NO (- ITEM-NO TOP-ITEM))))
	     (FUNCALL-SELF ':INSERT-LINE 1)
	     (FUNCALL-SELF ':REDISPLAY ITEM-NO (1+ ITEM-NO))))
	  (T (FUNCALL-SELF ':NEW-SCROLL-POSITION))))
  ITEM-NO)

;;; When exposed, draw in the items
(DEFMETHOD (TEXT-SCROLL-WINDOW :AFTER :REFRESH) (&OPTIONAL TYPE)
  (AND (OR (NOT RESTORED-BITS-P) (EQ TYPE ':SIZE-CHANGED))
       (FUNCALL-SELF ':REDISPLAY 0 (SHEET-NUMBER-OF-INSIDE-LINES))))

;;; Arguments are screen line indices -- assumes screen area already erased
(DEFMETHOD (TEXT-SCROLL-WINDOW :REDISPLAY) (START END)
  (DO ((I START (1+ I))
       (J (+ START TOP-ITEM) (1+ J))
       (LIM (ARRAY-ACTIVE-LENGTH ITEMS)))
      ((OR ( I END) ( J LIM)))
    (SHEET-SET-CURSORPOS SELF 0 (* LINE-HEIGHT I))
    (FUNCALL-SELF ':PRINT-ITEM (AREF ITEMS J) I J))
  (FUNCALL-SELF ':NEW-SCROLL-POSITION))

;;; Each item is allowed only one line
(DEFWRAPPER (TEXT-SCROLL-WINDOW :PRINT-ITEM) (IGNORE . BODY)
  `(*CATCH 'LINE-OVERFLOW . ,BODY))

(DEFMETHOD (TEXT-SCROLL-WINDOW :END-OF-LINE-EXCEPTION) ()
  (*THROW 'LINE-OVERFLOW T))

;;; Simplest printer, you want to redefine this probably
(DEFMETHOD (TEXT-SCROLL-WINDOW :PRINT-ITEM) (ITEM LINE-NO ITEM-NO)
  LINE-NO ITEM-NO				;Ignore these
  (PRIN1 ITEM SELF))

;;; Scrolling
(DEFMETHOD (TEXT-SCROLL-WINDOW :SCROLL-BAR-P) ()
  (OR (PLUSP TOP-ITEM)
      (> (ARRAY-ACTIVE-LENGTH ITEMS) (SHEET-NUMBER-OF-INSIDE-LINES))))

(DEFMETHOD (TEXT-SCROLL-WINDOW :SCROLL-POSITION) ()
  (PROG () (RETURN TOP-ITEM (ARRAY-ACTIVE-LENGTH ITEMS) LINE-HEIGHT)))

(DEFMETHOD (TEXT-SCROLL-WINDOW :SCROLL-TO) (NEW-TOP TYPE &AUX DELTA)
  (AND (EQ TYPE ':RELATIVE) (SETQ NEW-TOP (+ TOP-ITEM NEW-TOP)))
  (SETQ NEW-TOP (MAX (MIN NEW-TOP (1- (ARRAY-ACTIVE-LENGTH ITEMS))) 0))
  (SETQ DELTA (- NEW-TOP TOP-ITEM))
  (OR (= DELTA 0)				;Nothing to change
      (FUNCALL-SELF ':SCROLL-REDISPLAY NEW-TOP DELTA))
  (FUNCALL-SELF ':NEW-SCROLL-POSITION))

(DEFMETHOD (TEXT-SCROLL-WINDOW :AFTER :NEW-SCROLL-POSITION) (&REST IGNORE)
  (MOUSE-WAKEUP))

;;;This is a message so it can have daemons
(DEFMETHOD (TEXT-SCROLL-WINDOW :SCROLL-REDISPLAY) (NEW-TOP DELTA &AUX NLINES)
  (SHEET-HOME SELF)
  (SETQ NLINES (SHEET-NUMBER-OF-INSIDE-LINES))
  (COND	((> DELTA 0)				;Scrolling forward
	 (SETQ DELTA (MIN DELTA NLINES))
	 (WITHOUT-INTERRUPTS
	   (FUNCALL-SELF ':DELETE-LINE DELTA)
	   (SETQ TOP-ITEM NEW-TOP))
	 (FUNCALL-SELF ':REDISPLAY (- NLINES DELTA) NLINES))
	((< DELTA 0)				;Scrolling backward
	 (SETQ DELTA (MIN (- DELTA) NLINES))
	 (WITHOUT-INTERRUPTS
	   (FUNCALL-SELF ':INSERT-LINE DELTA)
	   (SETQ TOP-ITEM NEW-TOP))
	 (FUNCALL-SELF ':REDISPLAY 0 DELTA)))
  (FUNCALL-SELF ':NEW-SCROLL-POSITION))

(DEFFLAVOR FUNCTION-TEXT-SCROLL-WINDOW
       (PRINT-FUNCTION				;Function called to print the item
	(PRINT-FUNCTION-ARG NIL)		;Fixed argument for above
	)
       (TEXT-SCROLL-WINDOW)
  (:SETTABLE-INSTANCE-VARIABLES PRINT-FUNCTION PRINT-FUNCTION-ARG)
  (:DOCUMENTATION :MIXIN "Text scroll windows that print lines by calling a set function"))

(DEFMETHOD (FUNCTION-TEXT-SCROLL-WINDOW :SETUP) (LIST)
  ;; Label changing should be first -- this may cause redisplay so flush current items too
  (AND ITEMS (STORE-ARRAY-LEADER 0 ITEMS 0))
  (AND ( (LENGTH LIST) 5) (FUNCALL-SELF ':SET-LABEL (FIFTH LIST)))
  (FUNCALL-SELF ':SET-PRINT-FUNCTION (FIRST LIST))
  (FUNCALL-SELF ':SET-PRINT-FUNCTION-ARG (SECOND LIST))
  (SETQ TOP-ITEM (OR (FOURTH LIST) 0))
  (LET ((ARRAY (OR ITEMS (MAKE-ARRAY NIL 'ART-Q (LENGTH (THIRD LIST)) NIL '(0)))))
    (STORE-ARRAY-LEADER 0 ARRAY 0)
    (DO L (THIRD LIST) (CDR L) (NULL L) (ARRAY-PUSH-EXTEND ARRAY (CAR L)))
    (FUNCALL-SELF ':SET-ITEMS ARRAY))
  LIST)

(DEFMETHOD (FUNCTION-TEXT-SCROLL-WINDOW :PRINT-ITEM) (ITEM IGNORE ITEM-NO)
  (FUNCALL PRINT-FUNCTION ITEM PRINT-FUNCTION-ARG SELF ITEM-NO))


(DEFFLAVOR TEXT-SCROLL-WINDOW-TYPEOUT-MIXIN () (WINDOW-WITH-TYPEOUT-MIXIN)
  (:INCLUDED-FLAVORS TEXT-SCROLL-WINDOW)
  (:DOCUMENTATION :MIXIN "Makes a TEXT-SCROLL-WINDOW have a typeout window"))

(DEFWRAPPER (TEXT-SCROLL-WINDOW-TYPEOUT-MIXIN :REDISPLAY) (ARGS . BODY)
  `(LET ((TO (TEXT-SCROLL-WINDOW-FLUSH-TYPEOUT)))
     (COND (TO
	    (SETF (FIRST ARGS) 0)
	    (SETF (SECOND ARGS) (MAX TO (SECOND ARGS)))))
     . ,BODY))

(DEFMETHOD (TEXT-SCROLL-WINDOW-TYPEOUT-MIXIN :FLUSH-TYPEOUT) ()
  (LET ((TO (TEXT-SCROLL-WINDOW-FLUSH-TYPEOUT)))
    (AND TO (FUNCALL-SELF ':REDISPLAY 0 TO))))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (TEXT-SCROLL-WINDOW-TYPEOUT-MIXIN)
(DEFUN TEXT-SCROLL-WINDOW-FLUSH-TYPEOUT ()
  "If the typeout window is active, deexpose it, and make sure the redisplayer knows how many lines were clobbered."
  (COND ((FUNCALL TYPEOUT-WINDOW ':ACTIVE-P)
	 (LET ((BR (MIN (1- (SHEET-NUMBER-OF-INSIDE-LINES))
			(1+ (// (FUNCALL TYPEOUT-WINDOW ':BOTTOM-REACHED) LINE-HEIGHT)))))
	   (FUNCALL TYPEOUT-WINDOW ':DEACTIVATE)
	   (FUNCALL-SELF ':DRAW-RECTANGLE
			 (SHEET-INSIDE-WIDTH) (* BR LINE-HEIGHT)
			 0 0
			 ALU-ANDCA)
	   BR)))))

(DEFFLAVOR DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW
	(DISPLAYED-ITEMS				;An array of mouse sensitive items
	  )
	(TEXT-SCROLL-WINDOW)
  (:DOCUMENTATION :MIXIN "Keep track of displayed items on the screen"))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :AFTER :INIT) (IGNORE)
  (SETQ DISPLAYED-ITEMS (MAKE-ARRAY NIL 'ART-Q (SHEET-NUMBER-OF-INSIDE-LINES))))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :AFTER :CHANGE-OF-SIZE-OR-MARGINS)
	   (&REST IGNORE)
  (LET ((NLINES (SHEET-NUMBER-OF-INSIDE-LINES)))
    (AND (< (ARRAY-LENGTH DISPLAYED-ITEMS) NLINES)
	 (ADJUST-ARRAY-SIZE DISPLAYED-ITEMS NLINES))))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :BEFORE :DELETE-ITEM) (ITEM-NO &AUX AL)
  "Deleting an item -- if on the screen, update the displayed items appropriately"
  (SETQ ITEM-NO (- ITEM-NO TOP-ITEM)
	AL (SHEET-NUMBER-OF-INSIDE-LINES))
  (COND ((AND ( ITEM-NO 0)
	      (< ITEM-NO AL))
	 (DOTIMES (I (- AL ITEM-NO 1))
	   (ASET (AREF DISPLAYED-ITEMS (+ I ITEM-NO 1)) DISPLAYED-ITEMS (+ I ITEM-NO)))
	 (ASET NIL DISPLAYED-ITEMS (1- AL)))))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :BEFORE :INSERT-ITEM) (ITEM-NO IGNORE &AUX AL)
  "Inserting an item -- adjust the data structure appropriatly"
  (SETQ ITEM-NO (- ITEM-NO TOP-ITEM)
	AL (SHEET-NUMBER-OF-INSIDE-LINES))
  (COND ((AND ( ITEM-NO 0)
	      (< ITEM-NO AL))
	 ;; The item will be on the screen, adjust the data structure
	 (DOTIMES (I (- AL ITEM-NO 1))
	   (ASET (AREF DISPLAYED-ITEMS (- AL I 2)) DISPLAYED-ITEMS (- AL I 1)))
	 (ASET NIL DISPLAYED-ITEMS ITEM-NO))))

;;;Forget anything that was on screen before
(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :BEFORE :REDISPLAY) (START END)
  (DO I START (1+ I) ( I END)
    (ASET NIL DISPLAYED-ITEMS I)))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :BEFORE :SET-ITEMS) (&REST IGNORE)
  ;; Make sure mouse isn't left pointing to gubbish
  (DOTIMES (I (ARRAY-LENGTH DISPLAYED-ITEMS))
    (ASET NIL DISPLAYED-ITEMS I)))

(DEFMETHOD (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW :BEFORE :SCROLL-REDISPLAY) (IGNORE DELTA
									   &AUX NLINES)
  (SETQ NLINES (SHEET-NUMBER-OF-INSIDE-LINES))
  (COND ((> DELTA 0)				;Scrolling forward
	 (DO ((I DELTA (1+ I))
	      (J 0 (1+ J)))
	     (( I NLINES)
	      (DO J J (1+ J) ( J NLINES)
		(ASET NIL DISPLAYED-ITEMS J)))
	   (ASET (AREF DISPLAYED-ITEMS I) DISPLAYED-ITEMS J)))
	((< DELTA 0)				;Scrolling backward
	 (DO ((I (1- (+ NLINES DELTA)) (1- I))
	      (J (1- NLINES) (1- J)))
	     ((< I 0)
	      (DO J J (1- J) (< J 0)
		(ASET NIL DISPLAYED-ITEMS J)))
	   (ASET (AREF DISPLAYED-ITEMS I) DISPLAYED-ITEMS J)))))

(DEFFLAVOR MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK
       ((SENSITIVE-ITEM-TYPES T)		;Types of items that can be selected
	ITEM-BLINKER				;Blinker for displaying things
	)
       (DISPLAYED-ITEMS-TEXT-SCROLL-WINDOW)
  (:SETTABLE-INSTANCE-VARIABLES SENSITIVE-ITEM-TYPES)
  (:DOCUMENTATION :MIXIN "Text scroll window that allows selection of parts of text"))

(DEFSTRUCT (MOUSE-SENSITIVE-ITEM :LIST (:CONSTRUCTOR NIL))
  DISPLAYED-ITEM-ITEM
  DISPLAYED-ITEM-TYPE
  DISPLAYED-ITEM-LEFT
  DISPLAYED-ITEM-RIGHT)

(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :AFTER :INIT) (IGNORE)
  (SETQ ITEM-BLINKER (MAKE-BLINKER SELF 'HOLLOW-RECTANGULAR-BLINKER ':VISIBILITY NIL)))

;;;Print something that is sensitive to the mouse -- generally called inside a :PRINT-ITEM
(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :ITEM)
	   (ITEM TYPE &OPTIONAL (FUNCTION #'PRIN1) &REST PRINT-ARGS &AUX DISITEM)
  (SETQ DISITEM (LIST ITEM TYPE CURSOR-X (SHEET-INSIDE-RIGHT)))
  (PUSH DISITEM (AREF DISPLAYED-ITEMS (SHEET-LINE-NO)))
  (LEXPR-FUNCALL FUNCTION ITEM SELF PRINT-ARGS)
  ;; Try to avoid making zero-length items that cannot be selected with the mouse
  (SETF (DISPLAYED-ITEM-RIGHT DISITEM)
	(MIN (MAX (+ (DISPLAYED-ITEM-LEFT DISITEM) (SHEET-CHAR-WIDTH SELF)) CURSOR-X)
	     (SHEET-INSIDE-RIGHT)))
  (MOUSE-WAKEUP))

(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :AFTER :HANDLE-MOUSE) ()
  (BLINKER-SET-VISIBILITY ITEM-BLINKER NIL))

;;; Turn off blinker before setting up new items
(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :BEFORE :SET-ITEMS)
	   (&REST IGNORE)
  (BLINKER-SET-VISIBILITY ITEM-BLINKER NIL))

;;;Blink any item the mouse points to
(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :MOUSE-MOVES) (X Y
									    &AUX ITEM TYPE
										 LEFT TOP
										 BWIDTH
										 BHEIGHT)
  (MOUSE-SET-BLINKER-CURSORPOS)
  (MULTIPLE-VALUE (ITEM TYPE LEFT BWIDTH TOP)
    (FUNCALL-SELF ':MOUSE-SENSITIVE-ITEM X Y))
  (COND (TYPE
	 (SETQ BWIDTH (- BWIDTH LEFT)
	       BHEIGHT (FONT-BLINKER-HEIGHT CURRENT-FONT))
	 (BLINKER-SET-CURSORPOS ITEM-BLINKER (- LEFT (SHEET-INSIDE-LEFT))
					     (- TOP (SHEET-INSIDE-TOP)))
	 (BLINKER-SET-SIZE ITEM-BLINKER BWIDTH BHEIGHT)
	 (BLINKER-SET-VISIBILITY ITEM-BLINKER T))
	(T (BLINKER-SET-VISIBILITY ITEM-BLINKER NIL))))

(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK :MOUSE-SENSITIVE-ITEM) (X Y)
  (MOUSE-SENSITIVE-ITEM X Y))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK)
(DEFUN MOUSE-SENSITIVE-ITEM (X Y &AUX LINE-NO)
  (SETQ LINE-NO (SHEET-LINE-NO NIL Y))
  (AND ( Y (SHEET-INSIDE-TOP))
       (< Y (+ (SHEET-INSIDE-TOP) (* (SHEET-NUMBER-OF-INSIDE-LINES) LINE-HEIGHT)))
       (DOLIST (ITEM (AREF DISPLAYED-ITEMS LINE-NO))
	 (AND (OR (EQ SENSITIVE-ITEM-TYPES T)	;If everything visible,
		  (MEMQ (DISPLAYED-ITEM-TYPE ITEM) SENSITIVE-ITEM-TYPES))	;or this is ok
	      ( (DISPLAYED-ITEM-LEFT ITEM) X)	;And within this place on the line
	      (> (DISPLAYED-ITEM-RIGHT ITEM) X)
	      (RETURN (DISPLAYED-ITEM-ITEM ITEM) (DISPLAYED-ITEM-TYPE ITEM)
		      (DISPLAYED-ITEM-LEFT ITEM) (DISPLAYED-ITEM-RIGHT ITEM)
		      (+ (SHEET-INSIDE-TOP) (* LINE-NO LINE-HEIGHT))))))))

(DEFFLAVOR MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW ()
	   (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW-WITHOUT-CLICK))

(DEFMETHOD (MOUSE-SENSITIVE-TEXT-SCROLL-WINDOW :MOUSE-CLICK) (BUTTON X Y &AUX ITEM TYPE)
  (MULTIPLE-VALUE (ITEM TYPE) (FUNCALL-SELF ':MOUSE-SENSITIVE-ITEM X Y))
  (COND (TYPE
	 (FUNCALL-SELF ':FORCE-KBD-INPUT (LIST TYPE ITEM SELF BUTTON))
	 T)))

(DEFFLAVOR TEXT-SCROLL-WINDOW-EMPTY-GRAY-HACK () ()
  (:INCLUDED-FLAVORS TEXT-SCROLL-WINDOW)
  (:DOCUMENTATION :MIXIN "Text scroll window that is grayed when it has no items"))

(DEFMETHOD (TEXT-SCROLL-WINDOW-EMPTY-GRAY-HACK :AFTER :REDISPLAY)
	   EMPTY-GRAY-HACK-DRAW-GRAY)

(DECLARE-FLAVOR-INSTANCE-VARIABLES (TEXT-SCROLL-WINDOW-EMPTY-GRAY-HACK)
(DEFUN EMPTY-GRAY-HACK-DRAW-GRAY (&REST IGNORE)
  (OR (PLUSP (ARRAY-ACTIVE-LENGTH ITEMS))
      (PREPARE-SHEET (SELF)
        (BITBLT CHAR-ALUF (SHEET-INSIDE-WIDTH) (SHEET-INSIDE-HEIGHT)
		25%-GRAY 0 0
		SCREEN-ARRAY (SHEET-INSIDE-LEFT) (SHEET-INSIDE-TOP))))))

(DEFMETHOD (TEXT-SCROLL-WINDOW-EMPTY-GRAY-HACK :BEFORE :INSERT-ITEM) (&REST IGNORE)
  (OR (PLUSP (ARRAY-ACTIVE-LENGTH ITEMS))
      ;; We must have been gray -- erase ourselves
      (FUNCALL-SELF ':CLEAR-SCREEN)))

(DEFMETHOD (TEXT-SCROLL-WINDOW-EMPTY-GRAY-HACK :AFTER :DELETE-ITEM)
	   EMPTY-GRAY-HACK-DRAW-GRAY)

;;;Fancy printing of an item
(DEFUN PRINT-ITEM-CONCISELY (ITEM STREAM &OPTIONAL (LEVEL 0) &AUX (TYPE (DATA-TYPE ITEM)))
  (IF (EQ TYPE 'DTP-LIST)
      (COND ((EQ (CAR ITEM) 'QUOTE)
	     (FUNCALL STREAM ':TYO #/')
	     (FUNCALL STREAM ':ITEM (CADR ITEM) ':VALUE #'PRINT-ITEM-CONCISELY (1+ LEVEL)))
	    ((AND PRINLEVEL ( LEVEL PRINLEVEL))
	     (FUNCALL STREAM ':STRING-OUT (SI:PTTBL-PRINLEVEL READTABLE)))
	    (T
	     (DO () ((OR (NLISTP ITEM) (NEQ (CAR ITEM) 'QUOTE)))
	       (SETQ ITEM (CADR ITEM)))
	     (FUNCALL STREAM ':TYO (SI:PTTBL-OPEN-PAREN READTABLE))
	     (DO ((L ITEM (CDR L))
		  (FLAG NIL T)
		  (I 1 (1+ I)))
		 ((ATOM L)
		  (COND (L
			 (FUNCALL STREAM ':STRING-OUT (SI:PTTBL-CONS-DOT READTABLE))
			 (FUNCALL STREAM ':ITEM L ':VALUE #'PRINT-ITEM-CONCISELY (1+ LEVEL))))
		  (FUNCALL STREAM ':TYO (SI:PTTBL-CLOSE-PAREN READTABLE)))
	       (AND FLAG (FUNCALL STREAM ':TYO (SI:PTTBL-SPACE READTABLE)))
	       (FUNCALL STREAM ':ITEM (CAR L) ':VALUE #'PRINT-ITEM-CONCISELY (1+ LEVEL))
	       (COND ((AND PRINLENGTH ( I PRINLENGTH))
		      (FUNCALL STREAM ':STRING-OUT (SI:PTTBL-PRINLENGTH READTABLE))
		      (RETURN NIL))))))
      (SELECTQ TYPE
	((DTP-FEF-POINTER DTP-U-ENTRY)
	 (FUNCALL STREAM ':STRING-OUT "#'"))
	(DTP-ARRAY-POINTER
	 (AND (STRINGP ITEM)
	      (OR (AND ( LEVEL 0) (> (ARRAY-ACTIVE-LENGTH ITEM) 20.))
		  (STRING-SEARCH-CHAR #\CR ITEM))
	      (SETQ ITEM "..."))))
      (PRIN1 (SELECTQ TYPE
	       (DTP-FEF-POINTER (%P-CONTENTS-OFFSET ITEM %FEFHI-FCTN-NAME))
	       (DTP-U-ENTRY (MICRO-CODE-ENTRY-NAME-AREA (%POINTER ITEM)))
	       (OTHERWISE ITEM))
	     STREAM)))

(DEFVAR GRIND-INTO-LIST-LIST)
(DEFVAR GRIND-INTO-LIST-STRING)
(DEFVAR GRIND-INTO-LIST-ITEMS-P)
(DEFVAR GRIND-INTO-LIST-ITEMS)
(DEFVAR GRIND-INTO-LIST-LIST-ITEMS)
(DEFVAR GRIND-INTO-LIST-LIST-ITEM-STACK)
(DEFVAR GRIND-INTO-LIST-LINE)

(DEFUN GRIND-INTO-LIST (EXP WIDTH &OPTIONAL ITEMS-P
			    &AUX GRIND-INTO-LIST-LIST GRIND-INTO-LIST-STRING
			    (GRIND-INTO-LIST-ITEMS-P ITEMS-P)
			    (GRIND-INTO-LIST-ITEMS (NCONS NIL))
			    GRIND-INTO-LIST-LIST-ITEMS
			    GRIND-INTO-LIST-LIST-ITEM-STACK
			    (GRIND-INTO-LIST-LINE 0))
  (GRIND-TOP-LEVEL EXP WIDTH 'GRIND-INTO-LIST-IO NIL 'SI:DISPLACED T
		   (AND ITEMS-P 'GRIND-INTO-LIST-MAKE-ITEM) ':TOP-LEVEL)
  (GRIND-INTO-LIST-IO ':TYO #\CR)
  (PROG () (RETURN (NREVERSE GRIND-INTO-LIST-LIST)
		   (NREVERSE GRIND-INTO-LIST-ITEMS)
		   GRIND-INTO-LIST-LIST-ITEMS)))

(DEFUN GRIND-INTO-LIST-IO (OP &OPTIONAL ARG1 &REST REST)
  (COND ((EQ OP ':WHICH-OPERATIONS) '(:TYO))
	((EQ OP ':TYO)
	 (COND ((= ARG1 #\CR)
		(COND (GRIND-INTO-LIST-STRING
		       (PUSH GRIND-INTO-LIST-STRING GRIND-INTO-LIST-LIST)
		       (SETQ GRIND-INTO-LIST-LINE (1+ GRIND-INTO-LIST-LINE))
		       (AND GRIND-INTO-LIST-ITEMS-P
			    (PUSH NIL GRIND-INTO-LIST-ITEMS))))
		(SETQ GRIND-INTO-LIST-STRING (MAKE-ARRAY NIL 'ART-STRING 50. NIL '(0))))
	       (T
		(ARRAY-PUSH-EXTEND GRIND-INTO-LIST-STRING ARG1))))
	(T
	 (STREAM-DEFAULT-HANDLER 'GRIND-INTO-LIST-IO OP ARG1 REST))))

(DEFUN GRIND-INTO-LIST-MAKE-ITEM (THING LOC ATOM-P)
  (LET ((IDX (IF GRIND-INTO-LIST-STRING
		 (ARRAY-ACTIVE-LENGTH GRIND-INTO-LIST-STRING)
		 0)))
    (COND (ATOM-P
	   ;; An atom -- make an item for it
	   (PUSH (LIST LOC ':LOCATIVE IDX (+ IDX (FLATSIZE THING)))
		 (CAR GRIND-INTO-LIST-ITEMS)))
	  (T
	   ;; Printing an interesting character
	   (SELECTQ THING
	     (#/(
	      ;; Start of a list
	      (PUSH (LIST LOC IDX GRIND-INTO-LIST-LINE NIL NIL)
		    GRIND-INTO-LIST-LIST-ITEM-STACK))
	     (#/)
	      ;; Closing a list
	      (LET ((ITEM (POP GRIND-INTO-LIST-LIST-ITEM-STACK)))
		;; 1+ is to account for close-paren which hasn't been typed yet
		(SETF (FOURTH ITEM) (1+ IDX))
		(SETF (FIFTH ITEM) GRIND-INTO-LIST-LINE)
		(PUSH ITEM GRIND-INTO-LIST-LIST-ITEMS))))))))

(DEFUN CONCISE-FLATSIZE (THING)
  (LET ((SI:*IOCH 0))
    (PRINT-ITEM-CONCISELY THING 'CONCISE-FLATSIZE-STREAM)
    SI:*IOCH))

(DEFPROP CONCISE-FLATSIZE-STREAM T SI:IO-STREAM-P)
(DEFUN CONCISE-FLATSIZE-STREAM (OP &OPTIONAL ARG1 &REST REST)
  (IF (EQ OP ':ITEM)
      (PRINT-ITEM-CONCISELY ARG1 'CONCISE-FLATSIZE-STREAM (THIRD REST))
      (LEXPR-FUNCALL #'SI:FLATSIZE-STREAM OP ARG1 REST)))

(DEFUN CONCISE-STRING (THING &OPTIONAL TRUNCATE-AT)
  "Prints thing concisely into a string.  Returns two values: the string, and
an item-list in the form: (object starting-position-in-string last-position-in-string)."
  (LOCAL-DECLARE ((SPECIAL CONCISE-STRING CONCISE-ITEMS CONCISE-TRUNCATE))
    (LET ((CONCISE-STRING (MAKE-ARRAY NIL 'ART-STRING (OR TRUNCATE-AT 100.) NIL '(0)))
	  (CONCISE-ITEMS NIL)
	  (CONCISE-TRUNCATE TRUNCATE-AT))
      (*CATCH 'CONCISE-TRUNCATE
	(PRINT-ITEM-CONCISELY THING 'CONCISE-STRING-STREAM))
      (PROG () (RETURN CONCISE-STRING CONCISE-ITEMS)))))

(DEFPROP CONCISE-STRING-STREAM T SI:IO-STREAM-P)
(DEFUN CONCISE-STRING-STREAM (OP &OPTIONAL ARG1 &REST REST)
  (LOCAL-DECLARE ((SPECIAL CONCISE-STRING CONCISE-ITEMS CONCISE-TRUNCATE))
    (SELECTQ OP
      (:TYO
       (ARRAY-PUSH-EXTEND CONCISE-STRING ARG1)
       (AND CONCISE-TRUNCATE
	    ( (ARRAY-LEADER CONCISE-STRING 0) CONCISE-TRUNCATE)
	    (*THROW 'CONCISE-TRUNCATE NIL)))
      (:WHICH-OPERATIONS '(:TYO))
      (:ITEM
       (LET ((ITEM (LIST ARG1 (ARRAY-LEADER CONCISE-STRING 0) CONCISE-TRUNCATE)))
	 (PUSH ITEM CONCISE-ITEMS)
	 (PRINT-ITEM-CONCISELY ARG1 'CONCISE-STRING-STREAM (THIRD REST))
	 (SETF (THIRD ITEM) (ARRAY-LEADER CONCISE-STRING 0))))
      (T (STREAM-DEFAULT-HANDLER 'CONCISE-STRING-STREAM OP ARG1 REST)))))