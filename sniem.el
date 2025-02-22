;;; sniem.el --- Simple united editing method -*- lexical-binding: t -*-

;; Author: SpringHan
;; Maintainer: SpringHan
;; Version: 1.0
;; Package-Requires: ((emacs "26.1") (s "2.12.0") (dash "1.12.0") (cl-lib "1.0"))
;; Homepage: https://github.com/SpringHan/sniem.git
;; Keywords: convenience, united-editing-method


;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.


;;; Commentary:

;; Simple united editing method.

;;; Code:

(require 'cl-lib)
(require 's)
(require 'dash)

(defgroup sniem nil
  "The group for sniem."
  :group 'applications)

(require 'sniem-var)
(require 'sniem-macro)
(require 'sniem-operation)


(define-minor-mode sniem-mode
  "Simple united editing method mode."
  nil nil sniem-mode-keymap
  (if sniem-mode
      (sniem--enable)
    (sniem--disable)))

;;;###autoload
(define-globalized-minor-mode global-sniem-mode
  sniem-mode sniem-initialize)

(define-minor-mode sniem-normal-mode
  "Normal mode for sniem."
  nil nil sniem-normal-state-keymap
  (when sniem-normal-mode
    (sniem-normal-mode-init)))

(define-minor-mode sniem-insert-mode
  "Insert mode for sniem."
  nil nil sniem-insert-state-keymap
  (when sniem-insert-mode
    (sniem-insert-mode-init)))

(define-minor-mode sniem-motion-mode
  "Motion mode for sniem."
  nil nil sniem-motion-state-keymap
  (when sniem-motion-mode
    (sniem-motion-mode-init)))

(define-minor-mode sniem-expand-mode
  "Expand mode for sniem."
  nil nil sniem-expand-state-keymap
  (when sniem-expand-mode
    (sniem-expand-mode-init)))

(defun sniem-normal-mode-init ()
  "Normal mode init."
  (sniem-insert-mode -1)
  (sniem-motion-mode -1)
  (sniem-expand-mode -1)
  (when current-input-method
    (toggle-input-method)
    (setq-local sniem-input-method-closed t)))

(defun sniem-insert-mode-init ()
  "Insert mode init."
  (sniem-normal-mode -1)
  (sniem-motion-mode -1)
  (sniem-expand-mode -1)
  (when sniem-input-method-closed
    (toggle-input-method)
    (setq-local sniem-input-method-closed nil)))

(defun sniem-motion-mode-init ()
  "Motion mode init."
  (sniem-normal-mode -1)
  (sniem-insert-mode -1)
  (sniem-expand-mode -1))

(defun sniem-expand-mode-init ()
  "Expand mode init."
  (sniem-normal-mode -1)
  (sniem-insert-mode -1)
  (sniem-motion-mode -1))

(defun sniem--enable ()
  "Unable sniem."
  (unless (apply #'derived-mode-p sniem-close-mode-alist)
    (unless sniem-space-command
      (setq-local sniem-space-command (key-binding (kbd "SPC"))))
    (cond ((apply #'derived-mode-p sniem-normal-mode-alist)
           (sniem-change-mode 'normal))
          ((apply #'derived-mode-p sniem-insert-mode-alist)
           (sniem-change-mode 'insert))
          (t (sniem-change-mode 'motion)))
    (add-to-list 'emulation-mode-map-alists 'sniem-normal-state-keymap)))

(defun sniem--disable ()
  "Disable sniem."
  (sniem-normal-mode -1)
  (sniem-insert-mode -1)
  (sniem-motion-mode -1))

;;; Interactive functions

(defun sniem-expand-with-catch ()
  "Enter expand mode with object catch."
  (interactive)
  (sniem-object-catch)
  (sniem-expand-mode t))

(defun sniem-expand-enter-or-quit ()
  "Quit expand mode."
  (interactive)
  (if sniem-expand-mode
      (sniem-change-mode 'normal)
    (sniem-change-mode 'expand)))

(defun sniem-execute-space-command ()
  "Execute space command."
  (interactive)
  (call-interactively sniem-space-command))

(defun sniem-quit-insert ()
  "Quit insert mode."
  (interactive)
  (sniem-change-mode 'normal))

(defun sniem-keypad ()
  "Execute the keypad command."
  (interactive)
  (let ((key (pcase last-input-event
               (120 "C-x ") (109 "M-") (98 "C-M-") (118 "C-")))
        tmp)
    (when (null key)
      (setq key (concat "C-" (char-to-string last-input-event) " ")))

    (message key)
    (catch 'stop
      (while (setq tmp (read-char))
        (if (= tmp 127)
            (setq key (substring key 0 -2))
          (when (= tmp 59)
            (keyboard-quit))
          (setq key (concat key
                            (cond ((= tmp 32) (concat (char-to-string (read-char)) " "))
                                  ((= tmp 44) "C-")
                                  ((= tmp 46) "M-")
                                  ((= tmp 47) "C-M-")
                                  (t (concat (char-to-string tmp) " "))))))
        (message key)
        (when (commandp (setq tmp (key-binding (read-kbd-macro (substring key 0 -1)))))
          (throw 'stop nil))))
    (call-interactively tmp)))

(defun sniem-move-last-point ()
  "Move the last point to current point."
  (interactive)
  (setq-local sniem-last-point (point))
  (sniem-lock-unlock-last-point))

(defun sniem-keyboard-quit ()
  "Like `keyboard-quit'.
But when it's recording kmacro and there're region, deactivate mark."
  (interactive)
  (if (and (region-active-p) defining-kbd-macro)
      (deactivate-mark)
    (keyboard-quit)))

;;; Functional functions

(defun sniem-initialize ()
  "Initialize sniem."
  (unless (minibufferp)
    (sniem-mode t)))

(defun sniem--ele-exists-p (ele list)
  "Check if ELE is belong to the LIST."
  (catch 'exists
    (dolist (item list)
      (when (equal ele item)
        (throw 'exists t)))))

(defun sniem-cursor-change ()
  "Change cursor type."
  (setq-local cursor-type (pcase (sniem-current-mode)
                            ('normal sniem-normal-mode-cursor)
                            ('insert sniem-insert-mode-cursor)
                            ('motion sniem-motion-mode-cursor)
                            (_ cursor-type))))

(defun sniem-set-leader-key (key)
  "Set the leader KEY for normal mode."
  (define-key sniem-normal-state-keymap (kbd key) sniem-leader-keymap))

(defun sniem-leader-set-key (&rest keys)
  "Bind key to leader keymap.

\(fn KEY FUNC...)
Optional argument KEYS are the keys you want to add."
  (let (key func)
    (while keys
      (setq key (pop keys)
            func (pop keys))
      (define-key sniem-leader-keymap (kbd key) func))))

(defun sniem-normal-set-key (&rest keys)
  "Bind key to normal mode keymap.

\(fn KEY FUNC...)
Optional argument KEYS are the keys you want to add."
  (let (key func)
    (while keys
      (setq key (pop keys)
            func (pop keys))
      (define-key sniem-normal-state-keymap (kbd key) func))))

(defun sniem-expand-set-key (&rest keys)
  "Bind key to expand mode keymap.

\(fn KEY FUNC...)
Optional argument KEYS are the keys you want to add."
  (let (key func)
    (while keys
      (setq key (pop keys)
            func (pop keys))
      (define-key sniem-expand-state-keymap (kbd key) func))))

(defun sniem-set-keyboard-layout (layout)
  "Set the keyboard layout, then you can use the default keymap for your layout.

LAYOUT can be qwerty, colemak or dvorak."
  (cond
   ((eq layout 'qwerty)
    (sniem-normal-set-key
     "e" 'sniem-join
     "u" 'undo
     "k" 'sniem-prev-line
     "K" 'sniem-5-prev-line
     "j" 'sniem-next-line
     "J" 'sniem-5-next-line
     "i" 'sniem-insert
     "I" 'sniem-insert-line
     "h" 'sniem-backward-char
     "H" 'sniem-5-backward-char
     "l" 'sniem-forward-char
     "L" 'sniem-5-forward-char
     "n" 'sniem-lock-unlock-last-point
     "N" 'sniem-goto-last-point
     "t" 'sniem-next-symbol
     "T" 'sniem-prev-symbol)
    (setq sniem-keyboard-layout 'qwerty))
   ((eq layout 'colemak)
    (sniem-normal-set-key
     "j" 'sniem-join
     "l" 'undo
     "u" 'sniem-prev-line
     "U" 'sniem-5-prev-line
     "e" 'sniem-next-line
     "E" 'sniem-5-next-line
     "h" 'sniem-insert
     "H" 'sniem-insert-line
     "n" 'sniem-backward-char
     "N" 'sniem-5-backward-char
     "i" 'sniem-forward-char
     "I" 'sniem-5-forward-char
     "k" 'sniem-lock-unlock-last-point
     "K" 'sniem-goto-last-point
     "t" 'sniem-next-symbol
     "T" 'sniem-prev-symbol)
    (setq sniem-keyboard-layout 'colemak))
   ((or (eq layout 'dvorak)
        (eq layout 'dvp))
    (sniem-normal-set-key
     "j" 'sniem-join
     "u" 'undo
     "e" 'sniem-prev-line
     "E" 'sniem-5-prev-line
     "n" 'sniem-next-line
     "N" 'sniem-5-next-line
     "i" 'sniem-insert
     "I" 'sniem-insert-line
     "h" 'sniem-backward-char
     "H" 'sniem-5-backward-char
     "t" 'sniem-forward-char
     "T" 'sniem-5-forward-char
     "k" 'sniem-lock-unlock-last-point
     "K" 'sniem-goto-last-point
     "l" 'sniem-next-symbol
     "L" 'sniem-prev-symbol)
    (setq sniem-keyboard-layout (if (eq layout 'dvp)
                                    'dvp
                                  'dvorak)))
   (t (user-error "[Sniem]: The %s layout is not supplied!" layout))))

(defun sniem-current-mode ()
  "Get current mode."
  (cond (sniem-normal-mode 'normal)
        (sniem-insert-mode 'insert)
        (sniem-motion-mode 'motion)
        (sniem-expand-mode 'expand)
        (t nil)))

(defun sniem-change-mode (mode)
  "Change editing MODE."
  (unless (eq (sniem-current-mode) mode)
    (pcase mode
      ('normal (sniem-normal-mode t))
      ('insert (sniem-insert-mode t))
      ('motion (sniem-motion-mode t))
      ('expand (sniem-expand-mode t)))
    (sniem-cursor-change)))

(defun sniem-digit-argument-or-fn (arg)
  "The digit argument function.
Argument ARG is the `digit-argument' result."
  (interactive (list (ignore-errors (sniem-digit-argument-get))))
  (if arg
      (if (listp arg)
          (eval arg)
        (prefix-command-preserve-state)
        (setq prefix-arg arg)
        (universal-argument--mode))
    (message "Quited digit argument")))

(defun sniem-digit-argument-fn-get (string)
  "Read the fn for `sniem-digit-argument-or-fn'.
Argument STRING is the string get from the input."
  (pcase string
    ("." 'sniem-mark-content)
    (" " 'sniem-move-with-hint-num)
    ("/" 'sniem-object-catch-direction-reverse)
    ("," 'sniem-object-catch-repeat)
    ("p" 'sniem-pair)
    ("m" 'sniem-mark-jump-insert-with-name)
    ("<" 'sniem-mark-jump-prev)
    (">" 'sniem-mark-jump-next)))

(defun sniem-digit-argument-read-char ()
  "Read char for `sniem-digit-argument'."
  (pcase sniem-keyboard-layout
    ('colemak
     (pcase (read-char)
       (97 "1") (114 "2") (115 "3") (116 "4") (100 "5")
       (104 "6") (110 "7") (101 "8") (105 "9") (111 "0")
       (39 "-") (13 "over") (127 "delete") (59 nil)
       (x (char-to-string x))))
    ('qwerty
     (pcase (read-char)
       (97 "1") (115 "2") (100 "3") (102 "4") (103 "5")
       (104 "6") (106 "7") (107 "8") (108 "9") (59 "0")
       (39 "-") (13 "over") (127 "delete") (59 nil)
       (x (char-to-string x))))
    ('dvorak
     (pcase (read-char)
       (97 "1") (111 "2") (101 "3") (117 "4") (105 "5")
       (100 "6") (104 "7") (116 "8") (110 "9") (115 "0")
       (45 "-") (13 "over") (127 "delete") (59 nil)
       (x (char-to-string x))))))

(defun sniem-mark-content (&optional mark)
  "Mark/unmark the content.
Optional Argument MARK means mark forcibly."
  (interactive "P")
  (let ((mark-content (lambda ()
                        (if (region-active-p)
                            (progn
                              (setq-local sniem-mark-content-overlay
                                          (make-overlay (region-beginning) (region-end)))
                              (deactivate-mark))
                          (setq-local sniem-mark-content-overlay
                                      (make-overlay (point) (1+ (point)))))
                        (overlay-put sniem-mark-content-overlay 'face 'region))))
    (when (overlayp sniem-mark-content-overlay)
      (delete-overlay sniem-mark-content-overlay))
    (if (or (null sniem-mark-content-overlay) mark)
        (funcall mark-content)
      (setq-local sniem-mark-content-overlay nil))))

(defun sniem-show-last-point (&optional hide)
  "Show the last point.
Optional argument HIDE is t, the last point will be show."
  (let ((cursor-color
         `((t (:foreground ,(frame-parameter nil 'background-color))
              :background ,(frame-parameter nil 'cursor-color)))))
    (if (or sniem-last-point-overlay hide)
        (progn
          (delete-overlay sniem-last-point-overlay)
          (setq-local sniem-last-point-overlay nil))
      (setq-local sniem-last-point-overlay
                  (make-overlay sniem-last-point (1+ sniem-last-point) (current-buffer) t t))
      (overlay-put sniem-last-point-overlay 'face cursor-color))))

(defun sniem-set-quit-insert-key (key)
  "Set the `sniem-quit-insert' KEY."
  (define-key sniem-insert-state-keymap (kbd sniem-insert-quit-key) 'nil)
  (define-key sniem-insert-state-keymap (kbd key) 'sniem-quit-insert)
  (setq sniem-insert-quit-key key))

;;; Initialize
(sniem-set-leader-key ",")

(require 'sniem-object-catch)
(require 'sniem-cheatsheet)
(require 'sniem-mark-jump)

;;; Third-Party Settings
(advice-add 'wdired-change-to-wdired-mode :after #'sniem-normal-mode)
(advice-add 'wdired-change-to-dired-mode :after #'sniem-motion-mode)

;;; State info print support
(defun sniem-state ()
  "The function to show the current sniem state."
  (pcase (sniem-current-mode)
    ('normal (format "[N:%s%s%s]"
                     (if sniem-object-catch-forward-p ">" "<")
                     (if sniem-last-point-locked ":l" "")
                     (if sniem-mark-content-overlay ":M" "")))
    ('insert "[I]")
    ('motion "[M]")
    ('expand (format "[E:%s]"
                     (if sniem-object-catch-forward-p ">" "<")))))
(when (featurep 'awesome-tray)
  (add-to-list 'awesome-tray-module-alist '("sniem-state" . (sniem-state awesome-tray-module-evil-face))))

(provide 'sniem)

;;; sniem.el ends here
