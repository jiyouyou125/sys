;;; Cube input    -*-Package:CUBE; Mode:Lisp-*-
;;; BSG 7/27/80

(multicsp (%include cube-dcls))
(itsp (includef '|bsg;cube dcls|))

(declare (*lexpr cube-inerror cube-input-conserverify))

(defun cube-input ()
       (cursorpos 21. 5)
       (cursorpos 'l)
       (princ '|Type file name for image, end by CR. Type ? for help. |)
       (let ((fresult (errset (readline))))
	    (cursorpos 21. 5)
	    (cursorpos 'l)
	    (cond ((null fresult)
		   (cube-beep))
		  ((or
		     (memq (car (explodec '/?)) (explodec (car fresult)))
		     (equal (car fresult) ""))
		   (princ "Please read and copy ")
		   (princ
		     #+LISPM ">cube>cube.template"
		     #+ITS "AI: BSG; CUBE TEMPLT")
		   (princ " for info")
		   (cursorpos 22. 5)
		   (cursorpos 'l)
		   (princ '|on how to input cube configurations.|))
		  (t (let ((file (errset (open (car fresult) 'in)))
			   (eof (gensym)))
			  (cond ((null file) (cube-beep))
				(t
				 (let ((err
					(catch
					 (progn
					  (cube-input-reader (car file) eof)
					  (close (car file))
					  (setq file nil)
					  (cube-input-check-consistency)
					  nil)
					 cube-input-format-error)))
				      (and err (princ err))
				      #Q(or err
					    (funcall terminal-io ':force-kbd-input
						     #\CLEAR-SCREEN))
				      (and file (close (car file))))))))))
       #Q(progn
	   (cursorpos 23. 5)
	   (cursorpos 'l)
	   (princ "Hit CLEAR SCREEN to clean up this display when done.")))

(defun cube-input-reader (file eof)
       (let ((fnames (cdr (listarray 'face-names))))
	    (do x fnames (cdr x)(null x)
		(remprop (car x) 'cube-face-defined))
	    (do nil (nil)
		(let ((obj (let ((package #Q (pkg-find-package 'cube) #-LISPM nil))
				(read file eof))))
		     (cond ((eq obj eof)(return nil))
			   ((atom obj)
			    (cube-inerror '|random symbol floating around in file: | obj))
			   (t (let ((key (car obj)))
				   (cond ((not (symbolp key))
					  (cube-inerror '|bad header: | (maknam (explode key))))
					 ((eq key 'END)(return nil))
					 ((memq key '(INTRODUCTION comment)))
					 ((not (memq key fnames))
					  (cube-inerror  '|meaningless face-name: | key))
					 ((get key 'cube-face-defined)
					  (cube-inerror '|multiply-defined face: | key))
					 (t
					  (cube-input-get-face file eof key))))))))
	    (do x fnames (cdr x)(null x)
		(let ((f (car x)))
		     (or (get f 'cube-face-defined)
			 (cube-inerror '|cube face not defined: | f))))))

(defun cube-input-get-face (file eof face)
       (do ((i 1 (1+ i))
	    (facenum (symeval face))
	    (clist nil))
	   ((> i 9.)
	    (setq clist (nreverse clist))
	    (let  ((tchoice (cond ((= facenum TOP) BACK)
				  ((= facenum BOTTOM) FRONT)
				  (t TOP))))
		  (1to3 row
			(1to3 col
			      (let (((row col)(cube-xy-inverse-transform facenum tchoice row col)))
				   (store (cube facenum row col) (car clist))
				   (setq clist (cdr clist))))))
	    (putprop face t 'cube-face-defined))
	   (let ((obj (let ((package #Q (pkg-find-package 'cube) #-LISPM nil))
			   (read file eof))))
		(cond ((eq obj eof)
		       (cube-inerror '|end of file while reading in | face))
		      ((not (symbolp obj))
		       (cube-inerror '|Invalid object in | face '| description: |
				     (maknam (explode obj))))
		      ((> (flatc obj) 6)
		       (cube-inerror '|Invalid color: | obj '| > 6 chars|))
		      (t (setq obj (or (cdr (assq obj
						  '((r . red)(o . orange)(y . yellow)(g. green)
							     (b . blue)(i . indigo)(v . violet)
							     (w . white)(blu . blue)(blk . black)(brn . brown))))
				       obj))
			 (setq clist (cons obj clist)))))))

(defun cube-input-check-consistency ()
       (all-faces f1
		  (all-faces f2
			     (let ((c1 (cube f1 2 2))
				   (c2 (cube f2 2 2)))
				  (and (eq c1 c2)
				       (not (= f1 f2))
				       (cube-inerror '|Color | c1 '| duplicated in centers of |
						     (face-names f1) '| and | (face-names f2))))))
       (all-faces f
		  (store (colors f)(cube f 2 2)))
       (let ((cs (cdr (listarray 'colors))))
	    (all-faces f
		       (all-little-faces (y z)
					 (or (memq (cube f y z) cs)
					     (cube-inerror
					      '|Color | (cube f y z)
					      '| in | (face-names f)
					      '| is not in the center of any face.|)))))
       (all-faces f
		  (let ((hoc (cube f 2 2))
			(topc (cube (face-clock-relations f 1) 2 2))
			(rightc (cube (face-clock-relations f 2) 2 2))
			(bottomc (cube (face-clock-relations f 3) 2 2))
			(leftc (cube (face-clock-relations f 4) 2 2)))
		       (cube-input-conserverify hoc topc)
		       (cube-input-conserverify hoc rightc)
		       (cube-input-conserverify hoc bottomc)
		       (cube-input-conserverify hoc leftc)

		       (cube-input-conserverify hoc topc rightc)
		       (cube-input-conserverify hoc topc leftc)
		       (cube-input-conserverify hoc bottomc rightc)
		       (cube-input-conserverify hoc bottomc leftc))))

(defun cube-input-conserverify n
       (or (find-cubie (listify n))
	   (cube-inerror '|Cubie apparently missing: | (listify n))))

(defun cube-inerror n
       (cube-beep)
       (*throw 'cube-input-format-error
	       (maknam (apply 'nconc (mapcar 'explodec (listify n))))))

(defun cube-beep ()
  (cond ((status feature lispm)
	 (tv:beep))
	((tyo 7))))

#Q(defun cbarf (&rest ignore)
    (ferror nil "Illegally put-together cube."))