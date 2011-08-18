 ;;; Dribble Files				-*- LISP -*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(DECLARE (SPECIAL DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT
		  DRIBBLE-IO-PREVIOUS-STANDARD-INPUT
		  DRIBBLE-IO-UNRCHF DRIBBLE-FILE))

(DEFUN DRIBBLE-START (FILE-NAME)
  (COND ((BOUNDP 'DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT)
	 "ALREADY ATTACHED")
	(T (SETQ DRIBBLE-FILE (OPEN FILE-NAME '(WRITE)))
	   (SETQ DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT
		 STANDARD-OUTPUT)
	   (SETQ DRIBBLE-IO-PREVIOUS-STANDARD-INPUT
		 STANDARD-INPUT)
	   (SETQ DRIBBLE-IO-UNRCHF
		 NIL)
	   (SETQ STANDARD-OUTPUT
		 'DRIBBLE-IO)
	   (SETQ STANDARD-INPUT	   
		 'DRIBBLE-IO)
	   NIL)))

(DEFUN DRIBBLE-END ()
  (COND ((BOUNDP 'DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT)
	 (SETQ STANDARD-OUTPUT
	       DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT)
	 (SETQ STANDARD-INPUT
	       DRIBBLE-IO-PREVIOUS-STANDARD-INPUT)
	 (MAKUNBOUND 'DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT)
	 (CLOSE DRIBBLE-FILE)
	 NIL)
	("NOT ATTACHED")))

(DEFPROP DRIBBLE-IO T IO-STREAM-P)

(DEFUN DRIBBLE-IO (OP &OPTIONAL ARG1 &REST REST)
  (SELECTQ OP
    (:TYO
      (FUNCALL DRIBBLE-FILE ':TYO ARG1)
      (FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-OUTPUT OP ARG1))
    (:TYI
      (COND (DRIBBLE-IO-UNRCHF
	     (PROG1 DRIBBLE-IO-UNRCHF (SETQ DRIBBLE-IO-UNRCHF NIL)))
	    (T
	     (AND (SETQ ARG1 (FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-INPUT OP ARG1))
		  (FUNCALL DRIBBLE-FILE ':TYO ARG1))
	     ARG1)))
    (:UNTYI
      (SETQ DRIBBLE-IO-UNRCHF ARG1))
    (:RUBOUT-HANDLER		;Handling this is a bit of a kludge, needed to get echoing
      (MULTIPLE-VALUE-CALL	;If the user rubs out, funny stuff will get in the file...
          (LEXPR-FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-INPUT OP ARG1 REST)))
    (:READ-CURSORPOS		;Handling this is a bit of a kludge, mostly for FORMAT.
      (MULTIPLE-VALUE-CALL
          (LEXPR-FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-INPUT OP ARG1 REST)))
    (:WHICH-OPERATIONS
     (LET ((OPS (FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-INPUT ':WHICH-OPERATIONS)))
       (COND ((MEMQ ':RUBOUT-HANDLER OPS)
	      (COND ((MEMQ ':READ-CURSORPOS OPS)
		     '(:TYI :TYO :UNTYI :RUBOUT-HANDLER :READ-CURSORPOS))
		    (T '(:TYI :TYO :UNTYI :RUBOUT-HANDLER))))
	     ((MEMQ ':READ-CURSORPOS OPS)
	      '(:TYI :TYO :UNTYI :READ-CURSORPOS))
	     (T '(:TYI :TYO :UNTYI)))))
    (:PC-PPR (FUNCALL DRIBBLE-IO-PREVIOUS-STANDARD-INPUT ':PC-PPR))
    (OTHERWISE
     (MULTIPLE-VALUE-CALL (STREAM-DEFAULT-HANDLER 'DRIBBLE-IO OP ARG1 REST)))))
