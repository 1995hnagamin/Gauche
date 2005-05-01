;;;
;;; gauche-init.scm - initialize standard environment
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
;;;  $Id: gauche-init.scm,v 1.119 2005-05-01 06:36:03 shirok Exp $
;;;

(select-module gauche)

;;
;; Loading, require and provide
;;

;; Load path needs to be dealt with at the compile time.  this is a
;; hack to do so.   Don't modify *load-path* directly, since it causes
;; weird compiler-evaluator problem.
;; I don't like the current name "add-load-path", though---looks like
;; more a procedure than a compiler syntax---any ideas?
(define-macro (add-load-path path . args)
  `',(apply %add-load-path path args))

;; Same as above.
(define-macro (require feature)
  `',(%require feature))

(define-macro (export-all)
  `',(%export-all))

(define-macro (autoload file . vars)
  `(%autoload (current-module) ',file ',vars))

;; Preferred way
;;  (use x.y.z) ==> (require "x/y/z") (import x.y.z)

(define-macro (use module)
  `(begin
     (with-module gauche
       (require ,(module-name->path module)))
     (import ,module)))

;; create built-in modules, so that (use srfi-6) won't complain, for example.
(define-module srfi-2 )
(define-module srfi-6 )
(define-module srfi-8 )
(define-module srfi-10 )
(define-module srfi-17 )

;; for backward compatibility
(define-module gauche.vm.debugger )

;;
;; Auxiliary definitions
;;

(define <exception> <condition>) ;; backward compatibility

(define-reader-ctor 'string-interpolate
  (lambda (s) (string-interpolate s))) ;;lambda is required to delay loading

;;
;; Load object system
;;

;; A trick to cross-compile during development.  Will go away.
(define-macro (%init-object-system)
  (unless (find-module 'gauche.object)
    (%require "gauche/object")))

(%init-object-system)
