;;
;; testing rfc.* module
;;

(use gauche.test)
(use gauche.sequence)
(test-start "rfc")

;;--------------------------------------------------------------------
(test-section "rfc.822")
(use rfc.822)
(test-module 'rfc.822)

(define rfc822-header1
  "Received: by foo.bar.com id ZZZ55555; Thu, 31 May 2001 16:38:04 -1000 (HST)
Received: from ooo.ooo.com (ooo.ooo.com [1.2.3.4])
	by foo.bar.com (9.9.9+3.2W/3.7W-) with ESMTP id ZZZ55555
	for <yoo@bar.com>; Thu, 31 May 2001 16:38:02 -1000 (HST)
Received: from zzz ([1.2.3.5]) by ooo.ooo.com  with Maccrosoft SMTPSVC(5.5.1877.197.19);
	 Thu, 31 May 2001 22:33:16 -0400
Message-ID: <beefbeefbeefbeef@ooo.ooo.com>
Subject: Bogus Tester
From: Bogus Sender <bogus@ooo.com>
To: You <you@bar.com>, Another <another@ooo.com>
Date: Fri, 01 Jun 2001 02:37:31 (GMT)
Mime-Version: 1.0
Content-Type: text/html
Content-Transfer-Encoding: quoted-printable
X-MSMail-Priority: Normal
X-mailer: FooMail 4.0 4.03 (SMT460B92F)
Content-Length: 4349

")

(define rfc822-header1-list
  '(("received" "by foo.bar.com id ZZZ55555; Thu, 31 May 2001 16:38:04 -1000 (HST)")
    ("received" "from ooo.ooo.com (ooo.ooo.com [1.2.3.4])	by foo.bar.com (9.9.9+3.2W/3.7W-) with ESMTP id ZZZ55555	for <yoo@bar.com>; Thu, 31 May 2001 16:38:02 -1000 (HST)")
    ("received" "from zzz ([1.2.3.5]) by ooo.ooo.com  with Maccrosoft SMTPSVC(5.5.1877.197.19);	 Thu, 31 May 2001 22:33:16 -0400")
    ("message-id" "<beefbeefbeefbeef@ooo.ooo.com>")
    ("subject" "Bogus Tester")
    ("from" "Bogus Sender <bogus@ooo.com>")
    ("to" "You <you@bar.com>, Another <another@ooo.com>")
    ("date" "Fri, 01 Jun 2001 02:37:31 (GMT)")
    ("mime-version" "1.0")
    ("content-type" "text/html")
    ("content-transfer-encoding" "quoted-printable")
    ("x-msmail-priority" "Normal")
    ("x-mailer" "FooMail 4.0 4.03 (SMT460B92F)")
    ("content-length" "4349")
    ))

(test* "rfc822-header->list" #t
       (equal? rfc822-header1-list
               (rfc822-header->list (open-input-string rfc822-header1))))

;; token parsers
(test* "rfc822-field->tokens (basic)"
       '(("aa") ("bb") ("cc") ("dd") ("ee") (" a\"aa\\aa (a)"))
       (map rfc822-field->tokens
            '("aa"
              "  bb   "
              " (comment) cc(comment)"
              " (co\\mm$$*##&$%ent) dd(com (me) nt)"
              "\"ee\""
              "  \" a\\\"aa\\\\aa (a)\" (comment\\))")))

(test* "rfc822-field->tokens"
       '("from" "aaaaa.aaa.org" "by" "ggg.gggg.net" "with" "ESMTP" "id" "24D50175C8")
       (rfc822-field->tokens
        "from aaaaa.aaa.org (aaaaa.aaa.org [192.168.0.9]) by ggg.gggg.net (Postfix) with ESMTP id 24D50175C8"))


(test* "rfc822-parse-date" '(2003 2 4 12 34 56 -3600 2)
       (receive r (rfc822-parse-date "Tue,  4 Mar 2003 12:34:56 -3600") r))

(test* "rfc822-parse-date" '(2003 2 4 12 34 56 0 2)
       (receive r (rfc822-parse-date "Tue,  4 Mar 2003 12:34:56 UT") r))

(test* "rfc822-parse-date (no weekday)" '(2003 2 4 12 34 56 -3600 #f)
       (receive r (rfc822-parse-date "4 Mar 2003 12:34:56 -3600") r))

(test* "rfc822-parse-date (no timezone)" '(2003 2 4 12 34 56 #f #f)
       (receive r (rfc822-parse-date "4 Mar 2003 12:34:56") r))

(test* "rfc822-parse-date (old tz)" '(2003 2 4 12 34 56 #f #f)
       (receive r (rfc822-parse-date "4 Mar 2003 12:34:56 jst") r))

