;;
;; Tests for subtle effects of loading and autoloading
;;

(use gauche.test)

(test-start "load")

(add-load-path ".")

;;----------------------------------------------------------------
(test-section "require and provide")

(sys-system "rm -rf test.o")
(sys-mkdir "test.o" #o777)
(with-output-to-file "test.o/a.scm"
  (lambda ()
    (write '(provide "test.o/a"))
    (newline)))

(test* "double require"
       #t
       (begin
         (eval '(require "test.o/a") (interaction-environment))
         (sys-unlink "test.o/a.scm")
         (eval '(require "test.o/a") (interaction-environment))
         #t))

(sys-system "rm -rf test.o")
(sys-mkdir "test.o" #o777)
(with-output-to-file "test.o/b.scm"
  (lambda ()
    (write '(require "test.o/c"))
    (write '(provide "test.o/b"))
    (newline)))
(with-output-to-file "test.o/c.scm"
  (lambda ()
    (write '(require "test.o/b"))
    (write '(provide "test.o/c"))
    (newline)))

(test* "detecting loop of require"
       *test-error*
       (eval '(require "test.o/b") (interaction-environment)))

(sys-system "rm -rf test.o")
(sys-mkdir "test.o" #o777)
(with-output-to-file "test.o/d.scm"
  (lambda ()
    (display "(define z 0)(")
    (newline)))

(test "reload after error"
      1
      (lambda ()
        (with-error-handler
         (lambda (e) #t)
         (lambda ()
           (eval '(require "test.o/d") (interaction-environment))))
        (with-output-to-file "test.o/d.scm"
          (lambda ()
            (write '(define z 1))
            (write '(provide "tset.o/d"))))
        (eval '(require "test.o/d") (interaction-environment))
        (eval 'z (interaction-environment))))

;; :environment arg -------------------------------------
(test-section "load environment")

(with-output-to-file "test.o/d.scm"
  (lambda ()
    (display "(define foo 3)")))
(define-module load.test )
(define foo 8)

(test* ":environment argument"
      3
      (begin
        (load "test.o/d" :environment (find-module 'load.test))
        (with-module load.test foo)))

;; a compicated case involving eval, load and restoration of environment.
;; this is actually testing code in Scm_VMEval, but I put it here
;; since the 'eval' test is done before i/o.
(with-output-to-file "test.o/d.scm"
  (lambda ()
    (display "(define foo 6)")))

(test* "eval & load & environment" 6
       (begin
         (eval '(load "test.o/d") (find-module 'load.test))
         (with-module load.test foo)))


;; autoloading -----------------------------------------
(test-section "autoload")

(with-output-to-file "test.o/l0.scm"
  (lambda ()
    (write '(define foo 0))))
(autoload "test.o/l0" foo)
(test* "autoload (file)" 0 foo)

(with-output-to-file "test.o/l1.scm"
  (lambda ()
    (write '(define foo 0))))
(autoload "test.o/l1" foo1)
(test* "autoload (file/error)" *test-error* foo1)

(sys-system "rm -rf test.o")

;; library utilities -----------------------------------

(test-section "libutil")

(sys-system "mkdir test.o")

(let* ((arch (gauche-architecture))
       (len  (string-length arch)))
  (if (and (> len 7)
	   (string=? (substring arch (- len 7) len) "mingw32"))
      (begin
	;; NB: we use Windows' mkdir command, so we need to use backslashes!
        ;; sys-mkdir isn't tested yet so we can't use it.
	(sys-system "mkdir test.o\\_test")
	(sys-system "mkdir test.o\\_tset"))
      (begin
	(sys-system "mkdir test.o/_test")
	(sys-system "mkdir test.o/_tset"))))

(with-output-to-file "test.o/_test.scm"
  (lambda ()
    (write '(define-module _test ))
    (write '(provide "_test"))))

(with-output-to-file "test.o/_test/_test.scm"
  (lambda ()
    (write '(define-module _test._test ))
    (write '(provide "_test/_test"))))

(with-output-to-file "test.o/_test/_test1.scm"
  (lambda ()
    (write '(define-module _test._test1 ))
    (write '(provide "_test/_test2"))))

(with-output-to-file "test.o/_tset/_test.scm"
  (lambda ()
    (write '(define-module _tset._test ))
    (write '(provide "_tset/_test"))))

(with-output-to-file "test.o/_tset/_test1"
  (lambda ()
    (write '(define-module dummy ))))

(with-output-to-file "test.o/_tset/_test2.scm"
  (lambda ()
    (write '(provide "_tset/_test2"))))

(test* "library-fold _test" '((_test . "test.o/_test.scm"))
       (library-fold '_test acons '() :paths '("./test.o")))

(test* "library-fold _test" '(("_test" . "test.o/_test.scm"))
       (library-fold "_test" acons '() :paths '("./test.o")))

(define paths-a '("./test.o" "./test.o/_test" "./test.o/_tset"))
(define paths-b '("./test.o/_test" "./test.o" "./test.o/_tset"))

(test* "library-fold _test (multi)" '((_test . "test.o/_test.scm"))
       (library-fold '_test acons '() :paths paths-a))
(test* "library-fold _test (multi)" '((_test . "test.o/_test.scm"))
       (library-fold '_test acons '() :paths paths-b))
(test* "library-fold _test (multi)" '(("_test" . "test.o/_test/_test.scm"))
       (library-fold "_test" acons '() :paths paths-b))
(test* "library-fold _test (multi)" '(("_test" . "test.o/_tset/_test.scm")
                                      ("_test" . "test.o/_test.scm")
                                      ("_test" . "test.o/_test/_test.scm"))
       (library-fold "_test" acons '() :paths paths-b
                     :allow-duplicates? #t))
(test* "library-fold _test (non-strict)" '((_test . "test.o/_tset/_test.scm")
                                           (_test . "test.o/_test.scm")
                                           (_test . "test.o/_test/_test.scm"))
       (library-fold '_test acons '() :paths paths-b
                     :strict? #f :allow-duplicates? #t))

(test* "library-fold _test._test" '((_test._test . "test.o/_test/_test.scm"))
       (library-fold '_test._test acons '() :paths paths-b))
(test* "library-fold _test/_test" '(("_test/_test" . "test.o/_test/_test.scm"))
       (library-fold "_test/_test" acons '() :paths paths-b))

;; needs sort the result, for the order library-fold returns depends on
;; readdir(), which may be system dependent.
(test* "library-fold _test.*" '((_test._test . "test.o/_test/_test.scm")
                                (_test._test1 . "test.o/_test/_test1.scm"))
       (sort (library-fold '_test.* acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _tset.*" '((_tset._test . "test.o/_tset/_test.scm"))
       (sort (library-fold '_tset.* acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _tset/*" '(("_tset/_test" . "test.o/_tset/_test.scm")
                                ("_tset/_test2" . "test.o/_tset/_test2.scm"))
       (sort (library-fold "_tset/*" acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))

(test* "library-fold _test.*1" '((_test._test1 . "test.o/_test/_test1.scm"))
       (sort (library-fold '_test.*1 acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _*t._te*" '((_test._test . "test.o/_test/_test.scm")
                                 (_test._test1 . "test.o/_test/_test1.scm")
                                 (_tset._test . "test.o/_tset/_test.scm"))
       (sort (library-fold '_*t._te* acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold */*" '(("_test/_test" . "test.o/_test/_test.scm")
                            ("_test/_test1" . "test.o/_test/_test1.scm")
                            ("_tset/_test" . "test.o/_tset/_test.scm")
                            ("_tset/_test2" . "test.o/_tset/_test2.scm"))
       (sort (library-fold "*/*" acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))

(test* "library-fold _t??t._test?"
       '((_test._test1 . "test.o/_test/_test1.scm"))
       (sort (library-fold '_t??t._test? acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold ?test.?test"
       '((_test._test . "test.o/_test/_test.scm"))
       (sort (library-fold '?test.?test acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _t??t._test?"
       '((_test._test1 . "test.o/_test/_test1.scm")
         (_tset._test2 . "test.o/_tset/_test2.scm"))
       (sort (library-fold '_t??t._test? acons '() :paths paths-b :strict? #f)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _t??t/_test?"
       '(("_test/_test1" . "test.o/_test/_test1.scm")
         ("_tset/_test2" . "test.o/_tset/_test2.scm"))
       (sort (library-fold "_t??t/_test?" acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-fold _t??t?/_test?"
       '()
       (sort (library-fold "_t??t?/_test?" acons '() :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))

(test* "library-map" '((_test._test . "test.o/_test/_test.scm")
                       (_test._test1 . "test.o/_test/_test1.scm"))
       (sort (library-map '_test.* cons :paths paths-b)
             (lambda (a b) (string<? (cdr a) (cdr b)))))
(test* "library-for-each" '((_test._test . "test.o/_test/_test.scm")
                            (_test._test1 . "test.o/_test/_test1.scm"))
       (let ((p '()))
         (library-for-each '_test.*
                           (lambda (x y) (push! p (cons x y)))
                           :paths paths-b)
         (sort p (lambda (a b) (string<? (cdr a) (cdr b))))))

(test* "library-exists? _test" #t
       (not (not (library-exists? '_test :paths paths-b))))
(test* "library-exists? _test1" #f
       (not (not (library-exists? '_test1 :paths paths-b))))
(test* "library-exists? _test1, non-strict" #t
       (not (not (library-exists? '_test1 :paths paths-b :strict? #f))))
(test* "library-exists? _tset._test" #t
       (not (not (library-exists? '_tset._test :paths paths-b :strict? #f))))
(test* "library-exists? \"_test1\"" #t
       (not (not (library-exists? "_test1" :paths paths-b))))
(test* "library-exists? \"_tset/_test2\"" #t
       (not (not (library-exists? "_tset/_test2" :paths paths-b))))
(test* "library-exists? \"_test9\"" #f
       (not (not (library-exists? "_test9" :paths paths-b))))

(test* "library-exists? gauche" #t
       (not (not (library-exists? 'gauche :paths paths-b))))
(test* "library-exists? gauche, force-search" #f
       (not (not (library-exists? 'gauche :paths paths-b :force-search? #t))))
(test* "library-exists? gauche" #f
       (not (not (library-exists? "gauche" :paths paths-b))))
(test* "library-exists? gauche/object" #t
       (not (not (library-exists? "gauche/object" :paths paths-b))))

;; we check module here, since gauche.libutil is autoloaded.
(test-module 'gauche.libutil)

(sys-system "rm -rf test.o")

(test-end)
