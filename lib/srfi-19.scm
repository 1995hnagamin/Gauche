;; SRFI-19: Time Data Types and Procedures.
;; 
;; Copyright (C) Neodesic Corporation (2000). All Rights Reserved. 
;; 
;; This document and translations of it may be copied and furnished to others, 
;; and derivative works that comment on or otherwise explain it or assist in its 
;; implementation may be prepared, copied, published and distributed, in whole or 
;; in part, without restriction of any kind, provided that the above copyright 
;; notice and this paragraph are included on all such copies and derivative works. 
;; However, this document itself may not be modified in any way, such as by 
;; removing the copyright notice or references to the Scheme Request For 
;; Implementation process or editors, except as needed for the purpose of 
;; developing SRFIs in which case the procedures for copyrights defined in the SRFI 
;; process must be followed, or as required to translate it into languages other 
;; than English. 
;; 
;; The limited permissions granted above are perpetual and will not be revoked 
;; by the authors or their successors or assigns. 
;; 
;; This document and the information contained herein is provided on an "AS IS" 
;; basis and THE AUTHOR AND THE SRFI EDITORS DISCLAIM ALL WARRANTIES, EXPRESS OR 
;; IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF THE 
;; INFORMATION HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED WARRANTIES OF 
;; MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. 

;;; Modified for Gauche by Shiro Kawai, shiro@acm.org
;;; $Id: srfi-19.scm,v 1.7 2002-05-25 10:26:39 shirok Exp $

(define-module srfi-19
  (use gauche.let-opt)
  (export time-tai time-utc time-monotonic time-thread
          time-process time-duration current-time
          make-time time? time-type time-second time-nanosecond
          set-time-type! set-time-second! set-time-nanosecond copy-time
          time=? time<? time<=? time>? time>=?
          time-difference time-difference! add-duration add-duration!
          subtract-duration subtract-duration! 
          make-date date? date-nanosecond date-second date-minute
          date-hour date-day date-month date-year date-zone-offset
          date-year-day date-week-day date-week-number current-date
          date->julian-day date->modified-julian-day date->time-monotonic
          date->time-tai date->time-utc
          julian-day->date julian-day->time-monotonic
          julian-day->time-tai julian-day->time-utc
          modified-julian-day->date modified-julian-day->time-monotonic
          modified-julian-day->time-tai modified-julian-day->time-utc
          time-monotonic->date time-monotonic->julian-day
          time-monotonic->modified-julian-day
          time-monotonic->time-tai time-monotonic->time-tai!
          time-monotonic->time-utc time-monotonic->time-utc!
          time-utc->date time-utc->julian-day
          time-utc->modified-julian-day
          time-utc->time-monotonic time-utc->time-monotonic!
          time-utc->time-tai time-utc->time-tai!
          time-tai->date time-tai->julian-day
          time-tai->modified-julian-day
          time-tai->time-monotonic time-tai->time-monotonic!
          time-tai->time-utc time-tai->time-utc!
          date->string string->date
          )
  )
(select-module srfi-19)

;;;----------------------------------------------------------
;;; Constants
;;;