(test* "rfc822-parse-date (no seconds)" '(2003 2 4 12 34 #f 900 #f)
       (receive r (rfc822-parse-date "4 Mar 2003 12:34 +0900") r))

(test* "rfc822-parse-date (no seconds)" '(2003 2 4 12 34 #f 900 2)
       (receive r (rfc822-parse-date "Tue, 04 Mar 2003 12:34 +0900") r))

(test* "rfc822-parse-date (2digit year)" '(2003 2 4 12 34 56 -3600 2)
       (receive r (rfc822-parse-date "Tue,  4 Mar 03 12:34:56 -3600") r))

(test* "rfc822-parse-date (2digit year)" '(1987 2 4 12 34 56 -3600 2)
       (receive r (rfc822-parse-date "Tue,  4 Mar 87 12:34:56 -3600") r))

(test* "rfc822-parse-date (Weekday, exhausive)" '(0 1 2 3 4 5 6 #f)
       (map-with-index
        (lambda (ind wday)
          (receive (y m d H M S tz wd)
              (rfc822-parse-date
               #`",|wday|, ,(+ 2 ind) Jan 2000 00:00:00 +0000")
            wd))
        '("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Znn")))

(test* "rfc822-parse-date (Months, exhausive)"
       '(0 1 2 3 4 5 6 7 8 9 10 11 #f)
       (map (lambda (mon)
              (receive (y m d H M S tz wd)
                  (rfc822-parse-date
                   #`"1 ,mon 1999 00:00:00 +0000")
                m))
            '("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug"
              "Sep" "Oct" "Nov" "Dec" "Zzz")))

(test* "rfc822-parse-date (invalid)" '(#f #f #f #f #f #f #f #f)
       (receive r (rfc822-parse-date "Sun 2 Mar 2002") r))

;;--------------------------------------------------------------------
(test-section "rfc.base64")
(use rfc.base64)
(test-module 'rfc.base64)

(test* "encode" "" (base64-encode-string ""))
(test* "encode" "YQ==" (base64-encode-string "a"))
(test* "encode" "MA==" (base64-encode-string "0"))
(test* "encode" "Cg==" (base64-encode-string "\n"))
(test* "encode" "YTA=" (base64-encode-string "a0"))
(test* "encode" "YTAK" (base64-encode-string "a0\n"))
(test* "encode" "PQk0" (base64-encode-string "=\t4"))
(test* "encode" "eTQ5YQ==" (base64-encode-string "y49a"))
(test* "encode" "RWdqYWk=" (base64-encode-string "Egjai"))
(test* "encode" "OTNiamFl" (base64-encode-string "93bjae"))
(test* "encode" "QkFSMGVyOQ==" (base64-encode-string "BAR0er9"))

(test* "decode" "" (base64-decode-string ""))
(test* "decode" "a" (base64-decode-string "YQ=="))
(test* "decode" "a" (base64-decode-string "YQ="))
(test* "decode" "a" (base64-decode-string "YQ"))
(test* "decode" "a0" (base64-decode-string "YTA="))
(test* "decode" "a0" (base64-decode-string "YTA"))
(test* "decode" "a0\n" (base64-decode-string "YTAK"))
(test* "decode" "y49a" (base64-decode-string "eTQ5YQ=="))
(test* "decode" "Egjai" (base64-decode-string "RWdqYWk="))
(test* "decode" "93bjae" (base64-decode-string "OTNiamFl"))
(test* "decode" "BAR0er9" (base64-decode-string "QkFSMGVyOQ=="))
(test* "decode" "BAR0er9" (base64-decode-string "QkFS\r\nMGVyOQ\r\n=="))

;;--------------------------------------------------------------------
(test-section "rfc.quoted-printable")
(use rfc.quoted-printable)
(test-module 'rfc.quoted-printable)

(test* "encode" "abcd=0Cefg"
       (quoted-printable-encode-string "abcd\x0cefg"))
(test* "encode"
       "abcd\r\nefg"
       (quoted-printable-encode-string "abcd\r\nefg"))
(test* "encode (tab/space at eol)"
       "abcd=09\r\nefg=20\r\n"
       (quoted-printable-encode-string "abcd\t\r\nefg \r\n"))
(test* "encode (soft line break)"
       "0123456789abcdefghij0123456789abcdefghij0123456789abcdefghij0123456789abc=\r\ndefghij0123456789abcdefghij"
       (quoted-printable-encode-string "0123456789abcdefghij0123456789abcdefghij0123456789abcdefghij0123456789abcdefghij0123456789abcdefghij"))

(test* "decode" "\x01\x08abcde=\r\n"
       (quoted-printable-decode-string "=01=08abc=64=65=3D\r\n"))
(test* "decode (soft line break)"
       "Now's the time for all folk to come to the aid of their country."
       (quoted-printable-decode-string "Now's the time =\r\nfor all folk to come=   \r\n to the aid of their country."))
(test* "decode (robustness)"
       "foo=1qr =  j\r\n"
       (quoted-printable-decode-string "foo=1qr =  j\r\n="))


;;--------------------------------------------------------------------
(test-section "rfc.cookie")
(use rfc.cookie)
(test-module 'rfc.cookie)

(test* "parse, old" '(("foo" "bar")
                      ("aaa" "bbb" :path "/a/b" :domain "a.b.com")
                      ("x12" "Yy \"yY\" ;; Zz" :port "100, 200, 300")
                      ("zzz" #f)
                      ("_n_" "")
                      ("mmm" "ppp"))
       (parse-cookie-string " foo=bar; aaa = bbb ; $Path=/a/b;$Domain =a.b.com;x12=\"Yy \\\"yY\\\" ;; Zz\"; $Port=\"100, 200, 300\";zzz ;_n_=;mmm=ppp"))

(test* "parse, new" '(("$Version" "1")
                      ("foo" "bar")
                      ("aaa" "bbb" :path "/a/b" :domain "a.b.com")
                      ("x12" "Yy \"yY\" ;; Zz" :port "100, 200, 300")
                      ("zzz" #f)
                      ("_n_" "")
                      ("mmm" "ppp"))
       (parse-cookie-string "$Version=1; foo=bar, aaa = bbb ; $Path=/a/b;$Domain =a.b.com,x12=\"Yy \\\"yY\\\" ;; Zz\"; $Port=\"100, 200, 300\",zzz ,_n_=,mmm=ppp"))

(test* "parse, new" '(("foo" "bar")
                      ("aaa" "bbb" :path "/a/b" :domain "a.b.com")
                      ("x12" "Yy \"yY\" ;; Zz" :port "100, 200, 300")
                      ("zzz" #f)
                      ("_n_" "")
                      ("mmm" "ppp"))
       (parse-cookie-string " foo=bar, aaa = bbb ; $Path=/a/b;$Domain =a.b.com,x12=\"Yy \\\"yY\\\" ;; Zz\"; $Port=\"100, 200, 300\",zzz ,_n_=,mmm=ppp"
                            1))

(define *cookie-spec*
  '(("guest-id" "foo123"
     :domain "foo.com" :path "/abc"
     :expires 1000000000 :max-age 864000
     :discard #t :comment "hogehoge"
     :comment-url "http://foo.com/hogehoge"
     :port "80, 8080" :version 1)
    ("guest-account" "87975348"
     :domain "zzz.com" :path "/zzz"
     :discard #f :secure #t :comment "ZzzZzz, OooOoo"
     :comment-url "http://foo.com/hogehoge")))

(test* "cookie, old"
       '("guest-id=foo123;Domain=foo.com;Path=/abc;Expires=Sun, 09-Sep-2001 01:46:40 GMT"
         "guest-account=87975348;Domain=zzz.com;Path=/zzz;Secure")
       (construct-cookie-string *cookie-spec* 0))

(test* "cookie, new"
       '("guest-id=foo123;Domain=foo.com;Path=/abc;Max-Age=864000;Discard;Comment=hogehoge;CommentURL=\"http://foo.com/hogehoge\";Port=\"80, 8080\";Version=1"
         "guest-account=87975348;Domain=zzz.com;Path=/zzz;Secure;Comment=\"ZzzZzz, OooOoo\";CommentURL=\"http://foo.com/hogehoge\"")
       (construct-cookie-string *cookie-spec* 1))

;;--------------------------------------------------------------------
(test-section "rfc.mime")
(use rfc.mime)
(test-module 'rfc.mime)

(test* "mime-parse-version" '((1 0) (1 0) (1 0) (1 0) #f)
       (map mime-parse-version
            '(" 1.0"
              " 1.0 (produced by MetaSend Vx.x) "
              " (produced by MetaSend Vx.x) 1.0"
              " 1.(produced by MetaSend Vx.x (beta))0"
              " none ")))

(test* "mime-parse-content-type" '("text" "plain")
       (mime-parse-content-type " text/plain (client: foo bar)"))
(test* "mime-parse-content-type" '("text" "plain" ("charset" . "us-ascii"))
       (mime-parse-content-type " text/plain ;charset=\"us-ascii\""))
(test* "mime-parse-content-type" '("text" "plain" ("charset" . "us-ascii"))
       (mime-parse-content-type " text/plain; charset=us-ascii (Plain Text)"))
(test* "mime-parse-content-type" '("text" "plain" ("charset" . "iso-2022-jp"))
       (mime-parse-content-type " text/(Plain Text)plain ; (Japanese) charset=iso-2022-jp"))

(test* "mime-parse-content-type"
       '("text" "plain" ("zzz" . "yyy") ("xxx" . "www"))
       (mime-parse-content-type " text/plain ;zzz=\"yyy\"; xxx = www (AAA)"))

(test* "mime-parse-content-type"
       '("multipart" "alternative"
         ("boundary" . "=_alternative 006EBAA488256DF0_="))
       (mime-parse-content-type
        "multipart/alternative; boundary=\"=_alternative 006EBAA488256DF0_=\"")
       )

(use gauche.charconv)
(when (ces-conversion-supported? "iso-8859-1" #f)
  (test* "mime-decode-word" "this is some text"
         (mime-decode-word "=?iso-8859-1?q?this=20is=20some=20text?=")))
(when (ces-conversion-supported? "us-ascii" #f)
  (test* "mime-decode-word" "Keith_Moore"
         (mime-decode-word "=?US-ASCII?Q?Keith_Moore?=")))
(when (and (memq (gauche-character-encoding) '(euc-jp sjis utf8))
           (ces-conversion-supported? "iso-2022-jp" #f))
  (test* "mime-decode-word" "\u5ddd\u5408 \u53f2\u6717"
         (mime-decode-word "=?ISO-2022-JP?B?GyRCQG45ZxsoQiAbJEI7S08vGyhC?="))
  )
;; this tests whether illegal input sequence is handled gracefully
(when (memq (gauche-character-encoding) '(euc-jp sjis utf8))
  (test* "mime-decode-word" "=?ISO-2022-JP?B?GyRCJDkbKBsoQg==?="
         (mime-decode-word "=?ISO-2022-JP?B?GyRCJDkbKBsoQg==?=")))

;; NB: this assumes the test is run either under src/ or test/
(define (mime-message-tester num)
  (let ((src #`"../test/data/rfc-mime-,|num|.txt")
        (res (call-with-input-file #`"../test/data/rfc-mime-,|num|.res.txt"
               read)))
    (call-with-input-file src
      (lambda (inp)
        (let* ((title (read-line inp)) ;; test title
               (expl  (read-line inp)) ;; explanation (ignored)
               (headers (rfc822-header->list inp)))
          (test* #`"mime-parse-message (,|num| - ,|title|)"
                 res
                 (and (equal? (mime-parse-version
                               (rfc822-header-ref headers "mime-version"))
                              '(1 0))
                      (mime-message-resolver
                       (mime-parse-message inp headers
                                           (cut mime-body->string <> <> inp))
                       #f)
                      )))))
    ))

(define (mime-message-resolver mesg parent)
  (unless (eqv? (ref mesg 'parent) parent) (error "parent link broken"))
  (list* (string-append (ref mesg 'type) "/" (ref mesg 'subtype))
         (ref mesg 'index)
         (if (string? (ref mesg 'content))
           (list (ref mesg 'content))
           (map (cut mime-message-resolver <> mesg) (ref mesg 'content)))))

(dotimes (n 5)
  (mime-message-tester n))

;;--------------------------------------------------------------------
(test-section "rfc.uri")
(use rfc.uri)
(test-module 'rfc.uri)

(test* "encode" "abc%3c%20%3e%20%22%20%23%25%7b%7c%7d%5c%5e"
       (uri-encode-string "abc< > \" #%{|}\\^"))
(test* "decode" "abc< > \" #%?{|}\\^"
       (uri-decode-string "abc%3c%20%3e%20%22%20%23%25%3f%7b%7c%7d%5c%5e"))
(test* "decode" "abc<+>+\"+#%?{|}\\^"
       (uri-decode-string "abc%3c+%3e+%22+%23%25%3f%7b%7c%7d%5c%5e"))
(test* "decode" "abc< > \" #%?{|}\\^"
       (uri-decode-string "abc%3c+%3e+%22+%23%25%3f%7b%7c%7d%5c%5e"
                          :cgi-decode #t))
(test* "decode" "%"    (uri-decode-string "%"))
(test* "decode" "a%"   (uri-decode-string "a%"))
(test* "decode" "a%y"  (uri-decode-string "a%y"))
(test* "decode" "a%ay" (uri-decode-string "a%ay"))
(test* "decode" ""     (uri-decode-string ""))

(test-end)

