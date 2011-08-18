;;; -*- Mode:LISP; Package:FILE-SYSTEM -*-
;	** (c) Copyright 1980 Massachusetts Institute of Technology **
;;; New filename stuff:
;;; Filenames now get parsed into actors, which handle interesting messages.  This allows
;;; multiple hosts to be used by the same Lisp Machine, and have their filesnames
;;; handled correctly, etc...

;;; The main entrypoint is FILE-PARSE-NAME namestring &OPTIONAL with-respect-to
;;; which returns a FILENAME type instance with the namestring parsed.  If with-respect-to
;;; is supplied, then instead of looking for a host, it uses the value of this argument,
;;; so that things like :RENAME which require two filenames from the same host
;;; will default correctly.  Defaults are maintained on a per-host basis, though there
;;; is some argument as to whether this is correct.

(DEFVAR FILE-DEFAULTS-PER-HOST NIL)
;(DEFVAR FILE-DEFAULT-HOST)			;Maintained by QFILE

(REMPROP 'FILE-PARSE-NAME ':SOURCE-FILE-NAME)
(DEFUN FILE-PARSE-NAME (NAMESTRING &OPTIONAL WITH-RESPECT-TO (DEFAULT T) DEFAULT-TYPE)
  (COND ((TYPEP NAMESTRING 'FILENAME) NAMESTRING)
	(T
	 (SETQ NAMESTRING (STRING NAMESTRING))
	 (LET ((COLON-IDX (DO ((IDX 0 (1+ IDX))
			       (CHAR))
			      (( IDX (STRING-LENGTH NAMESTRING)))
			    (AND (= (SETQ CHAR (AREF NAMESTRING IDX)) #/:)
				 (RETURN IDX))
			    (OR (AND ( CHAR #/0) ( CHAR #/9))
				(AND ( CHAR #/A) ( CHAR #/Z))
				(AND ( CHAR #/a) ( CHAR #/z))
				;; If we get to non-alphabetic or -numeric,
				;; then no interesting colon
				(RETURN NIL))))
	       (HOST-INFO)
	       (HOST))
	   (COND (COLON-IDX
		  (SETQ HOST (SUBSTRING NAMESTRING 0 COLON-IDX))
		  (OR (SETQ HOST-INFO (ASSOC HOST HOST-FILENAME-FLAVOR-ALIST))
		      (SETQ COLON-IDX NIL
			    HOST NIL))
		  (AND WITH-RESPECT-TO
		       HOST
		       ;; If the thing before the colon is really a
		       ;; host, and WITH-RESPECT-TO was
		       ;; specified, then they better match
		       (NOT (STRING-EQUAL WITH-RESPECT-TO HOST))
		       (FERROR NIL "Host in ~A does not match ~A" NAMESTRING WITH-RESPECT-TO))
		  ))
	   (SETQ HOST (STRING-UPCASE (OR HOST
					 WITH-RESPECT-TO
					 ;; If default is a filename,
					 ;; then that specifies default host
					 (AND (TYPEP DEFAULT 'FILENAME)
					      (FUNCALL DEFAULT ':HOST))
					 FILE-DEFAULT-HOST)))
	   (SETQ HOST-INFO (OR HOST-INFO (ASSOC HOST HOST-FILENAME-FLAVOR-ALIST)))
	   (OR HOST-INFO
	       (FERROR NIL "Host information cannot be located for host ~A" HOST))
	   (FILE-CREATE-FILENAME HOST ':NAMESTRING (IF COLON-IDX
						       (SUBSTRING NAMESTRING (1+ COLON-IDX))
						       NAMESTRING)
				 ':HOST-SPECIFIED (NOT (NULL COLON-IDX))
				 ':DEFAULT-FILENAME DEFAULT
				 ':DEFAULT-TYPE DEFAULT-TYPE)))))

;(DEFVAR FILE-HOST-DEFAULTS-ALIST NIL)
(DEFUN FILE-DEFAULT-FILENAME (HOST)
  (FORCE-USER-TO-LOGIN)
  (OR (CDR (ASSOC HOST FILE-HOST-DEFAULTS-ALIST))
      (LET* ((HOST-INFO (SI:INIT-FORM (OR (ASSOC HOST FILE-HOST-ALIST)
					  (FERROR NIL "~A is unknown host" HOST))))
	     (UNIT (SYMEVAL-IN-CLOSURE HOST-INFO 'FILE-HOST-FIRST-UNIT)))
	(OR (HOST-UNIT-GRAB UNIT (FUNCALL HOST-INFO ':VALIDATE-CONTROL-CONNECTION UNIT))
	    (FERROR NIL "Cannot connect to host ~A" HOST))
	(OR (CDR (ASSOC HOST FILE-HOST-DEFAULTS-ALIST))
	    (FERROR NIL "We claim to have logged in, but yet we didn't make a default entry. ~
			 This is an internal error.")))))

(DEFUN FILE-NEW-DEFAULT-FILENAME (HOST FILENAME)
  (LET ((AE (ASSOC HOST FILE-HOST-DEFAULTS-ALIST)))
    (COND (AE (RPLACD AE FILENAME))
	  (T (PUSH (CONS HOST FILENAME) FILE-HOST-DEFAULTS-ALIST)))))

(DEFMACRO FILE-BIND-DEFAULTS BODY
  `(LET ((FILE-HOST-DEFAULTS-ALIST (COPYALIST FILE-HOST-DEFAULTS-ALIST))
	 (FILE-DEFAULT-HOST FILE-DEFAULT-HOST))
     . ,BODY))

(DEFUN FILE-CREATE-FILENAME (HOST &REST ARGS &AUX HOST-FLAVOR)
  (SETQ HOST-FLAVOR (CDR (ASSOC HOST HOST-FILENAME-FLAVOR-ALIST)))
  (SETQ ARGS (APPEND ARGS `(:HOST ,HOST)))
  (INSTANTIATE-FLAVOR HOST-FLAVOR (LOCF ARGS) T))

(DEFUN FILE-EXPAND-PATHNAME (PATHNAME)
  (FUNCALL (FILE-PARSE-NAME PATHNAME) ':STRING-FOR-PRINTING))


(DEFUN NULL-FILENAME (&REST IGNORE) "")


;;; Base flavor for all filenames: defaults interesting messages
(DEFFLAVOR FILENAME (HOST) ()
  :GETTABLE-INSTANCE-VARIABLES
  (:INITABLE-INSTANCE-VARIABLES HOST)
  (:INIT-KEYWORDS :NAMESTRING :DEFAULT-FILENAME :DEFAULT-TYPE :SPECIAL-TYPE :HOST-SPECIFIED)
  (:DEFAULT-INIT-PLIST :NAMESTRING "")
  (:REQUIRED-METHODS :DIRECTORY :NAME :TYPE :VERSION :STRING-FOR-HOST
		     :FILE-SYMBOLS :INIT-FILE))

(DEFMETHOD (FILENAME :INIT) (IGNORE)
  (OR (BOUNDP 'HOST)
      (FERROR NIL "Host must be specified when initializating a filename")))

(DEFMETHOD (FILENAME :STRING-FOR-PRINTING) ()
  (FUNCALL-SELF ':STRING-FOR-HOST))

(DEFMETHOD (FILENAME :STRING-FOR-WHOLINE) ()
  (FUNCALL-SELF ':STRING-FOR-PRINTING))

(DEFMETHOD (FILENAME :STRING-FOR-EDITOR) ()
  (FUNCALL-SELF ':STRING-FOR-PRINTING))

(DEFMETHOD (FILENAME :DEVICE) () "DSK")

(DEFMETHOD (FILENAME :DEFAULT-NAMESTRING) (NAMESTRING &OPTIONAL DEFAULT-TYPE)
  (FILE-PARSE-NAME NAMESTRING NIL SELF DEFAULT-TYPE))

(DEFMETHOD (FILENAME :COPY-WITH-TYPE) (NEW-TYPE)
  (FILE-CREATE-FILENAME HOST ':DEFAULT-FILENAME SELF ':SPECIAL-TYPE NEW-TYPE))

;;; PRINC as just the filename itself
(DEFMETHOD (FILENAME :PRINT-SELF) (STREAM IGNORE SLASHIFY-P)
  (IF SLASHIFY-P
      (FORMAT STREAM "#<~A ~S ~O>"
	      (TYPEP SELF) (FUNCALL-SELF ':STRING-FOR-PRINTING) (%POINTER SELF))
      (FUNCALL STREAM ':STRING-OUT (FUNCALL-SELF ':STRING-FOR-PRINTING))))

;;; For those hosts that are on the CHAOS net
(DEFFLAVOR CHAOS-FILENAME () (FILENAME))

(DEFMETHOD (CHAOS-FILENAME :OPEN) (OPTIONS EXCEPTION-HANDLER)
  (OPEN-CHAOS HOST SELF OPTIONS EXCEPTION-HANDLER))

(DEFMETHOD (CHAOS-FILENAME :RENAME) (NEW-NAME ERROR-P)
  (RENAME-CHAOS SELF (FILE-PARSE-NAME NEW-NAME HOST) ERROR-P))

(DEFMETHOD (CHAOS-FILENAME :DELETE) (ERROR-P)
  (DELETE-CHAOS SELF ERROR-P))


;;; ITS hosts
(DEFFLAVOR ITS-FILENAME (DEVICE DIRECTORY NAME FN2) (CHAOS-FILENAME)
  (:GETTABLE-INSTANCE-VARIABLES DEVICE DIRECTORY NAME FN2))

(DEFMETHOD (ITS-FILENAME :STRING-FOR-HOST) ()
  (FORMAT NIL "~A: ~A; ~A ~A" DEVICE DIRECTORY NAME FN2))

(DEFMETHOD (ITS-FILENAME :BEFORE :INIT) (PLIST)
  (LET ((FILENAME (GET PLIST ':NAMESTRING))
	(DEFAULT-FILENAME (GET PLIST ':DEFAULT-FILENAME))
	(NAMELIST))
    (COND ((EQ DEFAULT-FILENAME T)
	   (SETQ DEFAULT-FILENAME (FILE-DEFAULT-FILENAME HOST)))
	  ((NULL DEFAULT-FILENAME)
	   (SETQ DEFAULT-FILENAME 'NULL-FILENAME)))
    ;; Use the currently existing functions to parse an ITS filename
    (SETQ NAMELIST (FILE-SPREAD-ITS-PATHNAME FILENAME))
    (SETQ DEVICE (IF (NULL-S (FIRST NAMELIST))
		     (IF (GET PLIST ':HOST-SPECIFIED)
			 "DSK"
			 (FUNCALL DEFAULT-FILENAME ':DEVICE))		     
		     (FIRST NAMELIST)))
    (AND (OR (STRING-EQUAL DEVICE "DSK") (STRING-EQUAL DEVICE ""))
	 ;; Device is host name if DSK specified
	 (SETQ DEVICE HOST))
    (SETQ DIRECTORY (IF (NULL-S (SECOND NAMELIST))
			(FUNCALL DEFAULT-FILENAME ':DIRECTORY)
			(SECOND NAMELIST)))
    (SETQ NAME (IF (NULL-S (THIRD NAMELIST))
		   (FUNCALL DEFAULT-FILENAME ':NAME)
		   (THIRD NAMELIST)))
    (SETQ FN2 (IF (NULL-S (GET PLIST ':SPECIAL-TYPE))
		  (IF (NULL-S (FOURTH NAMELIST))
		      (IF (NULL-S (GET PLIST ':DEFAULT-TYPE))
			  (IF (TYPEP DEFAULT-FILENAME 'ITS-FILENAME)
			      ;; If this is an ITS filename, use >
			      ">"
			      ;; Otherwise, if the type is TEXT or LISP, then use >
			      (LET ((TYPE (FUNCALL DEFAULT-FILENAME ':TYPE)))
				(IF (MEMBER TYPE '("TEXT" "LISP")) ">" TYPE)))
			  (IF (EQ (GET PLIST ':DEFAULT-TYPE) ':NO-DEFAULT)
			      ""
			      (STRING (GET PLIST ':DEFAULT-TYPE))))
		      (FOURTH NAMELIST))
		  (LET ((TYPE (STRING (GET PLIST ':SPECIAL-TYPE))))
		    (IF (MEMBER TYPE '("TEXT" "LISP")) ">" TYPE))))
    (FILE-NEW-DEFAULT-FILENAME HOST SELF)))

(DEFMETHOD (ITS-FILENAME :TYPE) ()
  (IF (OR (NUMERIC-P FN2)
	  (MEM #'STRING-EQUAL FN2 '(">" "<")))
      "LISP" FN2))

(DEFMETHOD (ITS-FILENAME :VERSION) ()
  (OR (NUMERIC-P FN2) 0))

(DEFMETHOD (ITS-FILENAME :DEVICE) ()
  (IF (STRING-EQUAL HOST DEVICE) "DSK" DEVICE))

(DEFUN NUMERIC-P (STRING)
  (DO ((I 0 (1+ I))
       (LEN (STRING-LENGTH STRING))
       (NUM NIL)
       (CH))
      (( I LEN) NUM)
    (SETQ CH (AREF STRING I))
    (OR (AND ( CH #/0) ( CH #/9))
	(RETURN NIL))
    (SETQ NUM (+ (- CH #/0) (IF NUM (* NUM 10.) 0)))))

(DEFMETHOD (ITS-FILENAME :STRING-FOR-PRINTING) ()
  (ITS-STRING-FOR-PRINTING))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (ITS-FILENAME)
(DEFUN ITS-STRING-FOR-PRINTING ()
  (IF (OR (STRING-EQUAL HOST DEVICE) (STRING-EQUAL DEVICE "DSK"))
      ;; Device and host are the same, or else device is disk
      (FUNCALL-SELF ':STRING-FOR-HOST)
      ;; Otherwise, show both host and device
      (STRING-APPEND HOST ": " (FUNCALL-SELF ':STRING-FOR-HOST)))))

(DEFMETHOD (ITS-FILENAME :FILE-SYMBOLS) ()
  (PROG () (RETURN (INTERN-LOCAL (ITS-STRING-FOR-PRINTING) SI:PKG-FILE-PACKAGE)
		   (LET ((FN2 ">"))
		     (INTERN-LOCAL (ITS-STRING-FOR-PRINTING) SI:PKG-FILE-PACKAGE)))))

(DEFMETHOD (ITS-FILENAME :STRING-FOR-EDITOR) ()
  (FORMAT NIL "~A ~A ~A; ~:[~A: ~;~*~]~A:"
	  NAME FN2 DIRECTORY (STRING-EQUAL DEVICE HOST) HOST DEVICE))

(DEFMETHOD (ITS-FILENAME :INIT-FILE) (PROGRAM-NAME)
  (SETQ NAME (STRING-UPCASE USER-ID)
	FN2 PROGRAM-NAME))

;;; TOPS-20 support
(DEFUN FILE-PARSE-TOPS20-NAMESTRING (NAMESTRING)
  (DO ((START-IDX 0)
       (TEM) (DELIM)
       (DEV) (DIR) (NAME) (TYPE) (VERSION))
      (( START-IDX (STRING-LENGTH NAMESTRING))
       (LIST DEV DIR NAME TYPE VERSION))
    (COND ((= (AREF NAMESTRING START-IDX) #/<)
	   (AND DIR
		(FERROR NIL "Directory occurs twice in ~A" NAMESTRING))
	   (MULTIPLE-VALUE (DIR START-IDX)
	     (TOPS20-STRING-UNTIL-DELIM NAMESTRING (1+ START-IDX) NIL #/>)))
	  (T (MULTIPLE-VALUE (TEM START-IDX DELIM)
	       (TOPS20-STRING-UNTIL-DELIM NAMESTRING START-IDX T #/: #/.))
	     (COND ((= DELIM #/:)
		    (AND DEV
			 (FERROR NIL "Device occurs twice in ~A" NAMESTRING))
		    (SETQ DEV TEM))
		   ((NULL NAME) (SETQ NAME TEM))
		   ((NULL TYPE) (SETQ TYPE TEM))
		   ((NULL VERSION)
		    (IF (SETQ TEM (NUMERIC-P TEM))
			(SETQ VERSION TEM)
			(FERROR NIL "Version must be numeric in ~A" NAMESTRING)))
		   (T (FERROR NIL "Too many points in ~A" NAMESTRING)))))))

(DEFUN TOPS20-STRING-UNTIL-DELIM (STRING IDX EOS-OK &REST DELIMS
				  &AUX (LEN (STRING-LENGTH STRING)))
  (DO ((IDX IDX (1+ IDX))
       (CHAR)
       (NEW-STRING (MAKE-ARRAY NIL 'ART-STRING 30 NIL '(0))))
      (( IDX LEN)
       (OR EOS-OK (FERROR NIL "Illegal end of string in ~A" STRING))
       (PROG () (RETURN NEW-STRING IDX -1)))
    (SETQ CHAR (CHAR-UPCASE (AREF STRING IDX)))
    (COND ((= CHAR #/)
	   ;; TOPS-20 quoting character
	   (ARRAY-PUSH-EXTEND NEW-STRING CHAR)
	   (AND ( (SETQ IDX (1+ IDX)) LEN)
		(FERROR NIL "End of string after quote character in ~A" STRING))
	   (ARRAY-PUSH-EXTEND NEW-STRING (AREF STRING IDX)))
	  ((MEMQ CHAR DELIMS)
	   (RETURN NEW-STRING (1+ IDX) CHAR))
	  (T (ARRAY-PUSH-EXTEND NEW-STRING CHAR)))))

;;; TOPS-20 hosts
(DEFFLAVOR TOPS20-FILENAME (DEVICE DIRECTORY NAME TYPE VERSION) (CHAOS-FILENAME)
  :GETTABLE-INSTANCE-VARIABLES)

(DEFMETHOD (TOPS20-FILENAME :STRING-FOR-HOST) ()
  (FORMAT NIL "~A:<~A>~A.~A~:[.~D~]" DEVICE DIRECTORY NAME TYPE (< VERSION 0) VERSION))

(DEFMETHOD (TOPS20-FILENAME :BEFORE :INIT) (PLIST)
  (LET ((FILENAME (GET PLIST ':NAMESTRING))
	(DEFAULT-FILENAME (GET PLIST ':DEFAULT-FILENAME))
	(NAMELIST))
    (COND ((EQ DEFAULT-FILENAME T)
	   (SETQ DEFAULT-FILENAME (FILE-DEFAULT-FILENAME HOST)))
	  ((NULL DEFAULT-FILENAME)
	   (SETQ DEFAULT-FILENAME 'NULL-FILENAME)))
    (SETQ NAMELIST (FILE-PARSE-TOPS20-NAMESTRING FILENAME))
    (SETQ DEVICE (IF (NULL-S (FIRST NAMELIST))
		     (FUNCALL DEFAULT-FILENAME ':DEVICE)
		     (FIRST NAMELIST)))
    (SETQ DIRECTORY (IF (NULL-S (SECOND NAMELIST))
			(FUNCALL DEFAULT-FILENAME ':DIRECTORY)
			(SECOND NAMELIST)))
    (SETQ NAME (IF (NULL-S (THIRD NAMELIST))
		   (FUNCALL DEFAULT-FILENAME ':NAME)
		   (THIRD NAMELIST)))
    (SETQ TYPE (IF (NOT (NULL-S (GET PLIST ':SPECIAL-TYPE)))
		   (STRING (GET PLIST ':SPECIAL-TYPE))
		   (IF (NULL-S (FOURTH NAMELIST))
		       (IF (NOT (NULL-S (GET PLIST ':DEFAULT-TYPE)))
			   (IF (EQ (GET PLIST ':DEFAULT-TYPE) ':NO-DEFAULT)
			       ""
			       (STRING (GET PLIST ':DEFAULT-TYPE)))
			   (FUNCALL DEFAULT-FILENAME ':TYPE))
		       (FOURTH NAMELIST))))
    ;; Unspecified version defaults to -1, is this right?
    (SETQ VERSION (IF (NULL-S (FIFTH NAMELIST))
		      -1
		      (FIFTH NAMELIST)))
    (FILE-NEW-DEFAULT-FILENAME HOST SELF)))

(DEFMETHOD (TOPS20-FILENAME :STRING-FOR-PRINTING) ()
  (TOPS20-STRING-FOR-PRINTING))

(DEFMETHOD (TOPS20-FILENAME :FILE-SYMBOLS) ()
  (PROG () (RETURN (INTERN-LOCAL (TOPS20-STRING-FOR-PRINTING) SI:PKG-FILE-PACKAGE)
		   (LET ((TYPE "*"))
		     (INTERN-LOCAL (TOPS20-STRING-FOR-PRINTING) SI:PKG-FILE-PACKAGE)))))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (TOPS20-FILENAME)
(DEFUN TOPS20-STRING-FOR-PRINTING ()
  (FORMAT NIL "~A:~A:<~A>~A.~A~:[.~D~;~*~]"
	  HOST DEVICE DIRECTORY NAME TYPE (< VERSION 0) VERSION)))

(DEFMETHOD (TOPS20-FILENAME :STRING-FOR-EDITOR) ()
  (FORMAT NIL "~A.~A~:[.~D~;~*~] ~A:<~A> ~A:"
	  NAME TYPE (< VERSION 0) VERSION DEVICE DIRECTORY HOST))

(DEFMETHOD (TOPS20-FILENAME :INIT-FILE) (PROGRAM-NAME)
  (SETQ NAME PROGRAM-NAME
	TYPE "INIT"))

(COMPILE-FLAVOR-METHODS ITS-FILENAME TOPS20-FILENAME)

;;; This prevent errors when there isn't a default filename yet during system building.
(ADD-INITIALIZATION "NEW-FILE-NAME" '(FILE-LOGIN T) '(ONCE))

(COMMENT ;THIS CODE IS OBSOLETE
;;; Things for processing filenames.
;;; Nobody should know about the syntax of pathnames outside of this page.
;;; Since the format of path lists will change,
;;; nobody should know about them either outside of this page.
;;; The entry points are FILE-EXPAND-PATHNAME, FILE-DEFAULT-FN2,
;;; FILE-SET-FN2.

(DEFVAR FILE-LAST-DEVICE "DSK")
(DEFVAR FILE-LAST-DIRECTORY "LISPM")
(DEFVAR FILE-LAST-FN1 "FOO")
(DEFVAR FILE-DSK-DEVICE-NAME "AI")

;Replace NILs in a path with the defaults.  Also update the
;defaults for the specified parts of the path.
(DEFUN FILE-DEFAULT-PATH (PATH)
    (APPLY (FUNCTION (LAMBDA (DEV DIR FN1 FN2)
	       (AND DEV (SETQ FILE-LAST-DEVICE DEV))
	       (AND DIR (SETQ FILE-LAST-DIRECTORY DIR))
	       (AND FN1 (SETQ FILE-LAST-FN1 FN1))
	       (OR FN2 (SETQ FN2 ">"))
	       (AND (EQUAL FILE-LAST-DEVICE "DSK")
		    (SETQ FILE-LAST-DEVICE FILE-DSK-DEVICE-NAME))
	       (LIST FILE-LAST-DEVICE FILE-LAST-DIRECTORY FILE-LAST-FN1 FN2)))
	   PATH))

;Turn a path list back into a pathname string.
(DEFUN FILE-UNSPREAD-PATH (PATH)
    (OR (THIRD PATH)
	(FERROR NIL "The path ~S contains no FN1" PATH))
    (STRING-APPEND (IF (FIRST PATH) (SIX-CHARACTERS (FIRST PATH)) "")
		   (IF (FIRST PATH) ": " "")
		   (IF (SECOND PATH) (SIX-CHARACTERS (SECOND PATH)) "")
		   (IF (SECOND PATH) "; " "")
		   (SIX-CHARACTERS (THIRD PATH))
		   " "
		   (IF (FOURTH PATH) (SIX-CHARACTERS (FOURTH PATH)) "")))

;Truncate to six characters, knowing about slash and control-Q as quoting characters
(DEFUN SIX-CHARACTERS (STR)
  (DO ((I 0 (1+ I))
       (NCH 0)
       (CH)
       (N (STRING-LENGTH STR)))
      (( I N) STR)
    (SETQ CH (AREF STR I))
    (AND (OR (= CH #// ) (= CH #/)) ;extra space is because editor parses this wrong
	 (SETQ I (1+ I)))	;Quotes next character
    (AND (= (SETQ NCH (1+ NCH)) 6)
	 (< (1+ I) N)
	 (RETURN (SUBSTRING STR 0 (1+ I))))))

;Given a pathname string, default it and return a new pathname string.
; Also, for MACLISP compatibility, will accept MACLISP type LIST file spec lists.
(DEFUN FILE-EXPAND-PATHNAME (PATHNAME)
  (PROG (SPREAD-PATH DEVICE-SPEC)
    (RETURN (COND ((FBOUNDP 'NSUBSTRING)
		   (FILE-UNSPREAD-PATH
		     (FILE-DEFAULT-PATH
		       (PROGN
			 (MULTIPLE-VALUE (SPREAD-PATH DEVICE-SPEC)
			   (FILE-SPREAD-PATHNAME PATHNAME))
			 SPREAD-PATH))))
		  (T PATHNAME))
	    DEVICE-SPEC)))

;Given two pathnames, default missing parts of first from second.
(DEFUN FILE-MERGE-PATHNAMES (PATHNAME1 PATHNAME2)
    (FILE-UNSPREAD-PATH (FILE-MERGE-PATHS (FILE-SPREAD-PATHNAME PATHNAME1)
					  (FILE-SPREAD-PATHNAME PATHNAME2))))

;Internal merge function.
(DEFUN FILE-MERGE-PATHS (PATH1 PATH2)
   (DO ((L1 PATH1 (CDR L1))
	(L2 PATH2 (CDR L2))
	(NPATH))
       ((NULL L2) (NREVERSE NPATH))
     (PUSH (OR (CAR L1) (CAR L2)) NPATH)))

;Old name for file-expand-pathname.
(DEFUN FILE-DEFAULT-FILENAMES (FILENAME)
    (FILE-EXPAND-PATHNAME FILENAME))

;Given a pathname string, return a new one like it with the FN2 defaulted
;to the default we specify, unless there was an FN2 in the original.     
(DEFUN FILE-DEFAULT-FN2 (PATHNAME DEFAULT-FN2 &AUX PATH)
    (COND ((FBOUNDP 'NSUBSTRING)
	   (SETQ PATH (FILE-SPREAD-PATHNAME PATHNAME))
	   (OR (FOURTH PATH) (SETF (FOURTH PATH) DEFAULT-FN2))
	   (FILE-UNSPREAD-PATH PATH))
	  (T PATHNAME)))

;Given a pathname string, return a new one like it but with the fn2
;replaced.
(DEFUN FILE-SET-FN2 (PATHNAME FN2)
   (FILE-UNSPREAD-PATH (LET ((PATH (FILE-SPREAD-PATHNAME PATHNAME)))
			 (SETF (FOURTH PATH) FN2)
			 PATH)))
);COMMENT
