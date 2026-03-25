;;; init-packages.el --- Package setup -*- lexical-binding: t; -*-

(require 'package)

(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/"))
      package-archive-priorities '(("gnu" . 3)
                                   ("nongnu" . 2)
                                   ("melpa" . 1)))

(package-initialize)

(dolist (pkg '(magit markdown-mode diff-hl))
  (unless (package-installed-p pkg)
    (package-refresh-contents)
    (package-install pkg)))

(provide 'init-packages)
