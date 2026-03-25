;;; init.el --- Emacs initialization -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'init-packages)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file 'noerror 'nomessage)

(let ((local-init (expand-file-name "lisp/init-local.el" user-emacs-directory)))
  (when (file-exists-p local-init)
    (load local-init nil 'nomessage)))
