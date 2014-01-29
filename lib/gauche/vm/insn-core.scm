;;;
;;; gauche.vm.insn-core - <vm-insn-info> definition
;;;
;;;   Copyright (c) 2004-2013  Shiro Kawai  <shiro@acm.org>
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

;; This module isn't for public use.  Programs that wants to access
;; vm instruction info should use the gauche.vm.insn module, which
;; re-exports <vm-insn-info>.
;;
;; The reason that this is separated is solely for the 'geninsn' script,
;; which reads the VM definition and generates insn.scm.  Since
;; gauche.vm.insn module is generated by geninsn, it can't use gauche.vm.insn!

(define-module gauche.vm.insn-core
  (use util.match)
  (export <vm-insn-info> vm-find-insn-info vm-build-insn
          ;; utilities
          vm-insn-size))
(select-module gauche.vm.insn-core)

(define-class <vm-insn-info> ()
  ((name   :init-keyword :name)           ; name of insn (symbol)
   (code   :init-keyword :code)           ; code of insn (integer)
   (num-params :init-keyword :num-params) ; # of parameters
   (alt-num-params :init-keyword :alt-num-params) ; Alternative # of params
                                          ; see vminsn.scm comment
   (operand-type :init-keyword :operand-type) ; operand type
   (combined :init-keyword :combined)     ; combined insns
   (body   :init-keyword :body)           ; body of the insn
   (obsoleted :init-keyword :obsoleted)   ; is this insn fading out?

   (base-variant :init-form #f)           ; 'base' variant of this insn
   (push-variant :init-form #f)           ; 'push' variant of this insn
   (ret-variant  :init-form #f)           ; 'ret' variant of this insn

   (all-insns :allocation :class          ; alist of all instructions,
              :init-value '())            ;   keyed by name.
   ))

(define-method initialize ((self <vm-insn-info>) initargs)
  (next-method)
  (push! (ref self 'all-insns)
         (cons (ref self 'name) self)))

(define-method write-object ((s <vm-insn-info>) out)
  (format out "#<insn ~a>" (ref s 'name)))

;; API. opcode mnemonic -> <vm-insn-info>
(define (vm-find-insn-info mnemonic)
  (cond ((assq mnemonic (class-slot-ref <vm-insn-info> 'all-insns)) => cdr)
        (else (error "No such VM instruction:" mnemonic))))

;; API.  Arg can be <vm-insn-info> or opcode symbol
(define-method vm-insn-size ((info <vm-insn-info>))
  (ecase (~ info'operand-type)
    [(none) 1]
    [(obj addr code codes) 2]
    [(obj+addr) 3]))

(define-method vm-insn-size ((mnemonic <symbol>))
  (vm-insn-size (vm-find-insn-info mnemonic)))

;; API
;; INSN is a list of opcode and parameters, e.g. (PUSH) or (LREF 3 2)
;; Returns an exact integer of encoded VM instruction code.
;; NB: This must match the macro definitions in src/gauche/code.h !!!
(define (vm-build-insn insn)
  (define (check insn info n)
    (unless (or (= n (~ info'num-params))
                (memv n (~ info'alt-num-params)))
      (errorf "VM instruction ~a expects ~a parameters, but got ~s"
              (car insn) (~ info'num-params) insn)))
  (match insn
    [((? symbol? opcode) . params)
     (let1 info (vm-find-insn-info opcode)
       (match params
         [() (check insn info 0) (ref info 'code)]
         [(arg0)
          (check insn info 1)
          (logior (ash (logand arg0 #xfffff) 12)
                  (~ info 'code))]
         [(arg0 arg1)
          (check insn info 2)
          (logior (ash (logand arg1 #x3ff) 22)
                  (ash (logand arg0 #x3ff) 12)
                  (~ info 'code))]
         [else (error "vm-build-insn: bad insn:" insn)]))]
    [else (error "vm-build-insn: bad insn:" insn)]))




