;;;
;;; 822.scm - parsing RFC2822 style message
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
;;;  $Id: 822.scm,v 1.15 2003-12-30 05:39:22 shirok Exp $
;;;

;; Parser and constructor of the message defined in
;; RFC2822 Internet Message Format <ftp://ftp.isi.edu/in-notes/rfc2822.txt>

(define-module rfc.822
  (use srfi-1)
  (use srfi-2)
  (use srfi-13)
  (use srfi-19)
  (use text.parse)
  (use gauche.regexp)
  (export rfc822-header->list rfc822-header-ref
          rfc822-skip-cfws
          *rfc822-atext-chars* *rfc822-standard-tokenizers*
          rfc822-atom rfc822-dot-atom rfc822-quoted-string
          rfc822-next-token rfc822-field->tokens
          rfc822-parse-date rfc822-date->date
          )
  )

(select-module rfc.822)

;;=================================================================
;; Parsers
;;

;;-----------------------------------------------------------------
;; Generic header parser, recognizes folded line and field names
;;
(define (rfc822-header->list iport . args)
  (let-keywords* args ((strict? #f)
                       (reader (cut read-line <> #t)))

    (define (accum name bodies r)
      (cons (list name (string-concatenate-reverse bodies)) r))

    (define (drop-leading-fws body)
      (if (string-incomplete? body)
        body  ;; this message is not RFC2822 compliant anyway
        (string-trim body)))
    
    (let loop ((r '())
               (line (reader iport)))
      (cond
       ((eof-object? line) (reverse! r))
       ((string-null? line) (reverse! r))
       (else
        (receive (n body) (string-scan line #\: 'both)
          (let1 name (and-let* (((string? n))
                                 (name (string-incomplete->complete n))
                                 (name (string-trim-both name))
                                 ((string-every #[\x21-\x39\x3b-\x7e] name)))
                        (string-downcase name))
            (if name
              (let loop2 ((nline (reader iport))
                          (bodies (list (drop-leading-fws body))))
                (cond ((eof-object? nline)
                       ;; maybe premature end of the message
                       (if strict?
                         (error "premature end of message header")
                         (reverse! (accum name bodies r))))
                      ((string-null? nline)     ;; end of the header
                       (reverse! (accum name bodies r)))
                      ((memv (string-byte-ref nline 0) '(9 32))
                       ;; careful for byte strings
                       (loop2 (reader iport) (cons nline bodies)))
                      (else
                       (loop (accum name bodies r) nline)))
                )
              (if strict?
                (error "bad header line:" line)
                (loop r (reader iport)))))))
       ))
    ))

(define (rfc822-header-ref header field-name . maybe-default)
  (cond ((assoc field-name header) => cadr)
        (else (get-optional maybe-default #f))))

;;------------------------------------------------------------------
;; Comments, quoted pairs, atoms and quoted string.  Section 3.2
;;

;; skip comments and white spaces, then returns the head char.
(define (rfc822-skip-cfws input)
  (define (scan c)
    (cond ((eof-object? c) c)
          ((char=? c #\( ) (in-comment (peek-next-char input)))
          ((char-whitespace? c) (scan (peek-next-char input)))
          (else c)))
  (define (in-comment c)
    (cond ((eof-object? c) c)
          ((char=? c #\) ) (scan (peek-next-char input)))
          ((char=? c #\\ ) (read-char input) (in-comment (peek-next-char input)))
          ((char=? c #\( ) (in-comment (in-comment (peek-next-char input))))
          (else (in-comment (peek-next-char input)))))
  (scan (peek-char input)))

;; Basic tokenizers.  Supposed to be used for higher-level parsers.

(define-constant *rfc822-atext-chars* #[A-Za-z0-9!#$%&'*+/=?^_`{|}~-])

(define (rfc822-atom input)
  (next-token-of *rfc822-atext-chars* input))

;; NB: this is loose, but usually OK.
(define (rfc822-dot-atom input)
  (next-token-of (list *rfc822-atext-chars* #\.) input))

;; Assuming the first char in input is DQUOTE
(define (rfc822-quoted-string input)
  (let1 r (open-output-string/private)
    (define (finish) (get-output-string r))
    (let loop ((c (peek-next-char input)))
      (cond ((eof-object? c) (finish));; tolerate missing closing DQUOTE
            ((char=? c #\") (read-char input) (finish)) ;; discard DQUOTE
            ((char=? c #\\)
             (let1 c (peek-next-char input)
               (cond ((eof-object? c) (finish)) ;; tolerate stray backslash
                     (else (write-char c r) (loop (peek-next-char input))))))
            (else (write-char c r) (loop (peek-next-char input)))))))

;; Default tokenizer table
(define-constant *rfc822-standard-tokenizers*
  `((#[\"] . ,rfc822-quoted-string)
    (,*rfc822-atext-chars* . ,rfc822-dot-atom)))

;; Returns the next token or EOF
(define (rfc822-next-token input . opts)
  (let ((toktab (map (lambda (e)
                       (cond
                        ((char-set? e) (cons e (cut next-token-of e <>)))
                        (else e)))
                     (get-optional opts *rfc822-standard-tokenizers*)))
        (c (rfc822-skip-cfws input)))
    (cond ((eof-object? c) c)
          ((find (lambda (e) (char-set-contains? (car e) c)) toktab)
           => (lambda (e) ((cdr e) input)))
          (else (read-char input)))))

;; returns a list of tokens, for convenience
(define (rfc822-field->tokens field . opts)
  (call-with-input-string field
    (cut port->list (cut apply rfc822-next-token <> opts) <>)))

;;------------------------------------------------------------------
;; Date and time, section 3.3
;;

;; Takes RFC-822 type date string, and returns eight values:
;;   year, month, day-of-month, hour, minutes, seconds, timezone, day-of-week.
;; Timezone is an offset from UT in minutes.  Day-of-week is a day from
;; sunday, and may be #f if that information is not available.
;; If the string is not parsable, all the elements are #f.

;; NB: This function follows the new definition of date format in RFC2822,
;; but may fail to recognize "obsolete" format, which allows arbitrary
;; comments appear between words.

(define (rfc822-parse-date string)
  (define (dow->number dow)
    (list-index (cut string=? <> dow)
                '("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")))
  (define (mon->number mon)
    (list-index (cut string=? <> mon)
                '("Jan" "Feb" "Mar" "Apr" "May" "Jun"
                  "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")))
  (define (year->number year) ;; see obs-year definition of RFC2822
    (let ((y (string->number year)))
      (and y
           (cond ((< y 50)  (+ y 2000))
                 ((< y 100) (+ y 1900))
                 (else y)))))
  (define (tz->number tz)
    (cond ((equal? tz "-0000") #f)  ;;no effective TZ info; see 3.3 of RFC2822
          ((string->number tz))
          ((assoc tz '(("UT" . 0) ("GMT" . 0) ("EDT" . -400) ("EST" . -500)
                       ("CDT" . -500) ("CST" . -600) ("MDT" . -600)
                       ("MST" . -700) ("PDT" . -700) ("PST" . -800)))
           => cdr)
          (else #f)))

  (rxmatch-case string
    (#/((Sun|Mon|Tue|Wed|Thu|Fri|Sat)\s*,)?\s*(\d+)\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s*(\d\d(\d\d)?)\s+(\d\d)\s*:\s*(\d\d)(\s*:\s*(\d\d))?(\s+([+-]\d\d\d\d|[A-Z][A-Z][A-Z]?))?/
       (#f #f dow dom mon yr #f hour min #f sec #f tz)
       (values (year->number yr)
               (mon->number mon)
               (string->number dom)
               (string->number hour)
               (string->number min)
               (and sec (string->number sec))
               (and tz (tz->number tz))
               (and dow (dow->number dow))))
     (else (values #f #f #f #f #f #f #f #f))))

;; returns it by srfi-19 date
(define (rfc822-date->date string)
  (receive (year month day hour min sec tz . rest)
      (rfc822-parse-date string)
    (and year
         (make-date 0 sec min hour day month year
                    (receive (quot rem) (quotient&remainder tz 100)
                      (+ (* quot 3600) (* (abs rem) 60)))))))

;;------------------------------------------------------------------
;; Address specification (Section 3.4)
;;

;; The EBNF syntax in RFC2822 requires arbitrary lookahead,
;; so straight recursive-descent parser won't work.
;; 

;; to be written


(provide "rfc/822")
