;;; init-local.el --- Hand-written Emacs settings -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore
      use-dialog-box nil
      make-backup-files t
      backup-by-copying t
      create-lockfiles t
      indent-tabs-mode nil
      tab-width 4
      kill-whole-line t)

(fset 'yes-or-no-p #'y-or-n-p)

(setq frame-title-format
      '(:eval (if buffer-file-name
                  (abbreviate-file-name buffer-file-name)
                "%b")))

(set-face-attribute 'default nil :height 140)

(setq ediff-window-setup-function #'ediff-setup-windows-plain)

(when (display-graphic-p)
  (setq ns-option-modifier nil
        ns-command-modifier 'meta))

(global-set-key (kbd "<home>") #'move-beginning-of-line)
(global-set-key (kbd "<end>") #'move-end-of-line)

(electric-pair-mode 1)
(show-paren-mode 1)
(delete-selection-mode 1)
(column-number-mode 1)
(recentf-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(global-display-line-numbers-mode 1)
(global-auto-revert-mode 1)

(ido-mode 1)
(ido-everywhere 1)

(when (require 'diff-hl nil t)
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode))

(dolist (hook '(term-mode-hook
                shell-mode-hook
                eshell-mode-hook))
  (add-hook hook (lambda () (display-line-numbers-mode 0))))

(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

(when (fboundp 'scroll-bar-mode)
  (scroll-bar-mode -1))

(let ((var-dir (expand-file-name "var/" user-emacs-directory)))
  (make-directory var-dir t)
  (setq backup-directory-alist `(("." . ,(expand-file-name "backups/" var-dir)))
        auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-save/" var-dir) t))
        auto-save-list-file-prefix (expand-file-name "auto-save/sessions/" var-dir)))

(make-directory (expand-file-name "var/backups/" user-emacs-directory) t)
(make-directory (expand-file-name "var/auto-save/sessions/" user-emacs-directory) t)

(defun set-day-colors ()
  (interactive)
  (set-foreground-color "black")
  (set-background-color "white"))

(defun set-night-colors ()
  (interactive)
  (set-background-color "black")
  (set-foreground-color "white"))

(defvar global-font-zoom-level 0
  "Number of zoom steps from the default font size. Positive = larger.")

(defun global-font-zoom--mode-line ()
  "Mode-line indicator for the current font zoom level."
  (unless (zerop global-font-zoom-level)
    (format " %s%d" (if (> global-font-zoom-level 0) "+" "") global-font-zoom-level)))

(unless (member '(:eval (global-font-zoom--mode-line)) global-mode-string)
  (setq global-mode-string
        (append (or global-mode-string '(""))
                '((:eval (global-font-zoom--mode-line))))))

(defun global-font-size-increase ()
  "Increase the default face font size by 10 (1pt)."
  (interactive)
  (let ((height (face-attribute 'default :height)))
    (set-face-attribute 'default nil :height (+ height 10)))
  (cl-incf global-font-zoom-level)
  (force-mode-line-update t))

(defun global-font-size-decrease ()
  "Decrease the default face font size by 10 (1pt)."
  (interactive)
  (let ((height (face-attribute 'default :height)))
    (when (> height 10)
      (set-face-attribute 'default nil :height (- height 10))
      (cl-decf global-font-zoom-level)))
  (force-mode-line-update t))

(global-set-key (kbd "C-+") #'global-font-size-increase)
(global-set-key (kbd "C--") #'global-font-size-decrease)

(define-key global-map [f1]   'next-error)
(global-set-key [(shift f1)]  'previous-error)
(define-key global-map [f3]   'previous-error) ; in some XEmacs versions, shift in not recognized

(define-key global-map [f5]   'set-day-colors)
(define-key global-map [f6]   'set-night-colors)

(defvar theme-cycle--index 0
  "Index into the filtered theme list for the theme cycle.")

(defvar theme-cycle-blocklist '(light-blue)
  "Themes excluded from the cycle.")

(defun theme-cycle--themes ()
  "Return available themes with `theme-cycle-blocklist' removed."
  (cl-remove-if (lambda (th) (memq th theme-cycle-blocklist))
                (custom-available-themes)))

(defun theme-cycle--load (index)
  "Disable all active custom themes, then load the theme at INDEX."
  (mapc #'disable-theme custom-enabled-themes)
  (let* ((themes (theme-cycle--themes))
         (theme  (nth (mod index (length themes)) themes)))
    (setq theme-cycle--index (mod index (length themes)))
    (load-theme theme t)
    (message "Theme: %s" theme)))

(defun theme-cycle-next ()
  "Switch to the next available custom theme."
  (interactive)
  (theme-cycle--load (1+ theme-cycle--index)))

(defun theme-cycle-prev ()
  "Switch to the previous available custom theme."
  (interactive)
  (theme-cycle--load (1- theme-cycle--index)))

(define-key global-map [C-f5] 'theme-cycle-prev)
(define-key global-map [C-f6] 'theme-cycle-next)

(define-key global-map [f2]   'call-last-kbd-macro)
(define-key global-map [f11]  'grep)
(define-key global-map [f12]  'compile)
(define-key global-map [S-left] 'windmove-left)
(define-key global-map [S-right] 'windmove-right)
(define-key global-map [S-up] 'windmove-up)
(define-key global-map [S-down] 'windmove-down)
(define-key global-map [C-S-left] 'shrink-window-horizontally)
(define-key global-map [C-S-right] 'enlarge-window-horizontally)
(define-key global-map [C-S-up] 'enlarge-window)
(define-key global-map [C-S-down] 'shrink-window)
(global-set-key [(control f11)]   'isearch-toggle-case-fold)
(global-set-key (kbd "C-.") 'dabbrev-expand) ;; M-/ takes 3 keys - too inconvenient!
(global-set-key (kbd "C-#") 'comment-or-uncomment-region)
(global-set-key (kbd "C-x C-b") 'electric-buffer-list)

;; Change between hortizontal and vertical split.
(require 'transpose-frame)
(define-key global-map [f8]   'rotate-frame-clockwise)
(define-key global-map [C-f8] 'flop-frame)
(define-key global-map [M-f8] 'toggle-truncate-lines)

(defun transpose-line-up ()
  (interactive)
  (transpose-lines 1)
  (previous-line 2)
  )
(defun transpose-line-down ()
  (next-line)
  (interactive)
  (transpose-lines 1)
  (previous-line)
  )

(defun scroll-down-1 ()
  (interactive)
  (scroll-down 1))

(defun scroll-up-1 ()
  (interactive)
  (scroll-up 1))

(global-set-key (kbd "M-p") 'transpose-line-up)
(global-set-key (kbd "M-n") 'transpose-line-down)

(global-set-key [(meta up)] 'scroll-down-1) 
(global-set-key [(meta down)]   'scroll-up-1)

(require 'use-package)

(require 'project)

(defun mdbg-translate-region (beg end)
  "Translate the selected region in the MDBG Chinese dictionary."
  (interactive "r")
  (let* ((url (concat "https://www.mdbg.net/chinese/dictionary?"
		      "page=translate&email=&trst=0&wdqtm=0&wdqcham=1&trqs="
		      (url-hexify-string (buffer-substring-no-properties beg end))
		      "&trtranslation=&trlang=1")))
    (browse-url url)))

(use-package copilot
  :ensure t
  :hook (prog-mode . copilot-mode)
  :bind (:map copilot-completion-map
              ("<tab>" . copilot-accept-completion)
              ("TAB" . copilot-accept-completion)
              ("C-<tab>" . copilot-accept-completion-by-word)
              ("C-TAB" . copilot-accept-completion-by-word)
              ("C-n" . copilot-next-completion)
              ("C-p" . copilot-previous-completion)))