(define-constant time-tai 'time-tai)
(define-constant time-utc 'time-utc)
(define-constant time-monotonic 'time-monotonic)
(define-constant time-thread 'time-thread)
(define-constant time-process 'time-process)
(define-constant time-duration 'time-duration)

;; example of extension (MZScheme specific)
;(define time-gc 'time-gc)

;;-- Miscellaneous Constants.
;;-- only the tm:tai-epoch-in-jd might need changing if
;;   a different epoch is used.

(define-constant tm:nano 1000000000)
(define-constant tm:sid  86400)    ; seconds in a day
(define-constant tm:sihd 43200)    ; seconds in a half day
(define-constant tm:tai-epoch-in-jd 4881175/2) ; julian day number for 'the epoch'

;; each entry is ( tai seconds since epoch . # seconds to subtract for utc )
;; note they go higher to lower, and end in 1972.
;; See srfi-19/read-tai.scm to update this list.
(define-constant tm:leap-second-table
  '((915148800 . 32)
    (867715200 . 31)
    (820454400 . 30)
    (773020800 . 29)
    (741484800 . 28)
    (709948800 . 27)
    (662688000 . 26)
    (631152000 . 25)
    (567993600 . 24)
    (489024000 . 23)
    (425865600 . 22)
    (394329600 . 21)
    (362793600 . 20)
    (315532800 . 19)
    (283996800 . 18)
    (252460800 . 17)
    (220924800 . 16)
    (189302400 . 15)
    (157766400 . 14)
    (126230400 . 13)
    (94694400  . 12)
    (78796800  . 11)
    (63072000  . 10)))

(define (tm:leap-second-delta utc-seconds)
  (letrec ( (lsd (lambda (table)
		   (cond ((>= utc-seconds (caar table))
			  (cdar table))
			 (else (lsd (cdr table)))))) )
    (if (< utc-seconds  (* (- 1972 1970) 365 tm:sid)) 0
	(lsd  tm:leap-second-table))))

;;;----------------------------------------------------------
;;; TIME strcture interface
;;;  The <time> class is built-in.  We just define some APIs.

(define-method time-type       ((t <time>)) (slot-ref t 'type))
(define-method time-second     ((t <time>)) (slot-ref t 'second))
(define-method time-nanosecond ((t <time>)) (slot-ref t 'nanosecond))

(define-method set-time-type!  ((t <time>) s)
  (slot-set! t 'type s))
(define-method set-time-second! ((t <time>) s)
  (slot-set! t 'second s))
(define-method set-time-nanosecond! ((t <time>) s)
  (slot-set! t 'nanosecond s))

(define (make-time type second nanosecond)
  (make <time> :type type :second second :nanosecond nanosecond))

(define (copy-time time)
  (make <time>
    :type       (time-type time)
    :second     (time-second time)
    :nanosecond (time-nanosecond time)))

;;;----------------------------------------------------------
;;; Error check routine
;;;

(define-syntax tm:check-time-type
  (syntax-rules ()
    ((_ time type caller)
     (unless (eq? (time-type time) type)
       (errorf "~a: incompatible time type: ~a type required, but got ~a"
               caller type time)))
    ))

;;;----------------------------------------------------------
;;; Current-time
;;;

(define (tm:make-time-usec type sec usec)
  (make-time type sec (* usec 1000)))

(define (tm:current-time-process type)
  (let* ((times (sys-times))
         (cpu   (+ (car times) (cadr times)))
         (tick  (list-ref times 4))
         (sec   (quotient cpu tick))
         (nsec  (* (/ tm:nano tick) (remainder cpu tick))))
    (make-time type sec nsec)))

(define (tm:current-time-tai type)
  (let* ((now (with-module gauche (current-time)))
         (sec (slot-ref now 'second)))
    (make <time> :type type :second (+ sec (tm:leap-second-delta sec))
          :nanosecond (slot-ref now 'nanosecond))))


;; redefine built-in current-time
(define (current-time . args)
  (let-optionals* args ((clock-type 'time-utc))
    (case clock-type
     ((time-tai) (tm:current-time-tai clock-type))
     ((time-utc) (with-module gauche (current-time)))
     ((time-monotonic) (tm:current-time-tai clock-type))
     ((time-thread)  (tm:current-time-process 'time-thread))
     ((time-process) (tm:current-time-process 'time-process))
     (else (error "current-time: invalid-clock-type" clock-type)))))

;; -- Time Resolution
;; This is the resolution of the clock in nanoseconds.

;; We don't really know ...  for now, just return 10ms.
(define (time-resolution . args)
  10000000)

;; -- Time comparisons

(define (tm:time-compare time1 time2 proc caller)
  (if (or (not (and (time? time1) (time? time2)))
	  (not (eq? (time-type time1) (time-type time2))))
      (errorf "~a: incompatible time types: ~s, ~s"
              caller time1 time2)
      (cond ((= (time-second time1) (time-second time2))
             (proc (time-nanosecond time1) (time-nanosecond time2)))
            ((and (not (eq? proc =))
                  (proc (time-second time1) (time-second time2))))
            (else #f))))

(define (time=? time1 time2)
  (tm:time-compare time1 time2 = 'time=?))

(define (time>? time1 time2)
  (tm:time-compare time1 time2 > 'time>?))

(define (time<? time1 time2)
  (tm:time-compare time1 time2 < 'time<?))

(define (time>=? time1 time2)
  (tm:time-compare time1 time2 >= 'time>=?))

(define (time<=? time1 time2)
  (tm:time-compare time1 time2 <= 'time<=?))

;; -- Time arithmetic

(define (tm:time-difference time1 time2 time3)
  (if (or (not (and (time? time1) (time? time2)))
	  (not (eq? (time-type time1) (time-type time2))))
      (errorf "time-difference: incompatible time types: ~s, ~s"
              caller time1 time2)
      (let ( (sec-diff (- (time-second time1) (time-second time2)))
	     (nsec-diff (- (time-nanosecond time1) (time-nanosecond time2))) )
	(set-time-type! time3 time-duration)
	(if (negative? nsec-diff)
	    (begin
	      (set-time-second! time3 (- sec-diff 1))
	      (set-time-nanosecond! time3 (+ tm:nano nsec-diff)))
	    (begin
	      (set-time-second! time3 sec-diff)
	      (set-time-nanosecond! time3 nsec-diff)))
	time3)))

(define (time-difference time1 time2)
  (tm:time-difference time1 time2 (make <time>)))

(define (time-difference! time1 time2)
  (tm:time-difference time1 time2 time1))

(define (tm:add-duration time1 duration time3)
  (when (not (and (time? time1) (time? duration)))
    (errorf "add-duration: incompatible type types: ~a ~a"
            time1 duration))
  (tm:check-time-type duration 'time-duration 'add-duration)
  (let ((sec-plus (+ (time-second time1) (time-second duration)))
        (nsec-plus (+ (time-nanosecond time1) (time-nanosecond duration))) )
    (let ((r (remainder nsec-plus tm:nano))
          (q (quotient nsec-plus tm:nano)))
      (if (negative? r)
          (begin
            (set-time-second! time3 (+ sec-plus q -1))
            (set-time-nanosecond! time3 (+ tm:nano r)))
          (begin
            (set-time-second! time3 (+ sec-plus q))
            (set-time-nanosecond! time3 r)))
      time3)))

(define (add-duration time1 duration)
  (tm:add-duration time1 duration (make <time> :type (time-type time1))))

(define (add-duration! time1 duration)
  (tm:add-duration time1 duration time1))

(define (tm:subtract-duration time1 duration time3)
  (when (not (and (time? time1) (time? duration)))
    (errorf "subtract-duration: incompatible type types: ~a ~a"
            time1 duration))
  (tm:check-time-type duration 'time-duration 'subtract-duration)
  (let ((sec-minus  (- (time-second time1) (time-second duration)))
        (nsec-minus (- (time-nanosecond time1) (time-nanosecond duration))) )
    (let ((r (remainder nsec-minus tm:nano))
          (q (quotient nsec-minus tm:nano)))
      (if (negative? r)
          (begin
            (set-time-second! time3 (- sec-minus q 1))
            (set-time-nanosecond! time3 (+ tm:nano r)))
          (begin
            (set-time-second! time3 (- sec-minus q))
            (set-time-nanosecond! time3 r)))
      time3)))

(define (subtract-duration time1 duration)
  (tm:subtract-duration time1 duration (make <time> :type (time-type time1))))

(define (subtract-duration! time1 duration)
  (tm:subtract-duration time1 duration time1))

;; -- Converters between types.

(define (tm:time-tai->time-utc! time-in time-out caller)
  (tm:check-time-type time-in 'time-tai caller)
  (set-time-type! time-out time-utc)
  (set-time-nanosecond! time-out (time-nanosecond time-in))
  (set-time-second!     time-out (- (time-second time-in)
				    (tm:leap-second-delta 
				     (time-second time-in))))
  time-out)

(define (time-tai->time-utc time-in)
  (tm:time-tai->time-utc! time-in (make <time>) 'time-tai->time-utc))

(define (time-tai->time-utc! time-in)
  (tm:time-tai->time-utc! time-in time-in 'time-tai->time-utc!))


(define (tm:time-utc->time-tai! time-in time-out caller)
  (tm:check-time-type time-in 'time-utc caller)
  (set-time-type! time-out time-tai)
  (set-time-nanosecond! time-out (time-nanosecond time-in))
  (set-time-second!     time-out (+ (time-second time-in)
				    (tm:leap-second-delta 
				     (time-second time-in))))
  time-out)

(define (time-utc->time-tai time-in)
  (tm:time-utc->time-tai! time-in (make <time>) 'time-utc->time-tai))

(define (time-utc->time-tai! time-in)
  (tm:time-utc->time-tai! time-in time-in 'time-utc->time-tai!))

;; -- these depend on time-monotonic having the same definition as time-tai!
(define (time-monotonic->time-utc time-in)
  (tm:check-time-type time-in 'time-monotonic 'time-monotonic->time-utc)
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-tai)
  (tm:time-tai->time-utc! ntime ntime 'time-monotonic->time-utc)))

(define (time-monotonic->time-utc! time-in)
  (tm:check-time-type time-in 'time-monotonic 'time-monotonic->time-utc!)
  (set-time-type! time-in time-tai)
  (tm:time-tai->time-utc! ntime ntime 'time-monotonic->time-utc))

(define (time-monotonic->time-tai time-in)
  (tm:check-time-type time-in 'time-monotonic 'time-monotonic->time-tai)
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-tai)
    ntime))

(define (time-monotonic->time-tai! time-in)
  (tm:check-time-type time-in 'time-monotonic 'time-monotonic->time-tai!)
  (set-time-type! time-in time-tai)
  time-in)

(define (time-utc->time-monotonic time-in)
  (tm:check-time-type time-in 'time-utc 'time-utc->time-monotonic)
  (let ((ntime (tm:time-utc->time-tai! time-in (make <time>)
				       'time-utc->time-monotonic)))
    (set-time-type! ntime time-monotonic)
    ntime))


(define (time-utc->time-monotonic! time-in)
  (tm:check-time-type time-in 'time-utc 'time-utc->time-monotonic!)
  (let ((ntime (tm:time-utc->time-tai! time-in time-in
				       'time-utc->time-monotonic!)))
    (set-time-type! ntime time-monotonic)
    ntime))


(define (time-tai->time-monotonic time-in)
  (tm:check-time-type time-in 'time-tai 'time-tai->time-monotonic)
  (let ((ntime (copy-time time-in)))
    (set-time-type! ntime time-monotonic)
    ntime))

(define (time-tai->time-monotonic! time-in)
  (tm:check-time-type time-in 'time-tai 'time-tai->time-monotonic!)
  (set-time-type! time-in time-monotonic)
  time-in)

;; -- Date Structures

(define-class <date> ()
  ((nanosecond :init-keyword :nanosecond :getter date-nanosecond)
   (second     :init-keyword :second     :getter date-second)
   (minute     :init-keyword :minute     :getter date-minute)
   (hour       :init-keyword :hour       :getter date-hour)
   (day        :init-keyword :day        :getter date-day)
   (month      :init-keyword :month      :getter date-month)
   (year       :init-keyword :year       :getter date-year)
   (zone-offset :init-keyword :zone-offset :getter date-zone-offset)))

(define (date? obj) (is-a? obj <date>))

(define (make-date nanosecond second minute hour day month year zone-offset)
  (make <date>
    :nanosecond nanosecond :second second :minute minute :hour hour
    :day day :month month :year year :zone-offset zone-offset))

(define-method write-object ((obj <date>) port)
  (format port "#<date ~d/~2,'0d/~2,'0d ~2,'0d:~2,'0d:~2,'0d.~9,'0d (~a)>"
          (date-year obj) (date-month obj) (date-day obj)
          (date-hour obj) (date-minute obj) (date-second obj)
          (date-nanosecond obj) (date-zone-offset obj)))

;; gives the julian day which starts at noon.
(define (tm:encode-julian-day-number day month year)
  (let* ((a (quotient (- 14 month) 12))
	 (y (- (+ year 4800) a (if (negative? year) -1  0)))
	 (m (- (+ month (* 12 a)) 3)))
    (+ day
       (quotient (+ (* 153 m) 2) 5)
       (* 365 y)
       (quotient y 4)
       (- (quotient y 100))
       (quotient y 400)
       -32045)))

(define (tm:split-real r)
  (receive (frac int) (modf r) (values int frac)))

;; Gives the seconds/date/month/year
;; In Gauche, jdn is scaled by tm:sid to avoid precision loss.
(define (tm:decode-julian-day-number jdn)
  (let* ((days (inexact->exact (truncate (/ jdn tm:sid))))
	 (a (+ days 32044))
	 (b (quotient (+ (* 4 a) 3) 146097))
	 (c (- a (quotient (* 146097 b) 4)))
	 (d (quotient (+ (* 4 c) 3) 1461))
	 (e (- c (quotient (* 1461 d) 4)))
	 (m (quotient (+ (* 5 e) 2) 153))
	 (y (+ (* 100 b) d -4800 (quotient m 10))))
    (values ; seconds date month year
     (- jdn (* days tm:sid))
     (+ e (- (quotient (+ (* 153 m) 2) 5)) 1)
     (+ m 3 (* -12 (quotient m 10)))
     (if (>= 0 y) (- y 1) y))
    ))

;; Offset of local timezone in seconds.
;; System-dependent.

(define (tm:local-tz-offset)
  (define (tm->seconds-in-year tm)
    (+ (cond ((assv (+ (slot-ref tm 'mon) 1) tm:month-assoc) =>
              (lambda (p)
                (* (+ (cdr p)
                      (slot-ref tm 'mday)
                      (if (and (> (car p) 2)
                               (tm:leap-year? (slot-ref tm 'year)))
                          1 0))
                   3600 24)))
             (else (error "something wrong")))
       (* (slot-ref tm 'hour) 3600)
       (* (slot-ref tm 'min) 60)))
  (let* ((now   (sys-time))
         (local (sys-localtime now))
         (local-sec (tm->seconds-in-year local))
         (local-yr  (slot-ref local 'year))
         (gm    (sys-gmtime now))
         (gm-sec (tm->seconds-in-year gm))
         (gm-yr  (slot-ref gm 'year)))
    (cond ((= local-yr gm-yr)
           (- local-sec gm-sec))
          ;; The following two cases are very rare, when this function is
          ;; called very close to the year boundary.
          ((< local-yr gm-yr)
           (- (- local-sec
                 (if (tm:leap-year? (slot-ref local 'year)) 31622400 31536000))
              gm-sec))
          (else
           (- local-sec
              (- gm-sec
                 (if (tm:leap-year? (slot-ref gm 'year)) 31622400 31536000))))
          )))

;; special thing -- ignores nanos
;; Gauche doesn't have exact rational arithmetic.  To avoid precision loss,
;; the result is scaled by tm:sid.
(define (tm:time->julian-day-number seconds tz-offset)
  (+ (+ seconds tz-offset tm:sihd)
     (inexact->exact (* tm:tai-epoch-in-jd tm:sid))))

(define (tm:leap-second? second)
  (and (assoc second tm:leap-second-table) #t))

(define (time-utc->date time . tz-offset)
  (tm:check-time-type time 'time-utc 'time-utc->date)
  (let-optionals* tz-offset ((offset (tm:local-tz-offset)))
    (let ((is-leap-second (tm:leap-second? (+ offset (time-second time)))))
      (receive (secs date month year)
	  (if is-leap-second
	      (tm:decode-julian-day-number (tm:time->julian-day-number (- (time-second time) 1) offset))
	      (tm:decode-julian-day-number (tm:time->julian-day-number (time-second time) offset)))
        (let* ( (hours    (quotient secs (* 60 60)))
		(rem      (remainder secs (* 60 60)))
		(minutes  (quotient rem 60))
		(seconds  (remainder rem 60)) )
	  (make-date (time-nanosecond time)
		     (if is-leap-second (+ seconds 1) seconds)
		     minutes
		     hours
		     date
		     month
		     year
		     offset))))))

(define (time-tai->date time  . tz-offset)
  (tm:check-time-type time 'time-tai 'time-tai->date)
  (let-optionals* tz-offset ((offset (tm:local-tz-offset)))
    (let* ((seconds (- (time-second time) (tm:leap-second-delta (time-second time))))
           (is-leap-second (tm:leap-second? (+ offset seconds))) )
      (receive (secs date month year)
	  (if is-leap-second
	      (tm:decode-julian-day-number (tm:time->julian-day-number (- seconds 1) offset))
	      (tm:decode-julian-day-number (tm:time->julian-day-number seconds offset)))
	;; adjust for leap seconds if necessary ...
	(let* ( (hours    (quotient secs (* 60 60)))
		(rem      (remainder secs (* 60 60)))
		(minutes  (quotient rem 60))
		(seconds  (remainder rem 60)) )
	  (make-date (time-nanosecond time)
		     (if is-leap-second (+ seconds 1) seconds)
		     minutes
		     hours
		     date
		     month
		     year
		     offset))))))

;; this is the same as time-tai->date.
(define (time-monotonic->date time . tz-offset)
  (tm:check-time-type time 'time-monotonic 'time-monotonic->date)
  (let-optionals* tz-offset ((offset (tm:local-tz-offset)))
    (let* ((seconds (- (time-second time) (tm:leap-second-delta (time-second time))))
           (is-leap-second (tm:leap-second? (+ offset seconds))) )
      (receive (secs date month year)
	  (if is-leap-second
	      (tm:decode-julian-day-number (tm:time->julian-day-number (- seconds 1) offset))
	      (tm:decode-julian-day-number (tm:time->julian-day-number seconds offset)))
	;; adjust for leap seconds if necessary ...
	(let* ( (hours    (quotient secs (* 60 60)))
		(rem      (remainder secs (* 60 60)))
		(minutes  (quotient rem 60))
		(seconds  (remainder rem 60)) )
	  (make-date (time-nanosecond time)
		     (if is-leap-second (+ seconds 1) seconds)
		     minutes
		     hours
		     date
		     month
		     year
		     offset))))))

(define (date->time-utc date)
  (let ( (nanosecond (date-nanosecond date))
	 (second (date-second date))
	 (minute (date-minute date))
	 (hour (date-hour date))
	 (day (date-day date))
	 (month (date-month date))
	 (year (date-year date))
         (offset (date-zone-offset date)) )
    (let ( (jdays (- (tm:encode-julian-day-number day month year)
		     tm:tai-epoch-in-jd)) )
      (make-time 
       time-utc
       (+ (* (- jdays 1/2) 24 60 60)
	  (* hour 60 60)
	  (* minute 60)
	  second
          (- offset))
       nanosecond))))

(define (date->time-tai date)
  (time-utc->time-tai! (date->time-utc date)))

(define (date->time-monotonic date)
  (time-utc->time-monotonic! (date->time-utc date)))

(define (tm:leap-year? year)
  (or (= (modulo year 400) 0)
      (and (= (modulo year 4) 0) (not (= (modulo year 100) 0)))))

(define (leap-year? date)
  (tm:leap-year? (date-year date)))

(define  tm:month-assoc '((1 . 0)  (2 . 31)  (3 . 59)   (4 . 90)   (5 . 120) 
			  (6 . 151) (7 . 181)  (8 . 212)  (9 . 243)
			  (10 . 273) (11 . 304) (12 . 334)))

(define (tm:year-day day month year)
  (let ((days-pr (assoc month tm:month-assoc)))
    (if (not days-pr)
        (errorf "date-year-day: invalid month: ~a" month))
    (if (and (tm:leap-year? year) (> month 2))
	(+ day (cdr days-pr) 1)
	(+ day (cdr days-pr)))))

(define (date-year-day date)
  (tm:year-day (date-day date) (date-month date) (date-year date)))

;; from calendar faq 
(define (tm:week-day day month year)
  (let* ((a (quotient (- 14 month) 12))
	 (y (- year a))
	 (m (+ month (* 12 a) -2)))
    (modulo (+ day y (quotient y 4) (- (quotient y 100))
	       (quotient y 400) (quotient (* 31 m) 12))
	    7)))

(define (date-week-day date)
  (tm:week-day (date-day date) (date-month date) (date-year date)))

(define (tm:days-before-first-week date day-of-week-starting-week)
    (let* ( (first-day (make-date 0 0 0 0
				  1
				  1
				  (date-year date)
				  #f))
	    (fdweek-day (date-week-day first-day))  )
      (modulo (- day-of-week-starting-week fdweek-day)
	      7)))

(define (date-week-number date day-of-week-starting-week)
  (quotient (- (date-year-day date)
	       (tm:days-before-first-week  date day-of-week-starting-week))
	    7))
    
(define (current-date . tz-offset)
  (let-optionals* tz-offset ((off (tm:local-tz-offset)))
    (time-utc->date (current-time time-utc) off)))

;; given a 'two digit' number, find the year within 50 years +/-
(define (tm:natural-year n)
  (let* ( (current-year (date-year (current-date)))
	  (current-century (* (quotient current-year 100) 100)) )
    (cond
     ((>= n 100) n)
     ((<  n 0) n)
     ((<=  (- (+ current-century n) current-year) 50)
      (+ current-century n))
     (else
      (+ (- current-century 100) n)))))

(define (date->julian-day date)
  (let ( (nanosecond (date-nanosecond date))
	 (second (date-second date))
	 (minute (date-minute date))
	 (hour (date-hour date))
	 (day (date-day date))
	 (month (date-month date))
	 (year (date-year date)) )
    (+ (tm:encode-julian-day-number day month year)
       (- 1/2)
       (+ (/ (+ (* hour 60 60)
		(* minute 60)
		second
		(/ nanosecond tm:nano))
	     tm:sid)))))

(define (date->modified-julian-day date)
  (- (date->julian-day date)
     4800001/2))


(define (time-utc->julian-day time)
  (tm:check-time-type time 'time-utc 'time-utc->julian-day)
  (+ (/ (+ (time-second time) (/ (time-nanosecond time) tm:nano))
	tm:sid)
     tm:tai-epoch-in-jd))

(define (time-utc->modified-julian-day time)
  (- (time-utc->julian-day time)
       4800001/2))

(define (time-tai->julian-day time)
  (tm:check-time-type time 'time-tai 'time-tai->julian-day)
  (+ (/ (+ (- (time-second time) 
	      (tm:leap-second-delta (time-second time)))
	   (/ (time-nanosecond time) tm:nano))
	tm:sid)
     tm:tai-epoch-in-jd))

(define (time-tai->modified-julian-day time)
  (- (time-tai->julian-day time)
     4800001/2))

;; this is the same as time-tai->julian-day
(define (time-monotonic->julian-day time)
  (tm:check-time-type time 'time-monotonic 'time-monotonic->julian-day)
  (+ (/ (+ (- (time-second time) 
	      (tm:leap-second-delta (time-second time)))
	   (/ (time-nanosecond time) tm:nano))
	tm:sid)
     tm:tai-epoch-in-jd))


(define (time-monotonic->modified-julian-day time)
  (- (time-monotonic->julian-day time)
     4800001/2))


(define (julian-day->time-utc jdn)
 (let ( (secs (* tm:sid (- jdn tm:tai-epoch-in-jd))) )
    (receive (seconds parts)
	     (tm:split-real secs)
	     (make-time time-utc 
			(inexact->exact seconds)
			(inexact->exact (truncate (* parts tm:nano)))))))

(define (julian-day->time-tai jdn)
  (time-utc->time-tai! (julian-day->time-utc jdn)))
			 
(define (julian-day->time-monotonic jdn)
  (time-utc->time-monotonic! (julian-day->time-utc jdn)))

(define (julian-day->date jdn . tz-offset)
  (let-optionals* tz-offset ((offset (tm:local-tz-offset)))
    (time-utc->date (julian-day->time-utc jdn) offset)))

(define (modified-julian-day->date jdn . tz-offset)
  (let-optionals* tz-offset ((offset (tm:local-tz-offset)))
    (julian-day->date (+ jdn 4800001/2) offset)))

(define (modified-julian-day->time-utc jdn)
  (julian-day->time-utc (+ jdn 4800001/2)))

(define (modified-julian-day->time-tai jdn)
  (julian-day->time-tai (+ jdn 4800001/2)))

(define (modified-julian-day->time-monotonic jdn)
  (julian-day->time-monotonic (+ jdn 4800001/2)))

(define (current-julian-day)
  (time-utc->julian-day (current-time time-utc)))

(define (current-modified-julian-day)
  (time-utc->modified-julian-day (current-time time-utc)))

(autoload "srfi-19/format" date->string string->date)

(provide "srfi-19")
