;;;
;;; base64.scm - base64 encoding/decoding routine
;;;  
;;;   Copyright (c) 2000-2003 Shiro Kawai, All rights reserved.
;;;   
;;;   Redistribution and use in source and binary forms, with or without
;;;   modification, are permitted provided that the following conditions
;;;   are met:
;;;   
;;;   1. Redistributions of source code must retain the above copyright
;;;      notice, this list of conditions and the following disclaimer.
;;;  
;;;   2. Redistributions in binary form must reproduce the above copyright
;;;      notice, this list of conditions and the following disclaimer in the
;;;      documentation and/or other materials provided with the distribution.
;;;  
;;;   3. Neither the name of the authors nor the names of its contributors
;;;      may be used to endorse or promote products derived from this
;;;      software without specific prior written permission.
;;;  
;;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;;   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;;   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;;   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;;   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;;   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;;  
;;;  $Id: base64.scm,v 1.8 2003-07-05 03:29:11 shirok Exp $
;;;

;; Implements Base64 encoding/decoding routine
;; Ref: RFC2045 section 6.8  <http://www.rfc-editor.org/rfc/rfc2045.txt>

(define-module rfc.base64
  (use srfi-2)
  (export base64-encode base64-encode-string
          base64-decode base64-decode-string))
(select-module rfc.base64)

(define *decode-table*
  ;;    !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /
  #(#f  #f  #f  #f  #f  #f  #f  #f  #f  #f  #f  62  #f  #f  #f  63  
  ;;0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?
    52  53  54  55  56  57  58  59  60  61  #f  #f  #f  #f  #f  #f
  ;;@   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O
    #f  0   1   2   3   4   5   6   7   8   9   10  11  12  13  14
  ;;P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _
    15  16  17  18  19  20  21  22  23  24  25  #f  #f  #f  #f  #f
  ;;`   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o
    #f  26  27  28  29  30  31  32  33  34  35  36  37  38  39  40
  ;;p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~
    41  42  43  44  45  46  47  48  49  50  51  #f  #f  #f  #f  #f
  ))

(define *encode-table*
  ;;0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15
  #(#\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M #\N #\O #\P
  ;;16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31
    #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z #\a #\b #\c #\d #\e #\f
  ;;32  33  34  35  36  37  38  39  40  41  42  43  44  45  46  47
    #\g #\h #\i #\j #\k #\l #\m #\n #\o #\p #\q #\r #\s #\t #\u #\v
  ;;48  49  50  51  52  53  54  55  56  57  58  59  60  61  62  63
    #\w #\x #\y #\z #\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\+ #\/
  ))

(define (base64-decode)
  (let-syntax ((lookup (syntax-rules ()
                         ((_ c)
                          (let ((i (char->integer c)))
                            (and (< 32 i 128)
                                 (vector-ref *decode-table* (- i 32)))))))
               )
    (define (d0 c)
      (cond ((eof-object? c))
            ((eqv? c #\=))
            ((lookup c) => (lambda (v) (d1 (read-char) v)))
            (else (d0 (read-char)))))

    (define (d1 c hi)
      (cond ((eof-object? c))
            ((eqv? c #\=))
            ((lookup c) => (lambda (lo)
                             (write-byte (+ (* hi 4) (quotient lo 16)))
                             (d2 (read-char) (modulo lo 16))))
            (else (d1 (read-char) hi))))

    (define (d2 c hi)
      (cond ((eof-object? c))
            ((eqv? c #\=))
            ((lookup c) => (lambda (lo)
                             (write-byte (+ (* hi 16) (quotient lo 4)))
                             (d3 (read-char) (modulo lo 4))))
            (else (d2 (read-char) hi))))

    (define (d3 c hi)
      (cond ((eof-object? c))
            ((eqv? c #\=))
            ((lookup c) => (lambda (lo)
                             (write-byte (+ (* hi 64) lo))
                             (d0 (read-char))))
            (else (d3 (read-char) hi))))

    (d0 (read-char))))

(define (base64-decode-string string)
  (with-output-to-string
    (lambda ()
      (with-input-from-string string base64-decode))))


(define (base64-encode)
  (let-syntax ((emit (syntax-rules ()
                       ((_ idx)
                        (write-char (vector-ref *encode-table* idx))))))
    (define (e0 c cnt)
      (if (eof-object? c)
          #t
          (begin (emit (quotient c 4))
                 (e1 (read-byte) (modulo c 4) cnt))))

    (define (e1 c hi cnt)
      (if (eof-object? c)
          (begin (emit (* hi 16))
                 (write-char #\=)
                 (write-char #\=))
          (begin (emit (+ (* hi 16) (quotient c 16)))
                 (e2 (read-byte) (modulo c 16) cnt))))

    (define (e2 c hi cnt)
      (if (eof-object? c)
          (begin (emit (* hi 4))
                 (write-char #\=))
          (begin (emit (+ (* hi 4) (quotient c 64)))
                 (emit (modulo c 64))
                 (if (= cnt 17)
                     (begin (newline)
                            (e0 (read-byte) 0))
                     (e0 (read-byte) (+ cnt 1))))))

    (e0 (read-byte) 0)))

(define (base64-encode-string string)
  (with-output-to-string
    (lambda ()
      (with-input-from-string string base64-encode))))

(provide "rfc/base64")

