;; trie.scm - trie
;;
;;  Copyright (c) 2005 OOHASHI Daichi, All rights reserved.
;;  Copyright (c) 2006-2007  Shiro Kawai  <shiro@acm.org>
;;
;;  Redistribution and use in source and binary forms, with or without
;;  modification, are permitted provided that the following conditions
;;  are met:
;;
;;  1. Redistributions of source code must retain the above copyright
;;     notice, this list of conditions and the following disclaimer.
;;
;;  2. Redistributions in binary form must reproduce the above copyright
;;     notice, this list of conditions and the following disclaimer in the
;;     documentation and/or other materials provided with the distribution.
;;
;;  3. Neither the name of the authors nor the names of its contributors
;;     may be used to endorse or promote products derived from this
;;     software without specific prior written permission.
;;
;;  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;; [SK] Various people contributed to this module to improve it.
;; See http://practical-scheme.net/wiliki/wiliki.cgi/Gauche:Trie for
;; the details of the discussion (in Japanese).  I ended up rewriting
;; almost everything during the course of adjusting APIs to other
;; parts of Gauche, but the discussion was the source of inspiration anyway.

(define-module util.trie
  (use srfi-1)
  (use gauche.sequence)
  (use util.list)
  (export <trie>
          make-trie trie trie-with-keys
          trie? trie-num-entries trie-exists?
          trie-get trie-put! trie-update! trie-delete!
          trie-common-prefix
          trie-common-prefix-keys
          trie-common-prefix-values
          trie-common-prefix-fold
          trie-common-prefix-map
          trie-common-prefix-for-each
          trie->list trie->hash-table
          trie-keys trie-values trie-fold trie-map trie-for-each
          call-with-iterator call-with-builder size-of lazy-size-of
          ))

(select-module util.trie)

