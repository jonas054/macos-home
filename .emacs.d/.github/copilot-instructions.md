# Copilot instructions

## Validation

- Use a batch-load smoke test after editing startup files: `cd /Users/jonas/.emacs.d && emacs --batch -Q --load init.el --eval '(message "init loaded")'`

## Architecture

- `init.el` is intentionally thin. It adds `lisp/` to `load-path`, loads `init-packages`, redirects Customize output into `custom.el`, and then loads the hand-written local config from `lisp/init-local.el` if that file exists.
- `lisp/init-packages.el` is only for package bootstrap. It configures `package-archives`, sets archive priorities, and runs `package-initialize`.
- `lisp/init-local.el` is the main hand-written configuration layer. It holds UI defaults, editing behavior, minor-mode enablement, per-mode exceptions, and filesystem layout for generated state.
- `custom.el` is a separate Customize-managed file that is loaded from `init.el`. Treat it as generated state, not the place for manual feature work.
- Generated Emacs state is redirected under `var/` (`var/backups/`, `var/auto-save/`, and `var/auto-save/sessions/`) instead of being scattered at the repository root.

## Repository conventions

- Keep `init.el` as an entrypoint, not a feature dump. New hand-written behavior should usually live in `lisp/` and be loaded from there.
- Preserve the split between hand-written config and Customize output: hand-edit `lisp/*.el`, but leave `custom.el` for `custom-set-variables` / `custom-set-faces`.
- Follow the existing Emacs Lisp file pattern: `lexical-binding: t` in the file header, and `provide` for reusable modules like `init-packages.el`.
- When changing compatibility-sensitive UI features, follow the existing guards such as `(when (fboundp 'tool-bar-mode) ...)` and `(when (fboundp 'scroll-bar-mode) ...)`.
- Global defaults are set once and narrowed with hooks where needed. Example: line numbers are enabled globally, then disabled specifically for `term-mode`, `shell-mode`, and `eshell-mode`.
- Keep generated filesystem paths rooted at `user-emacs-directory` via `expand-file-name`, matching the existing backup and autosave setup.
