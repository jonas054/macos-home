---
name: ruby-code-reviewer
description: "Review Ruby code for style violations, potential bugs, security issues, and best practices using RuboCop and custom analysis."
---

## Description

This skill reviews Ruby code for quality issues including style violations, potential bugs, security concerns, and best practices.

## Trigger phrases

- "review this Ruby code"
- "check my Ruby for issues"
- "lint my Ruby file"
- "find style violations in this Ruby"
- "run rubocop on this"
- "is this Ruby code idiomatic?"
- "audit this Ruby for problems"

## How to invoke

Use this skill when a user shares Ruby code and asks for a review, style check, or general feedback on code quality.

## Behavior

When invoked, this skill will:

1. **Run RuboCop** to detect style violations and lint errors:
   ```
   rubocop <file_or_directory>
   ```
   Use `--format json` for structured output when processing results programmatically.

2. **Analyze RuboCop output** — interpret offense severity levels:
   - `Convention` — style guide violations
   - `Warning` — potential issues worth addressing
   - `Error` / `Fatal` — serious problems that should be fixed

3. **Check for common Ruby issues** beyond RuboCop:
   - Mutable default arguments (e.g., `def foo(arr = [])`)
   - Missing `frozen_string_literal` magic comment
   - Use of `rescue Exception` instead of `rescue StandardError`
   - Unnecessary `nil` checks or redundant conditionals
   - N+1 query patterns (in Rails contexts)

4. **Assess idiomatic Ruby** — flag non-idiomatic patterns and suggest Ruby-native alternatives (e.g., prefer `map` over `each` + `push`, use `&method(:foo)` where appropriate).

5. **Report findings** grouped by severity, with file path, line number, and a clear explanation of each issue and how to fix it.

## Notes

- If RuboCop is not installed, suggest: `gem install rubocop` or adding it to the `Gemfile`
- Respect project-level `.rubocop.yml` configuration if present
- Focus on actionable, high-signal feedback — avoid noise from trivial or auto-correctable offenses unless the user specifically asks
