---
name: duplicated-code-search
description: "Search for duplicated code in the current repository using the `dupfind` tool and fix it."
---

# Duplicated Code Search

## Description

This skill uses `dupfind` — a compiled binary at `/Users/jarv/bin/dupfind` — to detect duplicated code in a repository and then fixes the duplications found.

## Trigger phrases

- "find duplicated code"
- "detect code duplication"
- "run dupfind"
- "check for code duplication"
- "find repeated code"
- "eliminate code duplication"

## How to invoke

Use this skill when the user asks to find or fix duplicated code in the current repository.

## Behavior

When invoked, this skill will:

1. **Learn the tool's flags** by running `dupfind --help` if unfamiliar with the current version.

2. **Run dupfind** on the relevant source files, excluding generated directories:
   ```
   dupfind -v -x target -e .kt
   ```
   Key flags:
   - `-v` — verbose: show the duplicated content, not just file locations
   - `-e <extension>` — search recursively for files with this extension (e.g. `.kt`, `.java`, `.rb`)
   - `-x <substring>` — exclude any path containing this substring (use `-x target` to skip Maven build output)
   - `-m <n>` — report all duplications above N characters (default reports the 5 longest)

3. **Analyse the output** — dupfind reports each duplication group with:
   - File path and line number of each instance
   - Character count and line count of the duplicated block
   - The first ~100 characters of the duplicated content

4. **Fix duplications** by extracting helpers, applying the following strategies based on context:

   | Duplication pattern | Fix |
   |---|---|
   | Repeated setup/action calls in tests | Extract a private helper method |
   | Repeated assertion blocks in tests | Extract a lambda returning `SomeDsl.() -> Unit` |
   | Tests that differ only in one parameter | Use a parameterized test (`@CsvSource`, `@NullAndEmptySource`, `@ValueSource`) |
   | Logic extracted to a private method called only once | Inline the private method back |
   | Repeated boilerplate with one varying sub-expression | Use a default parameter on the helper |

5. **Re-run dupfind** after each round of fixes to check whether duplications remain.

6. **Verify tests pass** after every change using the project's test runner, for example:
   ```
   mvn -Dtest=<TestClass> test   # Maven (Java/Kotlin)
   pnpm test                     # Node.js
   poetry run pytest             # Python
   ```
   Check the project's `README`, `package.json`, `Makefile`, or CI configuration to find the correct command if unsure.

7. **Distinguish real vs. structural duplication** — some dupfind findings are unavoidable and should be left alone:
   - Shared annotations across sibling classes
   - Method signatures that must repeat by framework convention
   - Package declarations and import blocks shared across files in the same package

## Notes

- Aim to fix all dupfind findings that represent genuine duplication. Stop when remaining findings are structural/unavoidable.
