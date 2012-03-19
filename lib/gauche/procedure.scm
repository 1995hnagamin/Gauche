;;;
;;; procedure.scm - auxiliary procedure utilities.  to be autoloaded.
;;;  
;;;   Copyright (c) 2000-2011  Shiro Kawai  <shiro@acm.org>
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

(define-module gauche.procedure
  (use srfi-1)
  (export compose .$ complement pa$ map$ for-each$ apply$
          count$ fold$ fold-right$ reduce$ reduce-right$
          filter$ partition$ remove$ find$ find-tail$
          any$ every$ delete$ member$ assoc$
          any-pred every-pred
          applicable? arity procedure-arity-includes?
          <arity-at-least> arity-at-least? arity-at-least-value
          case-lambda ~ ref* disasm
          generator-fold generator-fold-right
          generator-for-each generator-map
          ))

(select-module gauche.procedure)

;; Combinator utilities -----------------------------------------

(define (pa$ fn . args)                  ;partial apply
  (lambda more-args (apply fn (append args more-args))))

(define (compose . fns)
  (cond ((null? fns) values)
        ((null? (cdr fns)) (car fns))
        ((null? (cddr fns))
         (lambda args
           (call-with-values (lambda () (apply (cadr fns) args)) (car fns))))
        (else
         (compose (car fns) (apply compose (cdr fns))))))

(define .$ compose)                     ;experimental

(define (compose$ f) (pa$ compose f))

(define (complement fn)
  (case (arity fn) ;; some optimization
    ((0) (lambda () (not (fn))))
    ((1) (lambda (x) (not (fn x))))
    ((2) (lambda (x y) (not (fn x y))))
    (else (lambda args (not (apply fn args))))))

(define (map$ proc)      (pa$ map proc))
(define (for-each$ proc) (pa$ for-each proc))
(define (apply$ proc)    (pa$ apply proc))

;; partial evaluation version of srfi-1 procedures
(define (count$ pred) (pa$ count pred))
(define (fold$ kons . maybe-knil)
  (lambda lists (apply fold kons (append maybe-knil lists))))
(define (fold-right$ kons . maybe-knil)
  (lambda lists (apply fold-right kons (append maybe-knil lists))))
(define (reduce$ f . maybe-ridentity)
  (lambda args (apply reduce f (append maybe-ridentity args))))
(define (reduce-right$ f . maybe-ridentity)
  (lambda args (apply reduce-right f (append maybe-ridentity args))))
(define (filter$ pred) (pa$ filter pred))
(define (partition$ pred) (pa$ partition pred))
(define (remove$ pred) (pa$ remove pred))
(define (find$ pred) (pa$ find pred))
(define (find-tail$ pred) (pa$ find-tail pred))
(define (any$ pred) (pa$ any pred))
(define (every$ pred) (pa$ every pred))
(define (delete$ x) (pa$ delete x))
(define (member$ x) (pa$ member x))
(define (assoc$ x) (pa$ assoc x))


