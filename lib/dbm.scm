;;;
;;; dbm - abstract base class for dbm interface
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
;;;  $Id: dbm.scm,v 1.5 2004-04-02 00:02:31 shirok Exp $
;;;

(define-module dbm
  (use gauche.collection)
  (export <dbm> <dbm-meta>
          dbm-open    dbm-close   dbm-closed? dbm-get
          dbm-put!    dbm-delete! dbm-exists?
          dbm-fold    dbm-for-each  dbm-map
          dbm-db-exists? dbm-db-remove dbm-db-copy dbm-db-rename)
  )
(select-module dbm)

(define-class <dbm-meta> (<class>)
  ())

(define-class <dbm> (<collection>)
  ((path       :init-keyword :path)
   (rw-mode    :init-keyword :rw-mode    :initform :write)
   (file-mode  :init-keyword :file-mode  :initform #o664)
   (key-convert   :init-keyword :key-convert :initform #f)
   (value-convert :init-keyword :value-convert :initform #f)
   ;; internal.  set up by dbm-open
   k2s s2k v2s s2v)
  :metaclass <dbm-meta>)

;; Macros & procedures that can be used by implementation modules
(define-syntax %dbm-k2s
  (syntax-rules ()
    ((_ self key) ((slot-ref self 'k2s) key))))

(define-syntax %dbm-s2k
  (syntax-rules ()
    ((_ self key) ((slot-ref self 's2k) key))))

(define-syntax %dbm-v2s
  (syntax-rules ()
    ((_ self key) ((slot-ref self 'v2s) key))))

(define-syntax %dbm-s2v
  (syntax-rules ()
    ((_ self key) ((slot-ref self 's2v) key))))

;; Utilities to copy/rename two files (esp. *.dir and *.pag file of
;; traditional dbm).  Makes some effort to take care of rollback on failure.
;; Also check if two files are hard-linked (gdbm_compat does that).

(autoload file.util file-eq? copy-file move-file)

(define (%dbm-copy2 from1 to1 from2 to2 . keys)
  (let-keywords* keys ((if-exists :error))
    (if (file-eq? from1 from2)
      (begin ;; dir and pag files are identical
        (copy-file from1 to1 :safe #t :if-exists if-exists)
        (sys-link to1 to2))
      (begin
        (copy-file from1 to1 :safe #t :if-exists if-exists)
        (with-error-handler
            (lambda (e) (sys-unlink to1) (sys-unlink to2) (raise e))
          (lambda () (copy-file from2 to2 :safe #t :if-exists if-exists)))))))

(define (%dbm-rename2 from1 to1 from2 to2 . keys)
  (let-keywords* keys ((if-exists :error))
    (if (file-eq? from1 from2)
      (begin
        (move-file from1 to1 :if-exists if-exists)
        (sys-link to1 to2)
        (sys-unlink from2))
      (begin
        (move-file from1 to1 :if-exists if-exists)
        (move-file from2 to2 :if-exists if-exists)))))

;;
;; DBM-OPEN
;;

(define-method dbm-open ((class <dbm-meta>) . initargs)
  (dbm-open (apply make class initargs)))

(define-method dbm-open ((self <dbm>))
  (define (pick-proc slot default custom)
    (let ((spec (slot-ref self slot)))
      (cond ((eq? spec #f) identity)
            ((eq? spec #t) default)
            ((and (pair? spec)
                  (null? (cddr spec))
                  (procedure? (car spec))
                  (procedure? (cadr spec)))
             (custom spec))
            (else (errorf "bad value for ~s: has to be boolean or a list of two procedures, but got ~s" slot spec)))))

  (slot-set! self 'k2s (pick-proc 'key-convert write-to-string car))
  (slot-set! self 's2k (pick-proc 'key-convert read-from-string cadr))
  (slot-set! self 'v2s (pick-proc 'value-convert write-to-string car))
  (slot-set! self 's2v (pick-proc 'value-convert read-from-string cadr))
  self)

;;
;; Method prototypes.  Actual method should be defined in subclasses.
;;

(define-method dbm-put! ((dbm <dbm>) key value)
  (when (dbm-closed? dbm) (errorf "dbm-put!: dbm already closed: ~s" dbm))
  (when (eqv? (slot-ref dbm 'rw-mode) :read)
    (errorf "dbm-put!: dbm is read only: ~s" dbm)))

(define-method dbm-get ((dbm <dbm>) key . args)
  (when (dbm-closed? dbm) (errorf "dbm-get: dbm already closed: ~s" dbm)))

(define-method dbm-exists? ((dbm <dbm>) key)
  (when (dbm-closed? dbm) (errorf "dbm-exists?: dbm already closed: ~s" dbm)))

(define-method dbm-delete! ((dbm <dbm>) key)
  (when (dbm-closed? dbm) (errorf "dbm-delete!: dbm already closed: ~s" dbm))
  (when (eqv? (slot-ref dbm 'rw-mode) :read)
    (errorf "dbm-put!: dbm is read only: ~s" dbm)))

(define-method dbm-fold ((dbm <dbm>) proc knil) #f)

(define-method dbm-close ((dbm <dbm>)) #f)

(define-method dbm-closed? ((dbm <dbm>)) #f)

;;
;; These work if dbm-fold is defined.
;;

(define-method dbm-for-each ((dbm <dbm>) proc)
  (when (dbm-closed? dbm) (errorf "dbm-for-each: dbm already closed: ~s" dbm))
  (unless (procedure? proc) (errorf "dbm-for-each: bad procedure: ~s" proc))
  (dbm-fold dbm (lambda (key value r) (proc key value)) #f))

(define-method dbm-map ((dbm <dbm>) proc)
  (when (dbm-closed? dbm) (errorf "dbm-map: dbm already closed: ~s" dbm))
  (unless (procedure? proc) (errorf "dbm-map: bad procedure: ~s" proc))
  (reverse (dbm-fold dbm (lambda (key value r) (cons (proc key value) r)) '())))

;; Collection framework
;;   This is a fallback, using "iterator inversion" technique to obtain
;;   a generator from dbm-fold.  The subclass may directly implement
;;   them if they have underlying generators.
;; NB: this doesn't work due to the bug of call/cc handling.
;(define-method call-with-iterator ((dbm <dbm>) proc . options)
;  (define restart #f)
;  (define buf #f)
;  (define (fetch)
;    (cond
;     ((eq? restart 'end) #f) ;; already finished
;     ((not restart)          ;; initial setup
;      (let/cc return
;        (dbm-fold dbm
;                  (lambda (k v r)
;                    (let/cc res
;                      (set! restart res)
;                      (return (cons k v))))
;                  #f)
;        (set! restart 'end)
;        'end))
;     (else (restart #f))))
;  (set! buf (fetch))
;  (proc (lambda () (eq? buf 'end))
;        (lambda () (begin0 buf (set! buf (fetch))))))

;;
;; Meta-operations
;;  Subclass has to implement these.

(define-method dbm-db-exists? ((class <dbm-meta>) name)
  (errorf "dbm-db-exists?: not supported in ~a" class))

(define-method dbm-db-remove ((class <dbm-meta>) name)
  (errorf "dbm-db-remove: not supported in ~a" class))

(define-method dbm-db-copy   ((class <dbm-meta>) from to)
  (errorf "dbm-db-copy: not supported in ~a" class))

(define-method dbm-db-rename ((class <dbm-meta>) from to)
  (errorf "dbm-db-rename: not supported in ~a" class))

(provide "dbm")
