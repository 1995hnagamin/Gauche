;;;
;;; module related utility functions.  to be autoloaded.
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
;;;  $Id: modutil.scm,v 1.6 2005-07-11 03:33:13 shirok Exp $
;;;

(define-module gauche.modutil
  (export export-if-defined use-version)
  )
(select-module gauche.modutil)

(define-macro (export-if-defined . symbols)
  ;; CAVEAT: this form sees whether the given symbols are defined or not
  ;; _at_compile_time_.  So the definitions of symbols have to appear
  ;; before this form.   Furthermore, the semantics of this form is ambigous
  ;; when used except top-level.  It's not very nice, so you should
  ;; avoid this form unless you really need it.
  ;; NB: filter is in srfi-1, and we don't want to load it here.  Ugh.
  `(export
    ,@(let loop ((syms symbols) (r '()))
        (cond ((null? syms) (reverse! r))
              ((not (symbol? (car syms)))
               (error "non-symbol in export-if-defined form:" (car syms)))
              ((global-variable-bound? #f (car syms))
               (loop (cdr syms) (cons (car syms) r)))
              (else (loop (cdr syms) r))))))

;; Inter-version compatibility.
(define-macro (use-version version)
  (let ((compat (string-append "gauche/compat/" version)))
    (unless (provided? compat)
      (let ((path (string-append (gauche-library-directory) "/" compat ".scm")))
        (when (file-exists? path)
          (let ((module (string->symbol (string-append "gauche-" version))))
            `(begin
               (require ,compat)
               (import ,module))))))))

(provide "gauche/modutil")
