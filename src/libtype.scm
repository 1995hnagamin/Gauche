;;;
;;; libtype.scm - type-related stuff
;;;
;;;   Copyright (c) 2021  Shiro Kawai  <shiro@acm.org>
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

;; This must be the first form to prevents generation of *.sci file
(declare (keep-private-macro define-type-constructor))

;; In Gauche, types are a data structure that appears in both compile-time
;; and run-time, describes metalevel properties of run-time data.
;;
;; Gauche has two kinds of types--generative types and descriptive types.
;; Generative types are the types that are actually used to generate the
;; actual data---we also call it classes.  Descriptive types are, otoh,
;; used only to descrive the nature of data at the certain point of program
;; execution---for example, you may say the argument must be either <integer>
;; or <boolean>.  The descriptive type can't be used to generate an instance,
;; only to be used to validate and/or infer the actual (generative) type of
;; data.
;;
;; Descriptive types can be constructed by type constructors.  Since the
;; compiler needs to know about types, type constructor expressions
;; are evaluated at the compile time, much like macros.
;;
;; We could implemented types with macros, but it would be tricky.  Unlike
;; macros, type expression needs to evaluate from inside to outside, just
;; like the ordinary expression.  It's more like compile-time constant folding.
;;
;; Since type handing is deeply intertwined with compiler, we let the compiler
;; recognize type expression specifically, rather than reusing existing
;; evaluation mechanism.  When the compile sees (C x ...) and C has an
;; inlineable binding to an instance of <type-constructor-meta>, it recognizes
;; type expression.

;; This module is not meant to be `use'd.   It is just to hide
;; auxiliary procedures from the rest of the system.  The necessary
;; bindings are injected into 'gauche' module at the initialization time.
(define-module gauche.typeutil)
(select-module gauche.typeutil)
(use util.match)

;; Metaclass: <type-constructor-meta>
;;   Instance classes of this metaclass are used to create an abstract types.
(inline-stub
 (.include "gauche/class.h")
 (define-ctype ScmTypeConstructor
   ::(.struct ScmTypeConstructorRec
              (common::ScmClass
               constructor::ScmObj
               deconstructor::ScmObj
               validator::ScmObj)))

 ;; constructor - a procedure to build a descriptive type, an instance
 ;;               of the metaclass.
 ;; deconstructor - returns a list of objects which, when passed to the
 ;;               constructor, recreates the type.
 ;;               each element must be either a simple constant or a type.
 ;; validator - takes type and obj, returns if obj is valid as type.
 (define-cclass <type-constructor-meta> :base :private :no-meta
   "ScmTypeConstructor*" "Scm_TypeConstructorMeta"
   (c "SCM_CLASS_METACLASS_CPL")
   ((constructor)
    (deconstructor)
    (validator))
   )

 (define-cfn Scm_TypeConstructorP (klass) ::int
   (return (SCM_ISA klass (& Scm_TypeConstructorMeta))))
 )

;; define-type-constructor name supers
;;   (slot ...)
;;   of-type

(define-syntax define-type-constructor
  (er-macro-transformer
   (^[f r c]
     (match f
       [(_ name supers slots constructor deconstructor validator)
        (let ([meta-name (rxmatch-if (#/^<(.*)>$/ (symbol->string name))
                             [_ trimmed]
                           (string->symbol #"<~|trimmed|-meta>")
                           (string->symbol #"~|name|-meta"))]
              [supers (if (null? supers)
                        (list (r'<type-instance-meta>))
                        supers)])
          (quasirename r
            `(begin
               (define-class ,meta-name (<type-constructor-meta>) ())
               (define-class ,name ,supers ,slots
                 :metaclass ,meta-name
                 :constructor ,constructor
                 :deconstructor ,deconstructor
                 :validator ,validator))))]))))

;; Metaclass: <type-instance-meta>
;;   An abstract type instance, which is a class but won't create instances.
;;   It can be used for of-type? method.
(define-class <type-instance-meta> (<class>)
  ())

(define-method allocate-instance ((t <type-instance-meta>) initargs)
  (error "Abstract type instance cannot instantiate a concrete object:" t))

;; Equality is used when consolidate literals.  It's not lightweight
;; (it calls deconstructor, which allocates).
(define-method object-equal? ((x <type-instance-meta>) (y <type-instance-meta>))
  (and (equal? (class-of x) (class-of y))
       (equal? (deconstruct-type x) (deconstruct-type y))))