(define (any-pred . preds)
  (lambda args
    (let loop ((preds preds))
      (cond ((null? preds) #f)
            ((apply (car preds) args))
            (else (loop (cdr preds)))))))

(define (every-pred . preds)
  (if (null? preds)
      (lambda args #t)
      (lambda args
        (let loop ((preds preds))
          (cond ((null? (cdr preds))
                 (apply (car preds) args))
                ((apply (car preds) args)
                 (loop (cdr preds)))
                (else #f))))))

;; Curryable procedures ------------------------------------

#|  disabled for now; see proc.c for the details.

(define %procedure-currying-set!        ;hidden
  (with-module gauche.internal %procedure-currying-set!))

(define-syntax curry-lambda
  (syntax-rules ()
    [(_ formals . body)
     (let1 var (lambda formals . body)
       (%procedure-currying-set! var #t)
       var)]))

(define-syntax define-curry
  (syntax-rules ()
    [(_ (name . formals) . body)
     (define name (curry-lambda formals . body))]))
|#

;; Applicability -------------------------------------------

;; NB: This takes a list of classes.  But what if we support eqv-specilizer?
;; One idea is to let the caller wrap a concrete instance.  We'll see...
(define (applicable? proc . arg-types)
  (define method-applicable?
    (with-module gauche.object method-applicable-for-classes?))
  (let1 c (class-of proc)
    (cond [(eq? c <procedure>)
           (procedure-arity-includes? proc (length arg-types))]
          [(eq? c <generic>)
           (any (^m (apply method-applicable? m arg-types)) (~ proc'methods))]
          [(eq? c <method>)  (apply method-applicable? m arg-types)]
          [else (apply applicable? object-apply c arg-types)])))

;; Procedure arity -----------------------------------------

(define-class <arity-at-least> ()
  ((value :init-keyword :value :init-value 0)))

(define-method write-object ((obj <arity-at-least>) port)
  (format port "#<arity-at-least ~a>" (ref obj 'value)))

(define (arity-at-least? x) (is-a? x <arity-at-least>))

(define (arity-at-least-value x)
  (check-arg arity-at-least? x)
  (ref x 'value))

(define (arity proc)
  (cond [(or (is-a? proc <procedure>) (is-a? proc <method>))
         (if (ref proc 'optional)
           (make <arity-at-least> :value (ref proc 'required))
           (ref proc 'required))]
        [(is-a? proc <generic>) (map arity (ref proc 'methods))]
        [else (errorf "cannot get arity of ~s" proc)]))

(define (procedure-arity-includes? proc k)
  (let1 a (arity proc)
    (define (check a)
      (cond [(integer? a) (= a k)]
            [(arity-at-least? a) (>= k (arity-at-least-value a))]
            [else (errorf "implementation error in (procedure-arity-includes? ~s ~s)" proc k)]))
    (if (list? a)
      (any check a)
      (check a))))

;; ~, ref*  ----------------------------------------------------
;;  (~ a b c d) => (ref (ref (ref a b) c) d)
;;  TODO: This is here because case-lambda used to be here as well.
;;  This should really belong to src/objlib.scm.  However, we can't
;;  do that in 0.9.2, since src/objlib.scm needs to be complied with
;;  0.9.1.  Move this after 0.9.2 release.
(define ~
  (getter-with-setter
   (case-lambda
     [(obj selector) (ref obj selector)]
     [(obj selector . more) (apply ~ (ref obj selector) more)])
   (case-lambda
     [(obj selector val) ((setter ref) obj selector val)]
     [(obj selector selector2 . rest)
      (apply (setter ~) (ref obj selector) selector2 rest)])))

(define ref* ~)                         ;for the backward compatibility

;; disassembler ------------------------------------------------
;; I'm not sure whether this should be here or not, but fot the time being...

(define (disasm proc)
  (define dump (with-module gauche.internal vm-dump-code))
  (define (dump-case-lambda min-reqargs proc-array)
    (print "CASE-LAMBDA")
    (let1 len (vector-length proc-array)
      (do ([i 0 (+ i 1)])
          ((= i len) #t)
        (when (closure? (vector-ref proc-array i))
          (if (= i (- len 1))
            (print ";;; numargs >= " (+ i min-reqargs))
            (print ";;; numargs = " (+ i min-reqargs)))
          (dump (closure-code (vector-ref proc-array i)))))))
    
  (cond
   [(closure? proc) (print "CLOSURE " proc) (dump (closure-code proc))]
   [(is-a? proc <method>)
    (print "METHOD " proc)
    (cond [(method-code proc) => dump]
          [else (print "(defined in C)")])]
   [(is-a? proc <generic>)
    (print "GENERIC FUNCTION " proc)
    (dolist [m (~ proc'methods)]
      (print ">> method " m)
    (cond [(method-code m) => dump]
          [else (print "(defined in C)")]))]
   [(and (subr? proc)
         (let1 info (procedure-info proc)
           ;; NB: Detect case-lamdba.  The format of procedure-info of
           ;; case-lambda is tentative, and may be changed in future.
           ;; See the comment of make-case-lambda-dispatcher in intlib.stub.
           (and (pair? info)
                (pair? (cdr info))
                (integer? (cadr info))
                (pair? (cddr info))
                (vector? (caddr info))
                (apply dump-case-lambda (cdr info)))))]
   [else (print "Disassemble not applicable for " proc)])
  (values))

;; iterate over generated values -----------------------------------------
;;   GEN is a procedure that yields a series of values, terminated by EOF.
;;   For example, read-char can be used as GEN.

;; Returns a list of new values generated by each of GENS, having tail
;; as the tail of the returned list.  It returns #<eof> when any one of
;; generator returns eof (generation is 
(define (%generate-values gens . tail)
  (fold-right (^[g tail]
                (let1 v (g)
                  (if (or (eof-object? v) (eof-object? tail))
                    (eof-object)
                    (cons v tail))))
              tail gens))

(define (generator-fold fn knil gen . more)
  (if (null? more)
    (let loop ([item (gen)]
               [r    knil])
      (if (eof-object? item)
        r
        (let1 r (fn item r)
          (loop (gen) r))))
    (let1 gens (cons gen more)
      (let loop ([knil knil])
        (let1 items (%generate-values gens knil)
          (if (eof-object? items)
            knil
            (loop (apply fn items))))))))

;; This will consume large stack if input file is large.
(define (generator-fold-right fn knil gen . more)
  (if (null? more)
    (let loop ([item (gen)])
      (if (eof-object? item)
        knil
        (fn item (loop (gen)))))
    (let1 gens (cons gen more)
      (let loop ()
        (let1 items (%generate-values gens)
          (if (eof-object? items)
            knil
            (apply fn (append items `(,(loop))))))))))

(define (generator-for-each fn gen . more)
  (if (null? more)
    (let loop ([item (gen)])
      (unless (eof-object? item)
        (fn item) (loop (gen))))
    (let1 gens (cons gen more)
      (let loop ()
        (let1 items (%generate-values gens)
          (unless (eof-object? items)
            (apply fn items)
            (loop)))))))

(define (generator-map fn gen . more)
  (if (null? more)
    (let loop ([item (gen)] [r '()])
      (if (eof-object? item)
        (reverse r)
        (loop (gen) (cons (fn item) r))))
    (let1 gens (cons gen more)
      (let loop ([r '()])
        (let1 items (%generate-values gens)
          (if (eof-object? items)
            (reverse r)
            (loop (cons (apply fn items) r))))))))
      
;; useful for error messages
(define (port-position-prefix port)
  (let ((n (port-name port))
        (l (port-current-line port)))
    (if n
      (if (positive? l)
        (format #f "~s:line ~a: " n l)
        (format #f "~s: " n))
      "")))


