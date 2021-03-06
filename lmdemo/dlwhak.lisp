;;; -*- Mode:Lisp; Package:Hacks-*-

;; User documentation:
;;; HACKS:TEST-PARC-WINDOW &optional (LABEL "This is a label.")
;;;     gets corners from the mouse and creates a PARC-labelled window.,
;;; HACKS:SPLINES draw splines on TERMINAL-IO.  You hit the left
;;;     button to set the next knot, and other buttons to draw it.  CTRL/ABORT to quit.
;;;     The middle button is relaxed open splines.
;;;     The right button is cyclic closed splines.
;;; (SETQ BASE 'TALLY) will cause numbers to come out in tally-mark notation.
;;;     This only works right if the default font is CPTFONT in the window.
;;; (TVBUG) from any Lisp Listener will walk a TV bug up from the bottom center.
;;;     It will go until it hits the top or until you type a character.  It runs
;;;     in "real time" mode.

(DEFFLAVOR PARC-LABEL-MIXIN () (TV:LABEL-MIXIN)
  (:INCLUDED-FLAVORS TV:WINDOW)
  (:DOCUMENTATION :MIXIN "Label at the top, with a box around it.
If the label is a string or defaults to the name, it is at the top.
When combined with BORDERS-MIXIN, the label will be surrounded by a box.
TOP-BOX-LABEL-MIXIN assumes borders will be outside, but this assumes
they will be inside."))

;;; Tell margin recomputation that there is an extra line, for the box.
(DEFMETHOD (PARC-LABEL-MIXIN :PARSE-LABEL-SPEC) (SPEC LM TM RM BM)
  (MULTIPLE-VALUE (SPEC LM TM RM BM)
    (TV:LABEL-MIXIN-PARSE-LABEL-SPEC-METHOD ':PARSE-LABEL-SPEC SPEC LM TM RM BM T))
  (AND SPEC (SETQ TM (+ TM 1)))
  (PROG () (RETURN SPEC LM TM RM BM)))

;;; Draw a box around the label.  Only draw three sides; the top border forms
;;; the bottom.
(DEFMETHOD (PARC-LABEL-MIXIN :AFTER :DRAW-LABEL) (SPEC LEFT TOP RIGHT BOTTOM)
  SPEC TOP
  (LET* ((WIDTH (- RIGHT LEFT))
	 (HEIGHT (- BOTTOM TOP))
	 (LABEL-LENGTH (MIN (1+ (FUNCALL-SELF ':STRING-LENGTH (TV:LABEL-STRING SPEC)))
			    WIDTH)))
    (TV:SHEET-FORCE-ACCESS (SELF)
      (TV:%DRAW-RECTANGLE 1 (1+ HEIGHT) LEFT TOP TV:CHAR-ALUF SELF)
      (TV:%DRAW-RECTANGLE LABEL-LENGTH 1 LEFT TOP TV:CHAR-ALUF SELF)
      (TV:%DRAW-RECTANGLE 1 (1+ HEIGHT) (+ LEFT LABEL-LENGTH) TOP TV:CHAR-ALUF SELF))))

;;; Must add 1 to top and left of string, to make room for the box.
(DEFMETHOD (PARC-LABEL-MIXIN :DRAW-LABEL) (SPEC LEFT TOP RIGHT BOTTOM)
  BOTTOM
  (AND SPEC
       (TV:SHEET-STRING-OUT-EXPLICIT SELF (TV:LABEL-STRING SPEC)
				     (1+ LEFT) (1+ TOP) (- RIGHT LEFT)
				     (TV:LABEL-FONT SPEC) TV:CHAR-ALUF)))

(DEFFLAVOR PARC-WINDOW () (PARC-LABEL-MIXIN TV:WINDOW))

(COMPILE-FLAVOR-METHODS PARC-WINDOW)

(DEFVAR TEST-PARC-WINDOW)

(DEFUN TEST-PARC-WINDOW (&OPTIONAL (LABEL "This is a label."))
  (SETQ TEST-PARC-WINDOW
	(TV:MAKE-WINDOW 'PARC-WINDOW
			':EDGES-FROM ':MOUSE
			':EXPOSE-P T
			':LABEL LABEL
			':BLINKER-P NIL)))

;;; Get a bunch of points from the user.
;;; Do graphics on WINDOW.  PX and PY are arrays which this function pushes
;;; pairs of coordinates onto.  If CLOSE-P, it will also push the first point
;;; onto the end.  It zeroes the fill pointers of the arrays.  It echoes
;;; by putting dots at each point.  You click left to put a point and click
;;; anything else to get out.
(DEFUN MOUSE-DRAW-SPLINE-CURVE (WINDOW PX PY DOCUMENTATION-STRING &AUX DX DY)
  (STORE-ARRAY-LEADER 0 PX 0)
  (STORE-ARRAY-LEADER 0 PY 0)
  (MULTIPLE-VALUE (DX DY)
    (TV:SHEET-CALCULATE-OFFSETS WINDOW TV:MOUSE-SHEET))
  (SETQ DX (+ DX (TV:SHEET-INSIDE-LEFT WINDOW))
	DY (+ DY (TV:SHEET-INSIDE-TOP WINDOW)))
  (TV:WITH-MOUSE-GRABBED
    (LET-GLOBALLY ((TV:WHO-LINE-MOUSE-GRABBED-DOCUMENTATION DOCUMENTATION-STRING))
      (DO ((X) (Y))
	  (NIL)
	(PROCESS-WAIT "Mouse up" #'(LAMBDA () (ZEROP TV:MOUSE-LAST-BUTTONS)))
	(PROCESS-WAIT "Mouse down"
		      #'(LAMBDA ()
			  (LOCAL-DECLARE ((SPECIAL MOUSE-FOO))
			    (NOT (ZEROP (SETQ MOUSE-FOO TV:MOUSE-LAST-BUTTONS))))))
	(LOCAL-DECLARE ((SPECIAL MOUSE-FOO))
	  (OR (= MOUSE-FOO 1) (RETURN MOUSE-FOO)))
	(SETQ X (- TV:MOUSE-X DX) Y (- TV:MOUSE-Y DY))
	(FUNCALL WINDOW ':DRAW-RECTANGLE 3 3 (1- X) (1- Y) TV:ALU-XOR)
;	(FUNCALL WINDOW ':DRAW-CHAR FONTS:CPTFONT #/  X Y TV:ALU-XOR)
	(ARRAY-PUSH-EXTEND PX X)
	(ARRAY-PUSH-EXTEND PY Y)))))

;;; Simple test program
(DEFVAR MOUSE-PX)
(DEFVAR MOUSE-PY)
(DEFVAR MOUSE-CX)
(DEFVAR MOUSE-CY)

(DEFUN SPLINES (&OPTIONAL (WINDOW TERMINAL-IO) (WIDTH 4) (ALU TV:ALU-IOR) (PRECISION 20.))
  (FUNCALL WINDOW ':CLEAR-SCREEN)
  (OR (BOUNDP 'MOUSE-PX)
      (SETQ MOUSE-PX (MAKE-ARRAY NIL 'ART-Q 100. NIL '(0))
	    MOUSE-PY (MAKE-ARRAY NIL 'ART-Q 100. NIL '(0))
	    MOUSE-CX (MAKE-ARRAY NIL 'ART-Q (* PRECISION 100.) NIL '(0))
	    MOUSE-CY (MAKE-ARRAY NIL 'ART-Q (* PRECISION 100.) NIL '(0))))
  (DO () (())
    (LET ((BUTTONS (MOUSE-DRAW-SPLINE-CURVE WINDOW MOUSE-PX MOUSE-PY
"Left: Set point.  Middle: Draw open curve.  Right: Draw closed curve.  CTRL//Abort exits.")))
      (LET ((LEN (ARRAY-ACTIVE-LENGTH MOUSE-PX)))
	(DOTIMES (N LEN)
	  (FUNCALL WINDOW ':DRAW-RECTANGLE 3 3 (1- (AREF MOUSE-PX N)) (1- (AREF MOUSE-PY N))
		   TV:ALU-XOR))
;	  (FUNCALL WINDOW ':DRAW-CHAR FONTS:CPTFONT #/  (AREF MOUSE-PX N) (AREF MOUSE-PY N)
;		   TV:ALU-XOR))
	(COND ((< LEN 2)
	       (FUNCALL WINDOW ':BEEP))
	      ((= BUTTONS 2)
	       (FUNCALL WINDOW ':DRAW-CUBIC-SPLINE
			MOUSE-PX MOUSE-PY PRECISION WIDTH ALU ':RELAXED))
	      (T
	       (ARRAY-PUSH-EXTEND MOUSE-PX (AREF MOUSE-PX 0))
	       (ARRAY-PUSH-EXTEND MOUSE-PY (AREF MOUSE-PY 0))
	       (FUNCALL WINDOW ':DRAW-CUBIC-SPLINE
			MOUSE-PX MOUSE-PY PRECISION WIDTH ALU ':CYCLIC)))))))

(DEFVAR *SPLINES-WINDOW* NIL "Window used by SPLINES-IN-WINDOW")

(DEFUN SPLINES-IN-WINDOW ()
  (IF (NULL *SPLINES-WINDOW*)
      (MULTIPLE-VALUE-BIND (LEFT TOP RIGHT BOTTOM)
	  (FUNCALL TV:MAIN-SCREEN ':EDGES)
	(LET ((FACTOR 10.))
	  (SETQ *SPLINES-WINDOW*
		(TV:MAKE-WINDOW 'TV:WINDOW
				':LEFT (+ LEFT FACTOR) ':TOP (+ TOP FACTOR)
				':RIGHT (- RIGHT FACTOR) ':BOTTOM (- BOTTOM FACTOR)
				':BORDERS 4
				':BLINKER-P NIL ':LABEL "Spline-drawing Window")))))
  (UNWIND-PROTECT
    (PROGN
      (FUNCALL *SPLINES-WINDOW* ':EXPOSE)
      (SPLINES *SPLINES-WINDOW*))
    (FUNCALL  *SPLINES-WINDOW* ':DEACTIVATE)))

(DEFDEMO "Splines" "Lets you draw open and closed cubic splines with the mouse."
  (SPLINES-IN-WINDOW))

(DEFPROP :TALLY TALLY-PRINC SI:PRINC-FUNCTION)

(DEFUN TALLY-PRINC (N STREAM)
  (IF (NOT (BOUNDP 'FONTS:TALLY))
      (LOAD "AI: DANNY; TALLY QFASL"))
  (COND ((GET-HANDLER-FOR STREAM ':SET-FONT-MAP)
	 (LET ((OLD-FONT-MAP (FUNCALL STREAM ':FONT-MAP))
	       (OLD-FONT (FUNCALL STREAM ':CURRENT-FONT)))
	   (UNWIND-PROTECT
	     (PROGN
	       (FUNCALL STREAM ':SET-FONT-MAP '(FONTS:CPTFONT FONTS:TALLY))
	       (FUNCALL STREAM ':SET-CURRENT-FONT 1)
	       (TALLY-PRINT (IF (BIGP N) N (- N)) STREAM))
	     (FUNCALL STREAM ':SET-FONT-MAP OLD-FONT-MAP)
	     (FUNCALL STREAM ':SET-CURRENT-FONT OLD-FONT))))
	(T
	 (TALLY-BOMB (IF (BIGP N) N (- N)) STREAM))))

(DEFUN TALLY-PRINT (N STREAM)
  (DOTIMES (I (// N 5))
    (FUNCALL STREAM ':TYO #/5))
  (DOTIMES (I (\ N 5))
    (FUNCALL STREAM ':TYO #/1)))

(DEFUN TALLY-BOMB (N STREAM)
  (LET ((BASE 10.))
    (PRINC N STREAM)))

(COMMENT ;old version
(DEFUN TVBUG (&OPTIONAL (SLOWNESS 10000.) (WINDOW STANDARD-OUTPUT))
  (IF (NOT (BOUNDP 'FONTS:TVBUG))
      (LOAD "SYS: FONTS; TVBUG"))
  (*CATCH 'CUT-IT-OUT
    (MULTIPLE-VALUE-BIND (WIDTH HEIGHT)
	(FUNCALL WINDOW ':INSIDE-SIZE)
      (WITH-REAL-TIME
	(DO ((X (// WIDTH 2))
	     (Y (- HEIGHT 33.)))
	    ((MINUSP Y))
	  (DOLIST (CHAR '(#/A #/B #/C #/D))
	    (FUNCALL WINDOW ':DRAW-CHAR FONTS:TVBUG CHAR X Y TV:ALU-XOR)
	    (DOTIMES (I SLOWNESS))
	    (FUNCALL WINDOW ':DRAW-CHAR FONTS:TVBUG CHAR X Y TV:ALU-XOR)
	    (IF (FUNCALL WINDOW ':TYI-NO-HANG)
		(*THROW 'CUT-IT-OUT NIL))
	    (SETQ Y (1- Y))))))))
);end COMMENT

(DEFVAR *TVBUG-ARRAYS*)	;List of the arrays of the bug
(DEFVAR *TVBUG-XORS*)	;Boolean first differences of the above
(DEFUN TVBUG (&OPTIONAL (SLOWNESS 10000.) (WINDOW STANDARD-OUTPUT))
  (IF (NOT (BOUNDP '*TVBUG-ARRAYS*))
      (LOAD "SYS: DEMO; TVBGAR"))
  (IF (NOT (BOUNDP '*TVBUG-XORS*))
      (SETQ *TVBUG-XORS*
	    (LOOP FOR (A1 A2) ON *TVBUG-ARRAYS*
		  AS XOR = (MAKE-ARRAY NIL 'ART-1B '(40 41))
		  DO (BITBLT TV:ALU-SETA 40 40 A1 0 0 XOR 0 1)
		  (BITBLT TV:ALU-XOR 40 40 (OR A2 (CAR *TVBUG-ARRAYS*)) 0 0 XOR 0 0)
		  COLLECT XOR)))
  (MULTIPLE-VALUE-BIND (WIDTH HEIGHT)
      (FUNCALL WINDOW ':INSIDE-SIZE)
    (WITH-REAL-TIME
      (LET ((X (// WIDTH 2)) (Y (- HEIGHT 33.)) (PHASE 0))
	(FUNCALL WINDOW ':BITBLT TV:ALU-XOR 40 40 (FIRST *TVBUG-ARRAYS*) 0 0 X Y)
	(DO-NAMED LUPO () ((FUNCALL WINDOW ':TYI-NO-HANG))
	  (DOLIST (XOR *TVBUG-XORS*)
	    (SETQ Y (1- Y))
	    (FUNCALL WINDOW ':BITBLT TV:ALU-XOR 40 41 XOR 0 0 X Y)
	    (SETQ PHASE (\ (1+ PHASE) (LENGTH *TVBUG-XORS*)))
	    (DOTIMES (I SLOWNESS))
	    (IF (ZEROP Y) (RETURN-FROM LUPO))))
	(FUNCALL WINDOW ':BITBLT TV:ALU-XOR 40 40 (NTH PHASE *TVBUG-ARRAYS*) 0 0 X Y)))))

(DEFDEMO "TV bug" "Display bugs in windows." (TVBUG))