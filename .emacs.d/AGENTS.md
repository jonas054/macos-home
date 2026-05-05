# Purpose

This file tells Copilot (and contributors) where Emacs stores its internal documentation on macOS/Homebrew installs and how to access it programmatically and interactively.

# Key locations

- Emacs binary (symlink): $(which emacs)  (example on this machine: /opt/homebrew/bin/emacs)
- Homebrew Cellar (example): /opt/homebrew/Cellar/emacs-plus@30/\<version>/
- Emacs data directory (contains "lisp/" and other runtime files): share/emacs/\<version>/ or the value of Emacs's data-directory
- Emacs lisp tree (source & docstrings): <data-directory>/lisp/ (contains *.el and *.elc files)
- Info manual files (GNU Info): /usr/share/info, /usr/local/share/info, or Homebrew's /opt/homebrew/share/info/ (look for emacs, emacs.info, dir)
- macOS app bundle (if installed): /Applications/Emacs.app (Contents/Resources/)

# Useful commands

- Locate emacs binary and symlink target:
  which emacs
  ls -l $(which emacs)

- Print Emacs data-directory (programmatic):
  emacs --batch --eval '(princ data-directory)'

- Print the lisp directory path:
  emacs --batch --eval '(princ (expand-file-name "lisp" data-directory))'

- List Info files installed by Emacs (example):
  ls -l /opt/homebrew/share/info | grep -i emacs || ls -l /usr/local/share/info | grep -i emacs || ls -l /usr/share/info | grep -i emacs

- Open the Emacs manual using the system info command:
  info emacs
  info -d /opt/homebrew/share/info  # (specify directory if needed)

- From inside Emacs (interactive help):
  - M-x info  (browse manuals)
  - C-h f FUNCTION  (describe function)
  - C-h v VARIABLE  (describe variable)
  - C-h k KEY  (describe key binding)

# Programmatic tips for automation

- To get a stable data-directory value in scripts, call Emacs in batch mode and print data-directory (see command above). Use that to construct the lisp and Info paths.
- Homebrew installs commonly symlink share/info/emacs -> Cellar path. Follow symlinks with ls -l or readlink when needed.

# Notes

- Paths depend on install method: Homebrew, packaged Emacs.app, or system-provided Emacs. Use the commands above to discover exact locations on the host.
- Elisp docstrings live in the .el (source) and .elc (compiled) files in the lisp/ tree; the Info manuals are separate formatted help files used by the info program and M-x info.
