;; this test only works when the core system is compiled with euc-jp.

;; $Id: euc-jp.scm,v 1.9 2001-05-31 19:43:30 shirok Exp $

(use gauche.test)

(test-start "EUC-JP")

;;-------------------------------------------------------------------
(test-section "string builtins")

(test "string" "����h�ˤۤ�t"
      (lambda () (string #\�� #\�� #\h #\�� #\�� #\�� #\t)))
(test "list->string" "����h�ˤۤ�t"
      (lambda () (list->string '(#\�� #\�� #\h #\�� #\�� #\�� #\t))))
(test "make-string" "�ؤؤؤؤ�" (lambda () (make-string 5 #\��)))
(test "make-string" "" (lambda () (make-string 0 #\��)))

(test "string->list" '(#\�� #\�� #\h #\�� #\�� #\�� #\t)
      (lambda () (string->list "����h�ˤۤ�t")))
(test "string->list" '(#\�� #\h #\�� #\�� #\�� #\t)
      (lambda () (string->list "����h�ˤۤ�t" 1)))
(test "string->list" '(#\�� #\h #\��)
      (lambda () (string->list "����h�ˤۤ�t" 1 4)))

(test "string-copy" '("����ͤ�" #f)
      (lambda () (let* ((x "����ͤ�") (y (string-copy x)))
                   (list y (eq? x y)))))
(test "string-copy" "��ͤ�" (lambda () (string-copy "����ͤ�" 1)))
(test "string-copy" "���"  (lambda () (string-copy "����ͤ�" 1 3)))

(test "string-ref" #\�� (lambda () (string-ref "�����" 1)))
(define x (string-copy "����Ϥˤ�"))
(test "string-set!" "����Z�ˤ�" (lambda () (string-set! x 2 #\Z) x))

(test "string-fill!" "�ΤΤΤΤΤ�"
      (lambda () (string-fill! (string-copy "000000") #\��)))
(test "string-fill!" "000�ΤΤ�"
      (lambda () (string-fill! (string-copy "000000") #\�� 3)))
(test "string-fill!" "000�Τ�0"
      (lambda () (string-fill! (string-copy "000000") #\�� 3 5)))

(test "string-join" "�դ� �Ф� �Ф�"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�"))))
(test "string-join" "�դ����Ф����Ф�"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�") "��")))
(test "string-join" "�դ������Ф������Ф�"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�") "����" 'infix)))
(test "string-join" ""
      (lambda () (string-join '() "����")))
(test "string-join" "�դ����Ф����Ф���"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�") "��" 'suffix)))
(test "string-join" "���դ����Ф����Ф�"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�") "��" 'prefix)))
(test "string-join" "�դ����Ф����Ф�"
      (lambda () (string-join '("�դ�" "�Ф�" "�Ф�") "��" 'strict-infix)))

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
        (set! sp (make-string-pointer "����Ϥ�ho�ؤ�"))
        (string-pointer? sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
(test "string-pointer-next!" #\��
      (lambda () (string-pointer-next! sp)))
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
(test "string-pointer-substring" '("����Ϥ�ho�ؤ�" "")
      (lambda () (list (string-pointer-substring sp)
                       (string-pointer-substring sp :after #t))))
(test "string-pointer-substring" '("����Ϥ�h" "o�ؤ�")
      (lambda ()
        (string-pointer-set! sp 5)
        (list (string-pointer-substring sp)
              (string-pointer-substring sp :after #t))))
(test "string-pointer-substring" '("" "����Ϥ�ho�ؤ�")
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

(test "string-byte-ref" #xa2 (lambda () (string-byte-ref #"������" 1)))

(test "string-append" #"����������"
      (lambda () (string-append "������" #"����")))
(test "string-append" #"����������"
      (lambda () (string-append #"������" "����")))
(test "string-append" #"����������"
      (lambda () (string-append #"������" #"����")))
(test "string-append" 10
      (lambda () (string-length (string-append "������" "����" #""))))

(test "string-substitute!" #"\xa4bc\xa4"
      (lambda () (string-substitute! (string-copy #"����") 1 #"bc")))

(test "string-incompltet->incomplete" "��"
      (lambda () (string-incomplete->complete
                  (string-append #"\xa4" #"\xa2"))))

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
(test "string-any" #t (lambda () (string-any #[��-��] "��������")))
(test "string-any" #f (lambda () (string-any #[��-��] "��������")))
(test "string-any" #f (lambda () (string-any #[��-��] "")))
(test "string-any" #t (lambda () (string-any (lambda (x) (char-ci=? x #\��)) "���餢")))
(test "string-any" #f (lambda () (string-any (lambda (x) (char-ci=? x #\��)) "���饢")))
(test "string-tabulate" "����������"
      (lambda ()
        (string-tabulate (lambda (code)
                           (integer->char (+ code
                                             (char->integer #\��))))
                         5)))
(test "reverse-list->string" "����"
      (lambda () (reverse-list->string '(#\�� #\�� #\��))))
(test "string-copy!" "ab������fg"
      (lambda () (let ((x (string-copy "abcdefg")))
                   (string-copy! x 2 "������������" 2 5)
                   x)))
(test "string-take" "��������"  (lambda () (string-take "������������" 4)))
(test "string-drop" "����"  (lambda () (string-drop "������������" 4)))
(test "string-take-right" "��������"  (lambda () (string-take-right "������������" 4)))
(test "string-drop-right" "����"  (lambda () (string-drop-right "������������" 4)))
(test "string-pad" "�����ѥå�" (lambda () (string-pad "�ѥå�" 5 #\��)))
(test "string-pad" "�ѥǥ���" (lambda () (string-pad "�ѥǥ���" 5 #\��)))
(test "string-pad" "�ǥ��󥰥�" (lambda () (string-pad "�ѥǥ��󥰥�" 5 #\��)))
(test "string-pad-right" "�ѥåɢ���" (lambda () (string-pad-right "�ѥå�" 5 #\��)))
(test "string-pad" "�ѥǥ���" (lambda () (string-pad-right "�ѥǥ��󥰥�" 5 #\��)))

;;-------------------------------------------------------------------
(test-section "char set")

(use srfi-14)

(test "char-set" #t
      (lambda () (char-set= (char-set #\�� #\�� #\�� #\�� #\��)
                            (string->char-set "����������"))))
(test "char-set" #t
      (lambda () (char-set= (list->char-set '(#\�� #\�� #\�� #\��))
                            (string->char-set "��󤤤���������"))))
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
      '(#xa4 #xa2 #xa4 #xa4 #xa4 #xa6 #xa4 #xa8 #xa4 #xaa
        #xa4 #xab #xa4 #xad #xa4 #xaf #xa4 #xb1 #xa4 #xb3)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 256))))

(test "buffered port (getb, bufsiz=20)"
      '(#xa4 #xa2 #xa4 #xa4 #xa4 #xa6 #xa4 #xa8 #xa4 #xaa
        #xa4 #xab #xa4 #xad #xa4 #xaf #xa4 #xb1 #xa4 #xb3)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 20))))

(test "buffered port (getb, bufsiz=19)"
      '(#xa4 #xa2 #xa4 #xa4 #xa4 #xa6 #xa4 #xa8 #xa4 #xaa
        #xa4 #xab #xa4 #xad #xa4 #xaf #xa4 #xb1 #xa4 #xb3)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 19))))

(test "buffered port (getb, bufsiz=2)"
      '(#xa4 #xa2 #xa4 #xa4 #xa4 #xa6 #xa4 #xa8 #xa4 #xaa
        #xa4 #xab #xa4 #xad #xa4 #xaf #xa4 #xb1 #xa4 #xb3)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 2))))

(test "buffered port (getb, bufsiz=1)"
      '(#xa4 #xa2 #xa4 #xa4 #xa4 #xa6 #xa4 #xa8 #xa4 #xaa
        #xa4 #xab #xa4 #xad #xa4 #xaf #xa4 #xb1 #xa4 #xb3)
      (lambda ()
        (port->byte-list (open-input-buffered-port (make-filler) 1))))

(test "buffered port (getz, siz=20,5)"
      '(#"\xa4\xa2\xa4\xa4\xa4" #"\xa6\xa4\xa8\xa4\xaa"
        #"\xa4\xab\xa4\xad\xa4" #"\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 20) 5)))

(test "buffered port (getz, siz=20,20)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa\xa4\xab\xa4\xad\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 20) 20)))

(test "buffered port (getz, siz=9,20)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa\xa4\xab\xa4\xad\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 9) 20)))

(test "buffered port (getz, siz=9,7)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4" #"\xa8\xa4\xaa\xa4\xab\xa4\xad"
        #"\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 9) 7)))

(test "buffered port (getz, siz=3,50)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa\xa4\xab\xa4\xad\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 3) 50)))

(test "buffered port (getz, siz=2,7)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4" #"\xa8\xa4\xaa\xa4\xab\xa4\xad"
        #"\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 2) 7)))

(test "buffered port (getz, siz=1,7)"
      '(#"\xa4\xa2\xa4\xa4\xa4\xa6\xa4" #"\xa8\xa4\xaa\xa4\xab\xa4\xad"
        #"\xa4\xaf\xa4\xb1\xa4\xb3")
      (lambda ()
        (port->chunk-list (open-input-buffered-port (make-filler) 1) 7)))

(test-end)