;; Trie node structure
;;
;; <node> :=  (<table> <terminal> ...)
;;
;; <terminal> := (<sequence> . <value>)
;;
;; We may have more than one terminal if the Trie contains heterogeneous
;; sequences, e.g. "foo" and (#\f #\o #\o).
;;
;; <table> can be any structure that can map an element of the sequence
;; to other nodes.  Hashtables and assoc-lists are handy ones.
;; The actual table can be specified by a set of procedures given
;; to make-trie:
;;
;;   tab-make :: () -> table    construct an empty table
;;   tab-get     table, key -> node or #f
;;                  lookup the table by the key.  return #f if there's
;;                  no entry for the key.
;;   tab-put! :: table, key, node -> table  
;;                  put a key&node pair into the table, or delete the
;;                  entry if node is #f.  returned table is used for
;;                  subsequent opration.
;;   tab-fold    table, (key, node, seed -> seed), seed -> seed
;;                  iterator on the table entries.

(define-class <trie-meta> (<class>)
  ())

(define-class <trie> (<collection>)
  ((root :init-form (%make-node))
   (size :init-value 0)
   (tab-make :init-keyword :tab-make
             :init-value (cut make-hash-table 'eqv?))
   (tab-get  :init-keyword :tab-get
             :init-value (cut hash-table-get <> <> #f))
   (tab-put! :init-keyword :tab-put!
             :init-value (lambda (t k v)
                           (if v
                             (hash-table-put! t k v)
                             (hash-table-delete! t k))
                           t))
   (tab-fold :init-keyword :tab-fold
             :init-value hash-table-fold)
   )
  :metaclass <trie-meta>)

;;;===========================================================
;;; Constructors etc.
;;;

(define (make-trie . args)
  (let-optionals* args ((tab-make #f)
                        (tab-get  #f)
                        (tab-put! #f)
                        (tab-fold #f))
    (apply make <trie>
           (cond-list
            (tab-make @ `(:tab-make ,tab-make))
            (tab-get  @ `(:tab-get  ,tab-get))
            (tab-put! @ `(:tab-put! ,tab-put!))
            (tab-fold @ `(:tab-fold ,tab-fold))))))

(define (trie params . keys&vals)
  (rlet1 t (apply make-trie params)
    (for-each (lambda (p) (trie-put! t (car p) (cdr p))) keys&vals)))

(define (trie-with-keys params . seqs)
  (rlet1 t (apply make-trie params)
    (for-each (lambda (seq) (trie-put! t seq seq)) seqs)))

(define (trie? x)
  (is-a? x <trie>))

(define (trie-num-entries trie)
  (slot-ref trie 'size))

;;;===========================================================
;;; Lookup and modification
;;;

;; internal: node constructor
(define (%make-node) (list #f))
(define %node-table car)
(define %node-terminals cdr)

(define (%node-table-create trie node)
  (rlet1 tab ((slot-ref trie 'tab-make))
    (set! (%node-table node) tab)))

;; We don't need to compare entire sequence, for we know all the elements
;; would match.  We only need to make sure the class of the sequence match.
(define (%node-find-terminal node seq)
  (let1 c (class-of seq)
    (find (lambda (p) (eq? c (class-of (car p)))) (cdr node))))

(define (%no-key seq)
  (error "Trie does not have an entry for a key:" seq))

;; internal:  Trie, [a] -> Maybe Node
(define (%trie-get-node trie seq create?)
  (define (lookup parent tab elt)
    (if-let1 node ((slot-ref trie 'tab-get) tab elt)
      node
      (and create?
           (rlet1 node (%make-node)
             (set! (%node-table parent)
                   ((slot-ref trie 'tab-put!) tab elt node))))))
  (define (descent node elt)
    (let1 tab (%node-table node)
      (cond [tab (lookup node tab elt)]
            [create? (lookup node (%node-table-create trie node) elt)]
            [else #f])))
  ;; In creation mode, we don't need to break during traversal, so
  ;; we save creation of continuation.
  (if create?
    (fold (lambda (elt node) (descent node elt))
          (slot-ref trie 'root)
          seq)
    (let/cc break
      (fold (lambda (elt node) (or (descent node elt) (break #f)))
            (slot-ref trie 'root)
            seq))))

(define (trie-exists? trie seq) (boolean (%trie-get-node trie seq #f)))

(define (trie-get trie seq . opt)
  (or (and-let* ((node (%trie-get-node trie seq #f))
                 (p    (%node-find-terminal node seq)))
        (cdr p))
      (get-optional opt (%no-key seq))))

(define (trie-put! trie seq val)
  (let* ((node (%trie-get-node trie seq #t))
         (p (%node-find-terminal node seq)))
    (cond
     (p (set-cdr! p val))
     (else
      (push! (%node-terminals node) (cons seq val))
      (inc! (slot-ref trie 'size)))))
  (undefined))

(define (trie-update! trie seq proc . opt)
  (let* ((node (%trie-get-node trie seq #t))
         (p    (%node-find-terminal node seq)))
    (cond
     (p (update! (cdr p) proc))
     (else
      (push! (%node-terminals node)
             (cons seq (proc (get-optional opt (%no-key seq)))))
      (inc! (slot-ref trie 'size))))
    (undefined)))

(define (trie-delete! trie seq)
  ;; TODO: prune a table if it becomes empty
  (and-let* ((c (class-of seq))
             (node (%trie-get-node trie seq #f)))
    (update! (cdr node)
             (lambda (terminals)
               (remove (lambda (p)
                         (and (eq? (class-of (car p)) c)
                              (dec! (slot-ref trie 'size))
                              #t))
                       terminals))))
  (undefined))

;;;===========================================================
;;; Scanning
;;;

;; iterate keys under the given node, depth-first.
(define (%trie-node-fold trie node proc seed)
  (define (fold-descendants seed)
    (or (and-let* ((tab (%node-table node)))
          ((slot-ref trie 'tab-fold)
           tab
           (lambda (elt node seed) (%trie-node-fold trie node proc seed))
           seed))
        seed))
  (define (fold-siblings seed)
    (fold (lambda (p seed) (proc (car p) (cdr p) seed))
          seed
          (%node-terminals node)))
  (fold-siblings (fold-descendants seed)))

(define (%trie-prefix-collect trie prefix collector)
  (or (and-let* ((node (%trie-get-node trie prefix #f)))
        ;; NB: we don't need to reverse, since the order of entries
        ;; are unspecified anyway.
        (%trie-node-fold trie node collector '()))
      '()))

(define (trie-common-prefix trie prefix)
  (%trie-prefix-collect trie prefix acons))

(define (trie-common-prefix-keys trie prefix)
  (%trie-prefix-collect trie prefix (lambda (k v s) (cons k s))))

(define (trie-common-prefix-values trie prefix)
  (%trie-prefix-collect trie prefix (lambda (k v s) (cons v s))))

(define (trie-common-prefix-fold trie prefix proc seed)
  (%trie-node-fold trie (or (%trie-get-node trie prefix #f) '()) proc seed))

(define (trie-common-prefix-map trie prefix proc)
  (trie-common-prefix-fold trie prefix
                           (lambda (k v s) (cons (proc k v) s))
                           '()))

(define (trie-common-prefix-for-each trie prefix proc)
  (trie-common-prefix-fold trie prefix
                           (lambda (k v s) (proc k v))
                           #f)
  (undefined))

(define (trie->list trie)
  (trie-common-prefix trie '()))

(define (trie->hash-table trie htype)
  (rlet1 ht (make-hash-table htype)
    (trie-for-each trie (cut hash-table-put! ht <> <>))))

(define (trie-keys trie)
  (trie-common-prefix-keys trie '()))

(define (trie-values trie)
  (trie-common-prefix-values trie '()))

(define (trie-fold trie proc seed)
  (trie-common-prefix-fold trie '() proc seed))

(define (trie-map trie proc)
  (trie-common-prefix-map trie '() proc))

(define (trie-for-each trie proc)
  (trie-common-prefix-for-each trie '() proc)) 

;;;===========================================================
;;; Collection framework
;;;

(define-method call-with-iterator ((trie <trie>) proc . opts)
  (define count 0)
  (define (next)
    (let/cc return
      (%trie-node-fold trie (slot-ref trie 'root)
                       (lambda (key value seed)
                         (let/cc restart
                           (inc! count)
                           (set! next (lambda () (restart #f)))
                           (return (cons key value))))
                       #f)))
  (proc (lambda () (= count (trie-num-entries trie)))
        (lambda () (next))))

(define-method call-with-builder ((class <trie-meta>) proc . opts)
  (let1 trie (apply make-trie (get-keyword :trie-options opts '()))
    (proc (lambda (val)
            (unless (pair? val)
              (error "pair required to build a trie, but got" val))
            (trie-put! trie (car val) (cdr val)))
          (lambda () trie))))

(define-method size-of ((trie <trie>))
  (trie-num-entries trie))

(define-method lazy-size-of ((trie <trie>))
  (trie-num-entries trie))

;; some shortcuts, so that we can avoid call/cc trampolines
;;

(define-method coerce-to ((class <list-meta>) (trie <trie>))
  (trie->list trie))

(define-method coerce-to ((class <vector-meta>) (trie <trie>))
  (rlet1 vec (make-vector (trie-num-entries trie))
    (trie-fold trie
               (lambda (k v ind)
                 (vector-set! vec ind (cons k v))
                 (+ ind 1))
               0)))

(define-method coerce-to ((class <hash-table-meta>) (trie <trie>))
  (trie->hash-table trie 'equal?))

(provide "util/trie")
