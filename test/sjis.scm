;; this test only works when the core system is compiled with shift-jis.

;; $Id: sjis.scm,v 1.1 2001-12-23 01:37:33 shirok Exp $

(use gauche.test)

(test-start "SJIS")
(use srfi-1)

;;-------------------------------------------------------------------
(test-section "string builtins")

(test "string" "����h�ɂق�t"
      (lambda () (string #\�� #\�� #\h #\�� #\�� #\�� #\t)))
(test "list->string" "����h�ɂق�t"
      (lambda () (list->string '(#\�� #\�� #\h #\�� #\�� #\�� #\t))))
(test "make-string" "�ււււ�" (lambda () (make-string 5 #\��)))
(test "make-string" "" (lambda () (make-string 0 #\��)))

(test "string->list" '(#\�� #\�� #\h #\�� #\�� #\�� #\t)
      (lambda () (string->list "����h�ɂق�t")))
(test "string->list" '(#\�� #\h #\�� #\�� #\�� #\t)
      (lambda () (string->list "����h�ɂق�t" 1)))
(test "string->list" '(#\�� #\h #\��)
      (lambda () (string->list "����h�ɂق�t" 1 4)))

(test "string-copy" '("����˂�" #f)
      (lambda () (let* ((x "����˂�") (y (string-copy x)))
                   (list y (eq? x y)))))
(test "string-copy" "��˂�" (lambda () (string-copy "����˂�" 1)))
(test "string-copy" "���"  (lambda () (string-copy "����˂�" 1 3)))

(test "string-ref" #\�� (lambda () (string-ref "�����" 1)))
(define x (string-copy "����͂ɂ�"))
(test "string-set!" "����Z�ɂ�" (lambda () (string-set! x 2 #\Z) x))

(test "string-fill!" "�̂̂̂̂̂�"
      (lambda () (string-fill! (string-copy "000000") #\��)))
(test "string-fill!" "000�̂̂�"
      (lambda () (string-fill! (string-copy "000000") #\�� 3)))
(test "string-fill!" "000�̂�0"
      (lambda () (string-fill! (string-copy "000000") #\�� 3 5)))

(test "string-join" "�ӂ� �΂� �΂�"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�"))))
(test "string-join" "�ӂ��I�΂��I�΂�"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�") "�I")))
(test "string-join" "�ӂ������΂������΂�"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�") "����" 'infix)))
(test "string-join" ""
      (lambda () (string-join '() "����")))
(test "string-join" "�ӂ��I�΂��I�΂��I"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�") "�I" 'suffix)))
(test "string-join" "�I�ӂ��I�΂��I�΂�"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�") "�I" 'prefix)))
(test "string-join" "�ӂ��I�΂��I�΂�"
      (lambda () (string-join '("�ӂ�" "�΂�" "�΂�") "�I" 'strict-infix)))

(test "string-scan" 7
      (lambda () (string-scan "��������������������������" "������")))
(test "string-scan" "��������������"
      (lambda () (string-scan "��������������������������" "������" 'before)))
(test "string-scan" "������"
      (lambda () (string-scan "��������������������������" "������" 'after)))
(test "string-scan" '("��������������" "������������")
      (lambda ()
        (receive r (string-scan "��������������������������" "������" 'before*) r)))
(test "string-scan" '("��������������������" "������")
      (lambda ()
        (receive r (string-scan "��������������������������" "������" 'after*) r)))
(test "string-scan" '("��������������" "������")
      (lambda ()
        (receive r (string-scan "��������������������������" "������" 'both) r)))
(test "string-scan" #f
      (lambda () (string-scan "��������������������������" "����")))

(test "string-substitute!" "������defghi"
      (lambda ()
        (let ((s (string-copy "abcdefghi")))
          (string-substitute! s 0 "������")
          s)))
(test "string-substitute!" "abc������ghi"
      (lambda ()
        (let ((s (string-copy "abcdefghi")))
          (string-substitute! s 3 "������")
          s)))

;;-------------------------------------------------------------------
(test-section "string-pointer")
(define sp #f)
(test "make-string-pointer" #t
      (lambda ()
        (set! sp (make-string-pointer "����͂�ho�ւ�"))
        (string-pointer? sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\h
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\o
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-prev!" #\��
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\o
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\h
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\��
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\��
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\��
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #\��
      (lambda () (string-pointer-prev! sp)))
(test "string-pointer-prev!" #t
      (lambda () (eof-object? (string-pointer-prev! sp))))
(test "string-pointer-index" 0
      (lambda () (string-pointer-index sp)))
(test "string-pointer-index" 8
      (lambda () (do ((x (string-pointer-next! sp) (string-pointer-next! sp)))
                     ((eof-object? x) (string-pointer-index sp)))))
(test "string-pointer-substring" '("����͂�ho�ւ�" "")
      (lambda () (list (string-pointer-substring sp)
                       (string-pointer-substring sp :after #t))))
(test "string-pointer-substring" '("����͂�h" "o�ւ�")
      (lambda ()
        (string-pointer-set! sp 5)
        (list (string-pointer-substring sp)
              (string-pointer-substring sp :after #t))))
(test "string-pointer-substring" '("" "����͂�ho�ւ�")
      (lambda ()
        (string-pointer-set! sp 0)
        (list (string-pointer-substring sp)
              (string-pointer-substring sp :after #t))))

;;-------------------------------------------------------------------
(test-section "incomplete strings")

(test "string-length" 6 (lambda () (string-length #"������")))
(test "string-complete->incomplete" #"������" 
      (lambda () (string-complete->incomplete "������")))
(test "string-complete->incomplete" #"������"
      (lambda () (string-complete->incomplete #"������")))
(test "string-incomplete->complete" "������"
      (lambda () (string-incomplete->complete #"������")))
(test "string-incomplete->complete" "������"
      (lambda () (string-incomplete->complete "������")))

(test "string=?" #t (lambda () (string=? #"������" #"������")))

(test "string-byte-ref" #xa0 (lambda () (string-byte-ref #"������" 1)))

(test "string-append" #"����������"
      (lambda () (string-append "������" #"����")))
(test "string-append" #"����������"
      (lambda () (string-append #"������" "����")))
(test "string-append" #"����������"
      (lambda () (string-append #"������" #"����")))
(test "string-append" 10
      (lambda () (string-length (string-append "������" "����" #""))))

(test "string-substitute!" #"\x82bc\xa2"
      (lambda () (string-substitute! (string-copy #"����") 1 #"bc")))

(test "string-incompltet->incomplete" "��"
      (lambda () (string-incomplete->complete
                  (string-append #"\x82" #"\xa0"))))

;;-------------------------------------------------------------------
(test-section "string-library")
(use srfi-13)

(test "string-every" #t (lambda () (string-every #\�� "")))
(test "string-every" #t (lambda () (string-every #\�� "��������")))
(test "string-every" #f (lambda () (string-every #\�� "������a")))
(test "string-every" #t (lambda () (string-every #[��-��] "��������")))
(test "string-every" #f (lambda () (string-every #[��-��] "����a��")))
(test "string-every" #t (lambda () (string-every #[��-��] "")))
(test "string-every" #t (lambda () (string-every (lambda (x) (char-ci=? x #\��)) "��������")))
(test "string-every" #f (lambda () (string-every (lambda (x) (char-ci=? x #\��)) "��������")))

(test "string-any" #t (lambda () (string-any #\�� "��������")))
(test "string-any" #f (lambda () (string-any #\�� "��������")))
(test "string-any" #f (lambda () (string-any #\�� "")))
(test "string-any" #t (lambda () (string-any #[��-��] "�����[��")))
(test "string-any" #f (lambda () (string-any #[��-��] "�X�L�[��")))
(test "string-any" #f (lambda () (string-any #[��-��] "")))
(test "string-any" #t (lambda () (string-any (lambda (x) (char-ci=? x #\��)) "���炠")))
(test "string-any" #f (lambda () (string-any (lambda (x) (char-ci=? x #\��)) "�������A")))
(test "string-tabulate" "�A�B�C�D�E"
      (lambda ()
        (string-tabulate (lambda (code)
                           (integer->char (+ code
                                             (char->integer #\�A))))
                         5)))
(test "reverse-list->string" "�����"
      (lambda () (reverse-list->string '(#\�� #\�� #\��))))
(test "string-copy!" "ab������fg"
      (lambda () (let ((x (string-copy "abcdefg")))
                   (string-copy! x 2 "������������" 2 5)
                   x)))
(test "string-take" "��������"  (lambda () (string-take "������������" 4)))
(test "string-drop" "����"  (lambda () (string-drop "������������" 4)))
(test "string-take-right" "��������"  (lambda () (string-take-right "������������" 4)))
(test "string-drop-right" "����"  (lambda () (string-drop-right "������������" 4)))
(test "string-pad" "�����p�b�h" (lambda () (string-pad "�p�b�h" 5 #\��)))
(test "string-pad" "�p�f�B���O" (lambda () (string-pad "�p�f�B���O" 5 #\��)))
(test "string-pad" "�f�B���O�X" (lambda () (string-pad "�p�f�B���O�X" 5 #\��)))
(test "string-pad-right" "�p�b�h����" (lambda () (string-pad-right "�p�b�h" 5 #\��)))
(test "string-pad" "�p�f�B���O" (lambda () (string-pad-right "�p�f�B���O�X" 5 #\��)))

;;-------------------------------------------------------------------
(test-section "char set")

(use srfi-14)

(test "char-set" #t
      (lambda () (char-set= (char-set #\�� #\�� #\�� #\�� #\��)
                            (string->char-set "����������"))))
(test "char-set" #t
      (lambda () (char-set= (list->char-set '(#\�� #\�� #\�� #\��))
                            (string->char-set "��񂢂���������"))))
(test "char-set" #t
      (lambda () (char-set<= (list->char-set '(#\�� #\��))
                             char-set:full)))
(test "char-set" #t
      (lambda ()
        (char-set= (->char-set "������������������")
                   (integer-range->char-set (char->integer #\��)
                                            (char->integer #\��)))))


;;-------------------------------------------------------------------
(test-section "buffered ports")

(define (make-filler)
  (let* ((str #"��������������������")  ;incomplete string
         (len (string-size str))
         (ind 0))
    (lambda (siz)
      (cond ((>= ind len) #f)
            ((>= (+ ind siz) len)
             (let ((r (substring str ind len)))
               (set! ind len)
               r))
            (else
             (let ((r (substring str ind (+ ind siz))))
               (set! ind (+ ind siz))
               r))))))

(define (port->char-list p)
  (let loop ((c (read-char p)) (r '()))
    (if (eof-object? c) (reverse r) (loop (read-char p) (cons c r)))))

(define (port->byte-list p)
  (let loop ((b (read-byte p)) (r '()))
    (if (eof-object? b) (reverse r) (loop (read-byte p) (cons b r)))))

(define (port->chunk-list p siz)
  (let loop ((b (read-block siz p)) (r '()))
    (if (eof-object? b) (reverse r) (loop (read-block siz p) (cons b r)))))

(test "buffered port (getc, bufsiz=256)"
      '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��)
      (lambda ()
        (port->char-list (open-input-buffered-port (make-filler) 256))))

(test "buffered port (getc, bufsiz=7)"
      '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��)
      (lambda ()
        (port->char-list (open-input-buffered-port (make-filler) 7))))

(test "buffered port (getc, bufsiz=3)"
      '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��)
      (lambda ()
        (port->char-list (open-input-buffered-port (make-filler) 3))))

(test "buffered port (getc, bufsiz=2)"
      '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��)
      (lambda ()
        (port->char-list (open-input-buffered-port (make-filler) 2))))

(test "buffered port (getc, bufsiz=1)"
      '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��)
      (lambda ()
        (port->char-list (open-input-buffered-port (make-filler) 1))))

(test "buffered port (getb, bufsiz=256)"
      '(#x82 #xa0 #x82 #xa2 #x82 #xa4 #x82 #xa6 #x82 #xa8
        #x82 #xa9 #x82 #xab #x82 #xad #x82 #xaf #x82 #xb1)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 256))))

(test "buffered port (getb, bufsiz=20)"
      '(#x82 #xa0 #x82 #xa2 #x82 #xa4 #x82 #xa6 #x82 #xa8
        #x82 #xa9 #x82 #xab #x82 #xad #x82 #xaf #x82 #xb1)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 20))))

(test "buffered port (getb, bufsiz=19)"
      '(#x82 #xa0 #x82 #xa2 #x82 #xa4 #x82 #xa6 #x82 #xa8
        #x82 #xa9 #x82 #xab #x82 #xad #x82 #xaf #x82 #xb1)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 19))))

(test "buffered port (getb, bufsiz=2)"
      '(#x82 #xa0 #x82 #xa2 #x82 #xa4 #x82 #xa6 #x82 #xa8
        #x82 #xa9 #x82 #xab #x82 #xad #x82 #xaf #x82 #xb1)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 2))))

(test "buffered port (getb, bufsiz=1)"
      '(#x82 #xa0 #x82 #xa2 #x82 #xa4 #x82 #xa6 #x82 #xa8
        #x82 #xa9 #x82 #xab #x82 #xad #x82 #xaf #x82 #xb1)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 1))))

(test "buffered port (getz, siz=20,5)"
      '(#"\x82\xa0\x82\xa2\x82" #"\xa4\x82\xa6\x82\xa8"
        #"\x82\xa9\x82\xab\x82" #"\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 20) 5)))

(test "buffered port (getz, siz=20,20)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8\x82\xa9\x82\xab\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 20) 20)))

(test "buffered port (getz, siz=9,20)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8\x82\xa9\x82\xab\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 9) 20)))

(test "buffered port (getz, siz=9,7)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82" #"\xa6\x82\xa8\x82\xa9\x82\xab"
        #"\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 9) 7)))

(test "buffered port (getz, siz=3,50)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8\x82\xa9\x82\xab\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 3) 50)))

(test "buffered port (getz, siz=2,7)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82" #"\xa6\x82\xa8\x82\xa9\x82\xab"
        #"\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 2) 7)))

(test "buffered port (getz, siz=1,7)"
      '(#"\x82\xa0\x82\xa2\x82\xa4\x82" #"\xa6\x82\xa8\x82\xa9\x82\xab"
        #"\x82\xad\x82\xaf\x82\xb1")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 1) 7)))

(define *flusher-out* '())

(define (flusher str)
  (if str
      (set! *flusher-out* (cons str *flusher-out*))
      (set! *flusher-out* (string-concatenate-reverse *flusher-out*))))

(define (byte-list->port p bytes)
  (set! *flusher-out* '())
  (for-each (lambda (b) (write-byte b p)) bytes)
  (close-output-port p)
  *flusher-out*)

(define (char-list->port p chars)
  (set! *flusher-out* '())
  (for-each (lambda (c) (write-char c p)) chars)
  (close-output-port p)
  *flusher-out*)

(define (string-list->port p strs)
  (set! *flusher-out* '())
  (for-each (lambda (s) (display s p)) strs)
  (close-output-port p)
  *flusher-out*)

(test "buffered port (putb, bufsiz=7)"
      #"@ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      (lambda ()
        (byte-list->port (open-output-buffered-port flusher 7)
                         (iota 27 #x40))))

(test "buffered port (putb, bufsiz=30)"
      #"@ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      (lambda ()
        (byte-list->port (open-output-buffered-port flusher 30)
                         (iota 27 #x40))))

(test "buffered port (putc, bufsiz=7)"
      #"������������������������������"
      (lambda ()
        (char-list->port (open-output-buffered-port flusher 7)
                         '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��
                           #\�� #\�� #\�� #\�� #\��))))

(test "buffered port (putc, bufsiz=30)"
      #"������������������������������"
      (lambda ()
        (char-list->port (open-output-buffered-port flusher 30)
                         '(#\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\�� #\��
                           #\�� #\�� #\�� #\�� #\��))))

(test "buffered port (puts, bufsiz=6)"
      #"������������������������������"
      (lambda ()
        (string-list->port (open-output-buffered-port flusher 6)
                           '("������" "������" "������" "������" "������"))))

(test "buffered port (puts, bufsiz=7)"
      #"������������������������������"
      (lambda ()
        (string-list->port (open-output-buffered-port flusher 7)
                           '("������" "������" "������" "������" "������"))))

(test "buffered port (puts, bufsiz=7)"
      #"������������������������������"
      (lambda ()
        (string-list->port (open-output-buffered-port flusher 7)
                           '("����������" "����������" "��������" "��"))))

(test "buffered port (puts, bufsiz=3)"
      #"������������������������������"
      (lambda ()
        (string-list->port (open-output-buffered-port flusher 3)
                           '("����������" "����������" "��������" "��"))))

(test-end)
