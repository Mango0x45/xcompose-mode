;;; xcompose-mode --- XCompose support for Emacs  -*- lexical-binding: t; -*-

;; Copyright © 2025 Thomas Voss

;; Author:   Thomas Voss <mail@thomasvoss.com>
;; Created:  June 2025
;; Keywords: languages xcompose
;; URL:      https://git.thomasvoss.com/xcompose-mdoe
;; Version:  1.0.0

;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;;; Commentary:

;; This file provides the major mode xcompose-mode, for use in editing
;; .XCompose files, which are used in X-windows systems to define the
;; behavior certain sequential keystroke combinations, usually involving
;; the ‘Multi-Key’.
;;
;; This file is derived from ‘xcompose-mode.el’ found at the following
;; address:
;; https://github.com/kragen/xcompose/blob/master/xcompose-mode.el

;;; Code:

;;;###autoload
(dolist (path (list "\\`/usr/share/X11/locale/[^/]+/Compose\\'"
                    "\\.XCompose\\'"
                    (getenv "XCOMPOSEFILE")))
  (when path
    (add-to-list 'auto-mode-alist path)))


;;; Faces

(defface xcompose-angle-face
  '((t (:inherit bold)))
  "Face for the angle brackets (<>) around key-names."
  :group 'xcompose)

(defface xcompose-keys-face
  '((t (:inherit font-lock-constant-face)))
  "Face for the key names."
  :group 'xcompose)

(defface xcompose-string-face
  '((t (:inherit font-lock-string-face)))
  "Face for the quoted strings containing the character(s) to be produced."
  :group 'xcompose)

(defface xcompose-number-face
  '((t (:inherit font-lock-preprocessor-face :weight bold)))
  "Face for the hex numbers identifying the code-point."
  :group 'xcompose)

(defface xcompose-colon-face
  '((t (:inherit bold)))
  "Face for the \":\" separating the keystrokes from the character string."
  :group 'xcompose)

(defface xcompose-keyword-face
  '((t (:inherit font-lock-keyword-face)))
  "Face for keywords."
  :group 'xcompose)

(defface xcompose-modifier-face
  '((t (:inherit font-lock-keyword-face)))
  "Face for modifiers."
  :group 'xcompose)

(defface xcompose-modifier-prefix-face
  '((t . ()))
  "Face for modifier prefixes."
  :group 'xcompose)


;;; Customisable Variables

(defgroup xcompose nil
  "Customization group for `xcompose'."
  :prefix "xcompose-"
  :group 'languages)

(defcustom xcompose-rule-style 'string-codepoint
  "TODO"
  :type '(choice (const :tag "Codepoint only" codepoint)
                 (const :tag "String and codepoint" string-codepoint)
                 (const :tag "String only" string))
  :package-version '(xcompose . "1.0.0")
  :group 'xcompose)


;;; Variables

(defvar xcompose-mode-syntax-table
  (let ((st (make-syntax-table text-mode-syntax-table)))
    (dolist (pair '((?<  . "(>  ")
                    (?>  . ")<  ")
                    (?#  . "<   ")
                    (?_  . "_   ")
                    (?\n . ">   ")
                    (?{  . "|   ")
                    (?}  . "|   ")))
      (modify-syntax-entry (car pair) (cdr pair) st))
    st)
  "Syntax table for xcompose-mode")

(defvar xcompose-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "C-c C-i" #'xcompose-insert-rule)
    map)
  "Keymap for xcompose-mode")

(defvar xcompose--modifier-rx
  (regexp-opt '("Ctrl" "Lock" "Caps" "Shift" "Alt" "Meta" "None")))

(defvar xcompose-font-lock-keywords
  `(("[<>]"                  . 'xcompose-angle-face)
    ("<\\([a-zA-Z0-9_]*\\)>" . (1 'xcompose-keys-face))
    ("\"[^\"]*\""            . 'xcompose-string-face)
    ("U[0-9A-Fa-f]\\{4,6\\}" . 'xcompose-number-face)
    (,xcompose--modifier-rx  . 'xcompose-modifier-face)
    ("[!~]"                  . 'xcompose-modifier-prefix-face)
    (":"                     . 'xcompose-colon-face)
    ("^[ \t]*include"        . 'xcompose-keyword-face))
  "Keywords for xcompose-mode")

(defvar xcompose-key-regexp "<[a-zA-Z0-9_]+"
  "Regexp matching the beginning of a keystroke.")

;; I wonder if this will be useful or really annoying.
(define-abbrev-table 'xcompose-mode-abbrev-table
  '(("<am"       "<ampersand>"    nil :system t)
    ("<ap"       "<apostrophe>"   nil :system t)
    ("<asciic"   "<asciicircum>"  nil :system t)
    ("<asciit"   "<asciitilde>"   nil :system t)
    ("<ast"      "<asterisk>"     nil :system t)
    ("<bac"      "<backslash>"    nil :system t)
    ("<bar"      "<bar>"          nil :system t)
    ("<bracel"   "<braceleft>"    nil :system t)
    ("<bracer"   "<braceright>"   nil :system t)
    ("<bracketl" "<bracketleft>"  nil :system t)
    ("<bracketr" "<bracketright>" nil :system t)
    ("<col"      "<colon>"        nil :system t)
    ("<com"      "<comma>"        nil :system t)
    ("<do"       "<dollar>"       nil :system t)
    ("<gra"      "<grave>"        nil :system t)
    ("<gre"      "<greater>"      nil :system t)
    ("<le"       "<less>"         nil :system t)
    ("<mi"       "<minus>"        nil :system t)
    ("<nu"       "<numbersign>"   nil :system t)
    ("<parenl"   "<parenleft>"    nil :system t)
    ("<parenr"   "<parenright>"   nil :system t)
    ("<perc"     "<percent>"      nil :system t)
    ("<peri"     "<period>"       nil :system t)
    ("<pl"       "<plus>"         nil :system t)
    ("<quo"      "<quotedbl>"     nil :system t)
    ("<se"       "<semicolon>"    nil :system t)
    ("<sp"       "<space>"        nil :system t)
    ("<un"       "<underscore>"   nil :system t)
    ("<Mu"       "<Multi_key>"    nil :system t))
  "Abbrev table"
  :regexp "\\(<[a-zA-Z0-9_]+\\)"
  :case-fixed t)


;;; Functions

(defun xcompose--insert-key (key)
  (insert ?< key "> "))

(defun xcompose-insert-rule ()
  "TODO"
  (interactive)
  (let ((keys (vconcat (read-string (format-prompt "Key sequence" nil))))
        (rune (read-char-from-minibuffer (format-prompt "Resulting rune" nil))))
    (seq-do #'xcompose--insert-key keys)
    (insert ": ")
    (pcase xcompose-rule-style
      ('codepoint
       (insert (format "U%04X" rune)))
      ('string
       (insert ?\" rune ?\"))
      ('string-codepoint
       (insert (format "\"%c\" U%04X" rune rune))))))

;;;###autoload
(define-derived-mode xcompose-mode conf-mode "XCompose"
  "Major mode for .XCompose files

\\{xcompose-mode-map}"
  :group 'xcompose
  (font-lock-add-keywords nil xcompose-font-lock-keywords)
  (setq-local comment-start "# "
              comment-start-skip "#+\\s-*"
              comment-end ""))

(provide 'xcompose-mode)
;;; xcompose-mode.el ends here