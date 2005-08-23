;;;
;;; charconv - character code conversion module
;;;  
;;;   Copyright (c) 2000-2005 Shiro Kawai, All rights reserved.
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
;;;  $Id: charconv.scm,v 1.21 2005-08-23 10:44:04 shirok Exp $
;;;

(define-module gauche.charconv
  (use srfi-1)
  (use srfi-2)
  (use srfi-13)
  (export open-input-conversion-port
          open-output-conversion-port
          ces-conversion-supported?
          ces-guess-from-string
          ces-equivalent? ces-upper-compatible?
          ces-convert
          wrap-with-input-conversion
          wrap-with-output-conversion
          call-with-input-conversion
          call-with-output-conversion
          with-input-conversion
          with-output-conversion
          ))
(select-module gauche.charconv)

(dynamic-load "libcharconv" :export-symbols #t)

;; Determine charset compatibility.  (ces-equivalent? a b) is true if CES a and
;; CES b refer to the same CES.
;; (ces-upper-compatible? a b) is true if a string in CES b can be a legal
;; string in CES a.
;; There is a case that the compatibility can't be determined.  In such
;; case, a value passed as unknown-fallback is returned, whose default is #f.

(define-values (ces-equivalent? ces-upper-compatible?)
  (let ()
    ;; Compatibility table:
    ;; ((x ...) y ...) means x ... are all equivalent, and includes y ....
    ;; Each entry is a symbol.  The CES name is first stripped off all _ and -
    ;; then made a lower case symbol before comparison.
    ;; NB: CES 'none' works as a wildcard.
    (define ces-compatibility-table
      '(((usascii ascii iso646))
        ((iso88591 88591) usascii)
        ((iso88592 88592) usascii)
        ((iso88593 88593) usascii)
        ((iso88594 88594) usascii)
        ((iso88595 88595) usascii)
        ((iso88596 88596) usascii)
        ((iso88597 88597) usascii)
        ((iso88598 88598) usascii)
        ((iso88599 88599) usascii)
        ((iso2022jp csiso2022jp) usascii) ; not exactly
        ((iso2022jp1 csiso2022jp1) iso2022jp)
        ((iso2022jp2 csiso2022jp2) iso2022jp)
        ((iso2022jp3 csiso2022jp3) iso2022jp)
        ((iso2022kr csiso2022kr) usascii)
        ((iso2022cnext csiso2022cnext) iso2022cn)
        ((iso2022cn csiso2022cn) usascii)
        ((eucjp) usascii)
        ((euckr) usascii)
        ((euccn) usascii)
        ((euctw) usascii)
        ((big5 bigfive) usascii)
        ((big5hkscs bigfivehkscs) big5)
        ((big5plus bigfiveplus) big5)
        ((johab) usascii)
        ((shiftjis sjis) usascii) ; not exactly
        ((unicode iso10646 iso10646/utf8 utf8) usascii)
        ))

    ;; canonicalize ces name
    (define (canon-name name)
      (string->symbol (string-downcase (string-delete (x->string name) #[_-]))))

    ;; find ces entry
    (define (find-entry ces)
      (find (lambda (e) (memq ces (car e))) ces-compatibility-table))

    (define (ces-equivalent? a b . unknown-fallback)
      (let* ((ces-a   (canon-name a))
             (ces-b   (canon-name b))
             (entry-a (find-entry ces-a))
             (entry-b (find-entry ces-b)))
        (cond ((or (eq? ces-a 'none) (eq? ces-b 'none)) #t)
              ((or (not entry-a) (not entry-b))
               (get-optional unknown-fallback #f))
              (else (eq? entry-a entry-b)))))

    (define (ces-upper-compatible? a b . unknown-fallback)
      (let* ((ces-a   (canon-name a))
             (ces-b   (canon-name b))
             (entry-a (find-entry ces-a)))
        (cond ((or (eq? ces-a 'none) (eq? ces-b 'none)) #t)
              ((or (not entry-a) (not (find-entry ces-b)))
               (get-optional unknown-fallback #f))
              (else 
               (let loop ((entry entry-a))
                 (if (memq ces-b (car entry))
                     #t
                     (any loop (map find-entry (cdr entry)))))))))
    
    (values ces-equivalent? ces-upper-compatible?)))

;; Convert string
(define (ces-convert string fromcode . args)
  (let-optionals* args ((tocode #f))
    (let ((out (open-output-string :private? #t))
          (in  (open-input-conversion-port
                (open-input-string string :private? #t)
                fromcode
                :to-code tocode :buffer-size (string-size string) :owner? #t)))
      (copy-port in out :unit 'byte)
      (close-input-port in)
      (begin0
       (get-output-string out)
       (close-output-port out)))))

;; "Wrap" the given port for convering to/from native encoding if needed.
;; Unlike open-*-conversion-port, these return port itself if the conversion
;; is not required.
(define (wrap-with-input-conversion port from-code . opts)
  (let-keywords* opts ((to-code (gauche-character-encoding)))
    (if (ces-upper-compatible? to-code from-code)
        port
        (apply open-input-conversion-port port from-code :owner? #t opts))))

(define (wrap-with-output-conversion port to-code . opts)
  (let-keywords* opts ((from-code (gauche-character-encoding)))
    (if (ces-upper-compatible? from-code to-code)
        port
        (apply open-output-conversion-port port to-code :owner? #t opts))))

;; Call with conversion port
(define (call-with-input-conversion port proc . opts)
  (let-keywords* opts ((from-code :encoding (gauche-character-encoding))
                       (bufsiz    :conversion-buffer-size 0))
    (if (ces-upper-compatible? (gauche-character-encoding) from-code)
      (proc port)
      (let1 cvp (open-input-conversion-port port from-code
                                            :owner? #f :buffer-size bufsiz)
        (with-error-handler
            (lambda (e) (close-input-port cvp) (raise e))
          (lambda ()
            (begin0 (proc cvp) (close-input-port cvp)))))
      )))

(define (call-with-output-conversion port proc . opts)
  (let-keywords* opts ((to-code :encoding (gauche-character-encoding))
                       (bufsiz  :conversion-buffer-size 0))
    (if (ces-upper-compatible? (gauche-character-encoding) to-code)
      (proc port)
      (let1 cvp (open-output-conversion-port port to-code
                                             :owner? #f :buffer-size bufsiz)
        (with-error-handler
            (lambda (e) (close-output-port cvp) (raise e))
          (lambda ()
            (begin0 (proc cvp) (close-output-port cvp)))))
      )))

(define (with-input-conversion port thunk . opts)
  (apply call-with-input-conversion port
         (cut with-input-from-port <> thunk)
         opts))

(define (with-output-conversion port thunk . opts)
  (apply call-with-output-conversion port
         (cut with-output-to-port <> thunk)
         opts))

;; Inserts conversion port.  These are called from system's
;; open-{input|output}-port when :encoding argument is given.
(define (%open-input-file/conv name . args)
  (and-let* ((port (apply %open-input-file name args)))
    (open-input-conversion-port
     port
     (get-keyword :encoding args #f)
     :buffer-size (get-keyword :conversion-buffer-size args 0)
     :owner? #t)))

(define (%open-output-file/conv name . args)
  (and-let* ((port (apply %open-output-file name args)))
    (open-output-conversion-port
     port
     (get-keyword :encoding args #f)
     :buffer-size (get-keyword :conversion-buffer-size args 0)
     :owner? #t)))

(provide "gauche/charconv")
