;;;
;;; singleton.scm - implements singleton mixin
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
;;;  $Id: singleton.scm,v 1.3 2003-07-05 03:29:11 shirok Exp $
;;;

;; EXPERIMENTAL

(define-module gauche.mop.singleton
  (export <singleton-meta> <singleton-mixin> instance-of))
(select-module gauche.mop.singleton)

(define-class <singleton-meta> (<class>)
  (%the-singleton-instance)
  )

;; TODO: MT safeness
(define-method make ((class <singleton-meta>) . initargs)
  (if (slot-bound? class '%the-singleton-instance)
      (slot-ref class '%the-singleton-instance)
      (let ((ins (next-method)))
        (slot-set! class '%the-singleton-instance ins)
        ins)))

(define-method instance-of ((class <singleton-meta>) . initargs)
  (apply make class initargs))

;; convenience mixin class.  you can either inherit <singleton-mixin>,
;; or specifying :metaclass <singleton-meta> to your class.
(define-class <singleton-mixin> ()
  ()
  :metaclass <singleton-meta>)

(provide "gauche/mop/singleton")
