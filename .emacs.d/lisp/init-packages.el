;;; init-packages.el --- Package setup -*- lexical-binding: t; -*-

(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/"))
      package-archive-priorities '(("gnu" . 3)
                                   ("nongnu" . 2)
                                   ("melpa" . 1)))

;; Disable signature checking — avoids bad-signature errors from stale GPG keys.
(setq package-check-signature nil)
;; Allow upgrading built-in packages (e.g. seq) when dependencies require it.
(setq package-install-upgrade-built-in t)

(package-initialize)

(dolist (pkg '(use-package magit markdown-mode diff-hl))
  (unless (package-installed-p pkg)
    (package-refresh-contents)
    (package-install pkg)))

(provide 'init-packages)
