;; this test only works when the core system is compiled with euc-jp.

;; $Id: euc-jp.scm,v 1.4 2001-05-01 10:27:26 shirok Exp $

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

(test "string-ref" #\�� (lambda () (string-ref "�����" 1)))
(define x (string-copy "����Ϥˤ�"))
(test "string-set!" "����Z�ˤ�" (lambda () (string-set! x 2 #\Z) x))

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

;; char-set

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


(test-end)
