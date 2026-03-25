# macos-home
My settings and tools

## Files

### Shell

- **`.zprofile`** – Shell profile that initializes Homebrew and adds `~/bin` to PATH.
- **`.zshrc`** – Zsh config with Git-aware prompt, aliases, and Ruby environment setup.

### Git

- **`.gitconfig`** – Git configuration with shorthand aliases.

### Emacs

- **`.emacs`** – Compatibility loader that forwards to `~/.emacs.d/init.el`.
- **`.emacs.d/init.el`** – Main Emacs entry point; loads packages, redirects Customize settings, and loads local config.
- **`.emacs.d/lisp/init-packages.el`** – Package manager setup (GNU, NonGNU, MELPA) and auto-installation of essential packages.
- **`.emacs.d/lisp/init-local.el`** – Hand-written config for UI settings, keybindings, minor modes, and Copilot integration.
- **`.emacs.d/custom.el`** – Auto-generated Customize-managed preferences (not manually edited).
- **`.emacs.d/history`**, **`ido.last`**, **`places`**, **`recentf`** – Auto-generated state files (minibuffer history, recent files, etc.).
- **`.emacs.d/transient/history.el`** – Transient command history for Magit operations.
- **`.emacs.d/.github/copilot-instructions.md`** – Documentation of the Emacs configuration architecture.

### Scripts (`bin/`)

- **`autorun`** – Wrapper that delegates to a Python-based automation tool.
- **`dupfind`** – Finds duplicate files.
- **`gd`** – Shows the diff of a specific Git commit.
- **`git_rebase`** – Rebases a fork from its upstream master branch.
- **`mlgrep`** – Multi-language pattern search tool (Ruby wrapper).

### Other

- **`.mlgrep.yml`** – Configuration for mlgrep specifying file glob patterns and directory exclusions.
