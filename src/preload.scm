;;
;; This file is loaded when we generate some files using host's Gauche that
;; are required to build target's Gauche.    The issue is that some libraries
;; required to run the generator program may be compiled DSOs, and those
;; DSOs in ./src compiled for target's Gauche may be incompatible with
;; host's Gauche.   So we 'preload' those compiled libraries from the host
;; enviroment before we add ./src and ./lib to the *load-path*, i.e.:
;;
;;  gosh -l./preload -I./src -I./lib ....
;;
;;
;; $Id: preload.scm,v 1.1 2005-11-10 08:46:42 shirok Exp $
;;

(use gauche.collection)
(use gauche.sequence)
(use gauche.hook)
(use gauche.parameter)
(use srfi-1)
(use srfi-13)
(use file.util)
(use util.match)




