---
name: web-first
description: Use web search as the primary source of truth for current, version-sensitive, or externally verifiable information. Especially important for software development, libraries, APIs, tools, GitHub, and technical documentation.
---

# Web-First Research

Use the `web_search` tool aggressively. Model knowledge is a useful starting point, but it is not a reliable source of truth for information that may have changed.

## Core rule

**If information could have changed, search the web before answering.**

Do not decide that you "probably know" the answer and skip the search.

For technical questions, prefer current web research over knowledge from training data.

## Always search first for

* Software libraries, frameworks, languages, APIs, SDKs, and CLIs
* GitHub and GitHub Copilot
* Configuration options and command-line flags
* Library versions and compatibility
* Current documentation
* Release notes and changelogs
* Deprecated or removed functionality
* Current best practices
* Security vulnerabilities and security recommendations
* Pricing, quotas, limits, and model availability
* Current behavior of cloud services
* Current features of commercial products
* Recent developments, announcements, or changes
* Recommendations or comparisons
* Anything explicitly described as "current", "latest", "today", "recent", or similar

For software-development questions, **search before answering by default**.

## When web search is optional

Do not search for simple, stable knowledge where the answer is unlikely to have changed and web research adds little value.

Examples:

* Basic programming concepts
* Standard algorithms
* Elementary mathematics
* General language syntax that is well established
* Pure reasoning tasks
* Code transformations where the required information is already present in the user's prompt

When uncertain whether something is stable, search.

## How to search

Use `web_search` before forming the final answer.

Prefer authoritative sources, in this order:

1. Official documentation
2. Official GitHub repositories
3. Official specifications
4. Official release notes/changelogs
5. Primary-source announcements
6. High-quality secondary sources

For technical questions, search for the specific technology and version whenever possible.

For example, prefer searches such as:

* "Spring Boot 3.5 WebClient configuration official documentation"
* "GitHub Copilot CLI skills SKILL.md official documentation"
* "React 19 useEffect official documentation"

rather than relying on remembered information.

## Verify important claims

If the answer depends on a specific technical detail, API, configuration option, version, limitation, or behavior, verify it with a source.

If multiple authoritative sources disagree, investigate the discrepancy rather than silently choosing the answer that matches model memory.

For important questions, perform multiple focused searches rather than one broad search.

## Search is not the answer

Use web search to obtain current facts, then reason about those facts yourself.

Do not blindly reproduce the search tool's answer.

The search result is evidence; it is not a substitute for analysis.

## Handling uncertainty

If web research cannot verify something:

* Say that it could not be verified.
* Distinguish verified facts from inference.
* Do not present model memory as a current fact.

If web research contradicts what you remember, prefer the current authoritative source.

## User explicitly asks for web research

If the user asks you to search the web, **always use `web_search`**. Never answer from model knowledge alone.

## Final answers

When web research materially affects the answer:

* Base current factual claims on the retrieved sources.
* Include citations when the tool provides them.
* Prefer links to the primary sources when useful.
* Clearly distinguish facts from recommendations or deductions.

Do not claim that you searched if you did not actually use the tool.
