;;; .emacs --- Compatibility loader -*- lexical-binding: t; -*-

(setq user-init-file (expand-file-name "init.el" user-emacs-directory))
(load user-init-file nil 'nomessage)