;; Internal API, required to precompile descriptive type constant
(define-method deconstruct-type ((t <type-instance-meta>))
  ((~ (class-of t)'deconstructor) t))

;; This is called from initialization of precompiled code to recove
;; descripitve type instance.
(inline-stub
 (define-cfn Scm_ConstructType (ctor args)
   (unless (Scm_TypeConstructorP ctor)
     (SCM_TYPE_ERROR ctor "<type-constructor-meta>"))
   (return (Scm_ApplyRec (-> (cast ScmTypeConstructor* ctor) constructor)
                         args)))
 )

;;;
;;; Utilities
;;;

(define (join-class-names classes)
  (string-join (map (^k (if (is-a? k <class>)
                          ($ symbol->string $ class-name k)
                          (x->string k)))
                    classes)
               " " 'prefix))

(define (make-compound-type-name op-name classes)
  ($ string->symbol
     $ string-append "<" (x->string op-name) (join-class-names classes) ">"))

(define (make-min-max-len-type-name op-name classes min max)
  ($ string->symbol
     $ string-append "<" (x->string op-name) (join-class-names classes)
     (if min
       (if max
         (if (= min max)
           (format " ~d" min)
           (format " ~d..~d" min max))
         (format " ~d.." min))
       (if max
         (format " ..~d" max)
         ""))
     ">"))

;;;
;;; Class: <^>  (maybe we want to name it <λ>)
;;;   Creates a procedure type.
;;;   The signature can be specified as
;;;
;;;       <argtype1> <argtype2> ... :- <rettype1> <rettype2> ...
;;;
;;;   Argument types and/or return types can be also a single symbol '*,
;;;   indicating arbitrary number of args/values.   That is, any procedure
;;;   can be of type '* :- '*.
;;;
;;;   NB: Currently we don't keep the return value info in procedure, so
;;;   we only allow "wild card" '* as the results.
;;;
;;;   TODO: How to type optional, keyword and rest arguments?
;;;


(define (make-^ . rest)
  (define (scan-args xs as)
    (match xs
      [() (error "Missing ':-' in the procedure type constructor arguments:"
                 rest)]
      [(':- . xs) (scan-results xs (reverse as) '())]
      [('* ':- . xs)
       (if (null? as)
         (scan-results xs '* '())
         (error "Invalid '* in the procedure type constructor arguments:"
                rest))]
      [else
       (if (is-a? (car xs) <class>)
         (scan-args (cdr xs) (cons (car xs) as))
         (error "Non-class argument in the procedure type constructor:"
                (car xs)))]))
  (define (scan-results xs args rs)
    (cond [(null? xs) (values args (reverse rs))]
          [(and (null? rs) (eq? (car xs) '*) (null? (cdr xs)))
           (values args '*)]
          [(is-a? (car xs) <class>)
           (scan-results (cdr xs) args (cons (car xs) rs))]
          [else
           (error "Non-class argument in the procedure type constructor:"
                  (car xs))]))

  (receive (args results) (scan-args rest '())
    (unless (eq? results '*)
      (error "Result type must be '*, for we don't support result type checking \
              yet:" results))
    (make <^>
      :name (make-compound-type-name '^ rest)
      :arguments args
      :results results)))

(define (deconstruct-^ type)
  (if (eq? (~ type'results) '*)
    (append (~ type'arguments) '(:- *))
    (append (~ type'arguments) '(:-) (~ type'results))))

(define (validate-^ type obj)
  (if (eq? (~ type'arguments) '*)
    (or (is-a? obj <procedure>)
        (is-a? obj <generic>)
        (let1 k (class-of obj)
          (let loop ([ms (~ object-apply'methods)])
            (cond [(null? ms) #f]
                  [(subtype? k (car (~ (car ms)'specializers)))]
                  [else (loop (cdr ms))]))))
    (apply applicable? obj (~ type'arguments))))

(define-type-constructor <^> ()
  ((arguments :init-keyword :arguments)
   (results :init-keyword :results))
  make-^
  deconstruct-^
  validate-^)

;;;
;;; Class: </>
;;;   Creates a union type.
;;;

(define (make-/ . args)
  (assume (every (cut is-a? <> <class>) args))
  (make </>
    :name (make-compound-type-name '/ args)
    :members args))

(define (deconstruct-/ type)
  (~ type'members))

(define (validate-/ type obj)
  (any (cut of-type? obj <>) (~ type'members)))

(define-type-constructor </> ()
  ((members :init-keyword :members))
  make-/
  deconstruct-/
  validate-/)

;;;
;;; Class: <?>
;;;   Creates a boolean-optional type, that is, <type> or #f.
;;;

(define (make-? ptype)
  (assume (is-a? ptype <class>))
  (make <?>
    :name (make-compound-type-name '? `(,ptype))
    :primary-type ptype))

(define (deconstruct-? type)
  (list (~ type'primary-type)))

(define (validate-? type obj)
  (or (eqv? obj #f) (of-type? obj (~ type'primary-type))))

(define-type-constructor <?> ()
  ((primary-type :init-keyword :primary-type))
  make-?
  deconstruct-?
  validate-?)

;;;
;;; Class: <Tuple>
;;;   Fixed-lenght list, each element having its own type constraints.
;;;

(define (make-Tuple . args)
  (assume (every (cut is-a? <> <class>) args))
  (make <Tuple>
    :name (make-compound-type-name 'Tuple args)
    :elements args))

(define (deconstruct-Tuple type)
  (~ type'elements))

(define (validate-Tuple type obj)
  (let loop ((obj obj) (elts (~ type'elements)))
    (if (null? obj)
      (null? elts)
      (and (pair? obj)
           (pair? elts)
           (of-type? (car obj) (car elts))
           (loop (cdr obj) (cdr elts))))))

(define-type-constructor <Tuple> ()
  ((elements :init-keyword :elements))
  make-Tuple
  deconstruct-Tuple
  validate-Tuple)

;;;
;;; Class: <List>
;;;   A list of specified types.
;;;

(define (make-List etype :optional (min #f) (max #f))
  (make <List>
    :name (make-min-max-len-type-name 'List (list etype) min max)
    :element-type etype
    :min-length min
    :max-length max))

(define (deconstruct-List type)
  (list (~ type'element-type) (~ type'min-length) (~ type'max-length)))

(define (validate-List type obj)
  (let ([et (~ type'element-type)]
        [mi (~ type'min-length)]
        [ma (~ type'max-length)])
    (if (not (or mi ma))
      ;; simple case
      (let loop ([obj obj])
        (cond [(null? obj) #t]
              [(not (pair? obj)) #f]
              [(of-type? (car obj) et) (loop (cdr obj))]
              [else #f]))
      ;; general case
      (let loop ([obj obj] [n 0])
        (cond [(null? obj) (or (not mi) (<= mi n))]
              [(and ma (<= ma n)) #f]
              [(not (pair? obj)) #f]
              [(of-type? (car obj) et) (loop (cdr obj) (+ n 1))]
              [else #f])))))

(define-type-constructor <List> ()
  ((element-type :init-keyword :element-type)
   (min-length :init-keyword :min-length :init-value #f)
   (max-length :init-keyword :max-length :init-value #f))
  make-List
  deconstruct-List
  validate-List)

;;;
;;; <Vector> element-type [min-length [max-length]]
;;;

(define (make-Vector etype :optional (min #f) (max #f))
  (make <Vector>
    :name (make-min-max-len-type-name 'Vector (list etype) min max)
    :element-type etype
    :min-length min
    :max-length max))

(define (deconstruct-Vector type)
  (list (~ type'element-type) (~ type'min-length) (~ type'max-length)))

(define (validate-Vector type obj)
  (and (vector? obj)
       (let ([et (~ type'element-type)]
             [mi (~ type'min-length)]
             [ma (~ type'max-length)]
             [len (vector-length obj)])
         (and (or (not mi) (<= mi len))
              (or (not ma) (<= len ma))
              (let loop ([i 0])
                (cond [(= i len) #t]
                      [(of-type? (vector-ref obj i) et) (loop (+ i 1))]
                      [else #f]))))))

(define-type-constructor <Vector> ()
  ((element-type :init-keyword :element-type)
   (min-length :init-keyword :min-length :init-value #f)
   (max-length :init-keyword :max-length :init-value #f))
  make-Vector
  deconstruct-Vector
  validate-Vector)

;;;
;;; Make exported symbol visible from outside
;;;

;; TRANSIENT: the inlinable flag is only necessary in 0.9.10 -> 0.9.11
;; transition, for define-class doesn't create inlinable binding in 0.9.10 but
;; it does in 0.9.11.
(let ((xfer (with-module gauche.internal %transfer-bindings)))
  (xfer (current-module)
        (find-module 'gauche)
        '(<type-constructor-meta>
          <type-instance-meta>
          <^> </> <?> <Tuple> <List> <Vector>)
        '(inlinable))
  (xfer (current-module)
        (find-module 'gauche.internal)
        '(deconstruct-type)))
