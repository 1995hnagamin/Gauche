;;;
;;; logical.scm - logical (bitwise) operations.  to be autoloaded.
;;;
;;;  Copyright(C) 2001 by Shiro Kawai (shiro@acm.org)
;;;
;;;  Permission to use, copy, modify, distribute this software and
;;;  accompanying documentation for any purpose is hereby granted,
;;;  provided that existing copyright notices are retained in all
;;;  copies and that this notice is included verbatim in all
;;;  distributions.
;;;  This software is provided as is, without express or implied
;;;  warranty.  In no circumstances the author(s) shall be liable
;;;  for any damages arising out of the use of this software.
;;;
;;;  $Id: logical.scm,v 1.2 2001-11-16 11:31:22 shirok Exp $
;;;

(select-module gauche)

;; SLIB compatible interface.

(define (logtest . args)  ;; can be optimized for two-arg case
  (not (zero? (apply logand args))))

(define (logbit? index n)
  (not (zero? (logand n (ash 1 index)))))

(define (copy-bit index from bit)
  (if bit
      (logior (ash 1 index) from)
      (logand (lognot (ash 1 index)) from)))

(define (bit-field n start end)
  (check-arg integer? start)
  (check-arg integer? end)
  (if (< start end)
      (let ((mask (- (ash 1 (- end start)) 1)))
        (logand (ash n (- start)) mask))
      0))

(define (copy-bit-field to start end from)
  (check-arg integer? start)
  (check-arg integer? end)
  (if (< start end)
      (let ((mask (- (ash 1 (- end start)) 1)))
        (logior (logand to (lognot (ash mask start)))
                (ash (logand from mask) start)))
      from))

;;; The following code uses the algorithm from SLIB's logical.scm,
;;; adapted to Gauche

;;;; "logical.scm", bit access and operations for integers for Scheme
;;; Copyright (C) 1991, 1993 Aubrey Jaffer.
;
;Permission to copy this software, to redistribute it, and to use it
;for any purpose is granted, subject to the following restrictions and
;understandings.
;
;1.  Any copy made of this software must include this copyright notice
;in full.
;
;2.  I have made no warrantee or representation that the operation of
;this software will be error-free, and I am under no obligation to
;provide any services, by way of maintenance, update, or otherwise.
;
;3.  In conjunction with products arising from the use of this
;material, there shall be no use of my name in any advertising,
;promotional, or sales literature without prior written consent in
;each case.

(define (logcount n)
  (check-arg integer? n)
  (letrec ((rec
            (lambda (n)
              (if (zero? n)
                  0
                  (+ (vector-ref '#(0 1 1 2 1 2 2 3 1 2 2 3 2 3 3 4)
                                 (logand n #xf))
                     (rec (ash n -4)))))))
    (if (negative? n)
        (rec (lognot n))
        (rec n))))

(define (integer-length n)
  (check-arg integer? n)
  (letrec ((rec
            (lambda (n)
              (case n
                ((0 -1) 0)
                ((1 -2) 1)
                ((2 3 -3 -4) 2)
                ((4 5 6 7 -5 -6 -7 -8) 3)
                (else (+ 4 (rec (ash n -4))))))))
    (rec n)))
