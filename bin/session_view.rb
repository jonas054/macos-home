#!/usr/bin/env ruby
# frozen_string_literal: true

require 'base64'
require 'cgi'
require 'etc'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'time'
require 'timeout'

DOC = <<~TEXT
  session_view - Render Copilot session events.jsonl file(s) as HTML,
                 and generate a sessions overview index.

  Usage:
      session_view                                      # batch: render all sessions, then regenerate overview
      session_view <session-id or path-to-events.jsonl> # single file, no overview
      session_view --story <path>                       # render with a Story tab (calls storyteller agent)
      session_view --story -f [-l <language>] <path>    # force-regenerate the story even if cached

  When processing multiple files (no argument), each events.jsonl is rendered in-place
  as events.html in its own directory; existing files are skipped unless events.jsonl
  or session_view itself is newer than events.html.
  After the batch pass, sessions-overview.html is regenerated automatically.

  Flags:
      --story     Generate a Story tab by calling `Copilot CLI`.
                  The story is cached as story.txt next to events.jsonl.
      --force     Re-generate story even if story.txt exists.
      --language  Language for the generated story (e.g. "Swedish" or "Frnch").
      --a11y      Use a colorblind-friendly (deuteranopia/protanopia) colour palette.
TEXT

FAVICON_SVG = <<~'SVG'
  <svg viewBox="0 0 512 416"
       xmlns="http://www.w3.org/2000/svg"
       fill-rule="evenodd"
       clip-rule="evenodd"
       stroke-linejoin="round"
       stroke-miterlimit="2">
    <path d="M181.33 266.143c0-11.497 9.32-20.818 20.818-20.818 11.498 0 20.819 9.321
             20.819 20.818v38.373c0 11.497-9.321 20.818-20.819 20.818-11.497
             0-20.818-9.32-20.818-20.818v-38.373zM308.807 245.325c-11.477 0-20.798
             9.321-20.798 20.818v38.373c0 11.497 9.32 20.818 20.798 20.818 11.497 0
             20.818-9.32 20.818-20.818v-38.373c0-11.497-9.32-20.818-20.818-20.818z"
          fill-rule="nonzero"/>
    <path d="M512.002 246.393v57.384c-.02 7.411-3.696 14.638-9.67 19.011C431.767 374.444
             344.695 416 256 416c-98.138
             0-196.379-56.542-246.33-93.21-5.975-4.374-9.65-11.6-9.671-19.012v-57.384a35.347
             35.347 0 016.857-20.922l15.583-21.085c8.336-11.312 20.757-14.31 33.98-14.31
             4.988-56.953 16.794-97.604 45.024-127.354C155.194 5.77 226.56 0 256 0c29.441 0
             100.807 5.77 154.557 62.722 28.19 29.75 40.036 70.401 45.025 127.354 13.263 0
             25.602 2.936 33.958 14.31l15.583 21.127c4.476 6.077 6.878 13.345 6.878
             20.88zm-97.666-26.075c-.677-13.058-11.292-18.19-22.338-21.824-11.64
             7.309-25.848 10.183-39.46 10.183-14.454
             0-41.432-3.47-63.872-25.869-5.667-5.625-9.527-14.454-12.155-24.247a212.902
             212.902 0 00-20.469-1.088c-6.098 0-13.099.349-20.551 1.088-2.628 9.793-6.509
             18.622-12.155 24.247-22.4 22.4-49.418 25.87-63.872 25.87-13.612
             0-27.86-2.855-39.501-10.184-11.005 3.613-21.558 8.828-22.277 21.824-1.17
             24.555-1.272 49.11-1.375 73.645-.041 12.318-.082 24.658-.288 36.976.062 7.166
             4.374 13.818 10.882 16.774 52.97 24.124 103.045 36.278 149.137 36.278 46.01 0
             96.085-12.154 149.014-36.278 6.508-2.956 10.84-9.608
             10.881-16.774.637-36.832.124-73.809-1.642-110.62h.041zM107.521 168.97c8.643
             8.623 24.966 14.392 42.56 14.392 13.448 0 39.03-2.874 60.156-24.329 9.28-8.951
             15.05-31.35
             14.413-54.079-.657-18.231-5.769-33.28-13.448-39.665-8.315-7.371-27.203-10.574-48.33-8.644-22.399
             2.238-41.267 9.588-50.875 19.833-20.798 22.728-16.323 80.317-4.476
             92.492zm130.556-56.008c.637 3.51.965 7.35 1.273 11.517 0 2.875 0 5.77-.308
             8.952 6.406-.636 11.847-.636 16.959-.636s10.553 0
             16.959.636c-.329-3.182-.329-6.077-.329-8.952.329-4.167.657-8.007
             1.294-11.517-6.735-.637-12.812-.965-17.924-.965s-11.21.328-17.924.965zm49.275-8.008c-.637
             22.728 5.133 45.128 14.413 54.08 21.105 21.454 46.708 24.328 60.155 24.328
             17.596 0 33.918-5.769 42.561-14.392 11.847-12.175
             16.322-69.764-4.476-92.492-9.608-10.245-28.476-17.595-50.875-19.833-21.127-1.93-40.015
             1.273-48.33 8.644-7.679 6.385-12.791 21.434-13.448 39.665z"/>
  </svg>
SVG
FAVICON_URI = "data:image/svg+xml;base64,#{Base64.strict_encode64(FAVICON_SVG)}"
COPILOT_IMG = %(<img src="#{FAVICON_URI}" style="height:1.5em;vertical-align:middle;margin-right:6px;">)
ABBREV_LEN = 200
DEFAULT_GLOB = '~/.copilot/session-state/*/events.jsonl'
OVERVIEW_OUTPUT = File.expand_path('~/.copilot/session-state/sessions-overview.html')
MARKDOWN_AGENT_NAMES = ['Explore Agent', 'General Purpose Agent', 'Code Review Agent'].freeze

TOOL_ICONS = {
  'bash' => '🖥️',
  'view' => '👀',
  'edit' => '✏️',
  'create' => '🆕',
  'grep' => '🔍',
  'glob' => '🗂️',
  'task' => '🤖',
  'sql' => '🗃️',
  'ask_user' => '💬',
  'web_search' => '🌐',
  'web_fetch' => '🌐',
  'report_intent' => '🎯',
  'read_bash' => '🖥️👀',
  'write_bash' => '🖥️✏️',
  'stop_bash' => '🛑',
  'list_bash' => '📋',
  'read_agent' => '📡',
  'list_agents' => '📡'
}.freeze

SUBAGENT_ICONS = {
  'Explore Agent' => '🕵️‍♀️',
  'Code Review Agent' => '✅'
}.freeze

TOOL_COLORS = {
  'bash' => '#e8f4fd',
  'view' => '#f0fdf4',
  'edit' => '#fff7ed',
  'create' => '#fdf4ff',
  'grep' => '#fefce8',
  'glob' => '#fefce8',
  'task' => '#f0f9ff',
  'sql' => '#f5f3ff',
  'ask_user' => '#fff1f2',
  'web_search' => '#f0fdf4',
  'web_fetch' => '#f0fdf4',
  'default' => '#f8fafc'
}.freeze

TOOL_BORDER_COLORS = {
  'bash' => '#3b82f6',
  'view' => '#22c55e',
  'edit' => '#f97316',
  'create' => '#a855f7',
  'grep' => '#eab308',
  'glob' => '#eab308',
  'task' => '#0ea5e9',
  'sql' => '#8b5cf6',
  'ask_user' => '#f43f5e',
  'web_search' => '#10b981',
  'web_fetch' => '#10b981',
  'default' => '#94a3b8'
}.freeze

CSS = <<~'CSS'
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #f1f5f9;
    color: #1e293b;
    line-height: 1.6;
    font-size: 14px;
  }

  .container {
    margin: 0 auto;
    padding: 24px 16px 64px;
  }

  .overview-section {
    background: white;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }

  .page-title {
    font-size: 1.6rem;
    font-weight: 700;
    margin-bottom: 12px;
  }

  .overview-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    color: #64748b;
    margin-bottom: 20px;
    font-size: 13px;
  }
  .overview-meta strong { color: #1e293b; }

  .overview-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 16px;
    margin-bottom: 16px;
  }

  .overview-block {
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 14px 16px;
  }

  .overview-block-title {
    font-weight: 600;
    font-size: 13px;
    color: #475569;
    margin-bottom: 10px;
    text-transform: uppercase;
    letter-spacing: .4px;
  }

  .overview-block-full { grid-column: 1 / -1; }

  .kv-table { width: 100%; border-collapse: collapse; }
  .kv-table td { padding: 3px 0; vertical-align: top; }
  .kv-table td:first-child { color: #64748b; padding-right: 12px; white-space: nowrap; }
  .kv-table code { font-size: 12px; background: #e2e8f0; padding: 1px 4px; border-radius: 3px; word-break: break-all; }

  .resume-cmd { display: flex; align-items: center; gap: 6px; }
  .copy-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 2em;
    color: #94a3b8;
    padding: 0 2px;
    line-height: 1;
    border-radius: 3px;
    flex-shrink: 0;
  }
  .copy-btn:hover { color: #2563eb; background: #e2e8f0; }
  .copy-btn-ok { color: #16a34a !important; background: #dcfce7 !important; }

  .code-changes { display: flex; gap: 12px; margin-bottom: 10px; font-weight: 600; font-size: 13px; }
  .added  { color: #16a34a; }
  .removed { color: #dc2626; }
  .files  { color: #2563eb; }

  .file-list { list-style: none; }
  .file-list li { font-size: 12px; padding: 2px 0; }
  .file-list code { background: #e2e8f0; padding: 1px 4px; border-radius: 3px; word-break: break-all; }

  .user-msg-list, .intent-list { padding-left: 18px; }
  .user-msg-summary { font-size: 13px; padding: 3px 0; color: #334155; }
  .intent-item { font-size: 13px; padding: 2px 0; color: #334155; }

  .metrics-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .metrics-table th { text-align: right; padding: 6px 8px; border-bottom: 1px solid #e2e8f0; color: #64748b; font-weight: 600; }
  .metrics-table td { padding: 5px 8px; border-bottom: 1px solid #f1f5f9; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
  .metrics-premium { color: #7c3aed; font-weight: 600; }

  .tool-badges { display: flex; flex-wrap: wrap; gap: 8px; }
  .tool-badge {
    padding: 4px 10px;
    border-radius: 20px;
    border: 1px solid;
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .turns-section {
    background: white;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }

  .section-title {
    font-size: 1.2rem;
    font-weight: 700;
    margin-bottom: 20px;
    padding-bottom: 10px;
    border-bottom: 1px solid #e2e8f0;
  }

  .turn { margin-bottom: 28px; }

  .user-bubble {
    background: #cff6ff;
    border: 1px solid #bfdbfe;
    border-radius: 10px;
    padding: 14px 16px;
    margin-bottom: 12px;
  }

  .bubble-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }

  .bubble-role { font-weight: 700; font-size: 12px; text-transform: uppercase; letter-spacing: .5px; }
  .user-role    { color: #2563eb; }
  .assistant-role { color: #7c3aed; }

  .bubble-ts { font-size: 11px; color: #94a3b8; }

  .bubble-content {
    white-space: pre-wrap;
    color: #1e293b;
    font-size: 14px;
  }

  .assistant-turn {
    border-left: 0px solid #c4b5fd;
    padding-left: 2em;
    margin-left: 4px;
  }

  .turn-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 10px;
  }

  .turn-label { font-size: 12px; color: #94a3b8; }

  .tool-step {
    margin-bottom: 6px;
    border-radius: 8px;
    overflow: hidden;
    border: 1px solid #e2e8f0;
  }

  .tool-summary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    cursor: pointer;
    user-select: none;
    list-style: none;
    flex-wrap: wrap;
  }

  .tool-summary::-webkit-details-marker { display: none; }
  .tool-summary::marker { display: none; }

  details[open] > .tool-summary { border-bottom: 1px solid #e2e8f0; }

  .tool-summary:hover { filter: brightness(.97); }

  .tool-icon { font-size: 15px; }
  .tool-name { font-weight: 600; font-size: 13px; }
  .tool-intent { color: #64748b; font-size: 12px; flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tool-meta { margin-left: auto; font-size: 11px; color: #94a3b8; white-space: nowrap; }

  .badge-success { color: #16a34a; font-size: 13px; }
  .badge-fail    { color: #dc2626; font-size: 13px; }

  .tool-body {
    padding: 12px 14px;
    background: white;
  }

  .tool-section-label {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: .5px;
    color: #94a3b8;
    margin-bottom: 6px;
    margin-top: 12px;
  }
  .tool-section-label:first-child { margin-top: 0; }

  .arg-inline { font-size: 13px; }
  .arg-key { color: #7c3aed; font-weight: 600; }
  .arg-val { color: #15803d; }

  .arg-pretty-key {
    font-size: 11px;
    font-weight: 600;
    color: #7c3aed;
    margin: 6px 0 2px;
  }
  .arg-pretty-key:first-child { margin-top: 0; }

  .diff-block {
    background: #0f172a;
    color: #e2e8f0;
    border-radius: 6px;
    padding: 12px 14px;
    overflow-x: auto;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: 12px;
    line-height: 1.5;
    white-space: pre;
    max-height: 500px;
    overflow-y: auto;
    margin: 0;
  }
  .diff-add  { display: block; background: #14532d; color: #86efac; }
  .diff-del  { display: block; background: #450a0a; color: #fca5a5; }
  .diff-hunk { display: block; color: #93c5fd; }
  .diff-meta { display: block; color: #94a3b8; }

  .grep-block {
    background: #0f172a;
    color: #e2e8f0;
    border-radius: 6px;
    padding: 12px 14px;
    overflow-x: auto;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: 12px;
    line-height: 1.5;
    white-space: pre;
    max-height: 400px;
    overflow-y: auto;
    margin: 0;
  }
  .grep-file  { color: #7dd3fc; }
  .grep-sep   { color: #475569; }
  .grep-lnum  { color: #fbbf24; }
  .grep-count { color: #f472b6; font-weight: 600; }
  .grep-match { background: #854d0e; color: #fef08a; border-radius: 2px; font-style: normal; }

  .text-step { padding: 4px 0 8px; }
  .md-body { line-height: 1.7; }
  .md-body .md-p { margin: 0 0 10px; }

  .md-h1, .md-h2, .md-h3, .md-h4, .md-h5, .md-h6 {
    font-weight: 700;
    margin: 18px 0 8px;
    line-height: 1.3;
    color: #0f172a;
  }
  .md-h1 { font-size: 1.5rem; border-bottom: 2px solid #e2e8f0; padding-bottom: 6px; }
  .md-h2 { font-size: 1.25rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px; }
  .md-h3 { font-size: 1.1rem; }
  .md-h4 { font-size: 1rem; }
  .md-h5, .md-h6 { font-size: .9rem; color: #475569; }

  .md-ul, .md-ol {
    margin: 6px 0 10px 22px;
    padding: 0;
  }
  .md-li { margin: 3px 0; }
  .md-ul .md-ul, .md-ol .md-ol, .md-ul .md-ol, .md-ol .md-ul {
    margin-top: 3px;
    margin-bottom: 3px;
  }

  .md-blockquote {
    border-left: 4px solid #cbd5e1;
    background: #f8fafc;
    margin: 10px 0;
    padding: 8px 14px;
    border-radius: 0 6px 6px 0;
    color: #475569;
  }
  .md-blockquote p { margin: 0; }

  .md-hr {
    border: none;
    border-top: 2px solid #e2e8f0;
    margin: 16px 0;
  }

  code.md-code {
    background: #f1f5f9;
    color: #be185d;
    padding: 1px 5px;
    border-radius: 4px;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: .88em;
    border: 1px solid #e2e8f0;
  }

  .md-table-wrap { overflow-x: auto; margin: 10px 0; }
  .md-table {
    border-collapse: collapse;
    width: 100%;
    font-size: 13px;
  }
  .md-table th, .md-table td {
    border: 1px solid #e2e8f0;
    padding: 6px 12px;
    text-align: left;
  }
  .md-table th {
    background: #f1f5f9;
    font-weight: 600;
    color: #334155;
  }
  .md-table tr:nth-child(even) td { background: #f8fafc; }
  .md-table a { color: #2563eb; }

  del { color: #94a3b8; text-decoration: line-through; }
  .md-body a { color: #2563eb; text-decoration: underline; }
  .md-body a:hover { color: #1d4ed8; }
  .md-body .code-block { margin: 10px 0; }

  .json-block, .result-pre, .code-block, .arg-pretty-val, .sql-result {
    background: #0f172a;
    color: #e2e8f0;
    border-radius: 6px;
    padding: 12px 14px;
    overflow-x: auto;
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    font-size: 12px;
    line-height: 1.5;
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 400px;
    overflow-y: auto;
  }
  .sql-result .md-p:last-child { margin-bottom: 0; }
  .sql-result .md-h1, .sql-result .md-h2, .sql-result .md-h3, .sql-result .md-h4, .sql-result .md-h5, .sql-result .md-h6 { color: #e2e8f0; border-color: #334155; }
  .sql-result .md-blockquote { background: #111827; color: #cbd5e1; border-left-color: #475569; }
  .sql-result .md-table th, .sql-result .md-table td { border-color: #334155; color: #e2e8f0; }
  .sql-result .md-table th { background: #1e293b; color: #cbd5e1; }
  .sql-result .md-table tr:nth-child(even) td { background: #111827; }
  .sql-result .md-table a, .sql-result .md-body a { color: #93c5fd; }

  .jk    { color: #93c5fd; }
  .js    { color: #86efac; }
  .jn    { color: #fca5a5; }
  .jb    { color: #fdba74; }
  .jnull { color: #94a3b8; }
  .jp    { color: #cbd5e1; }
  .sql-kw  { color: #93c5fd; font-weight: 600; }
  .sql-str { color: #86efac; }

  .agent-result {
    padding: 4px 2px;
    border-left: 3px solid #e2e8f0;
    padding-left: 14px;
  }

  .raw-section {
    background: white;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }

  .raw-event {
    border-bottom: 1px solid #f1f5f9;
    padding: 3px 0;
  }
  .raw-event > summary {
    cursor: pointer;
    padding: 4px 6px;
    border-radius: 4px;
    list-style: none;
    display: flex;
    align-items: center;
    gap: 10px;
    font-size: 12px;
  }
  .raw-event > summary::-webkit-details-marker { display: none; }
  .raw-event > summary:hover { background: #f8fafc; }
  .raw-event.raw-highlight > summary { background: #fef9c3 !important; }
  .raw-ts   { color: #94a3b8; font-family: monospace; }
  .raw-type { font-weight: 600; color: #334155; }
  .raw-id   { color: #94a3b8; font-family: monospace; font-size: 11px; }
  .raw-event .json-block { margin: 8px 6px; }
  .raw-link {
    font-size: 11px;
    color: #94a3b8;
    text-decoration: none;
    margin-left: 6px;
    vertical-align: middle;
    opacity: 0;
    transition: opacity .15s;
  }
  .bubble-header:hover .raw-link,
  .tool-summary:hover .raw-link,
  .text-step:hover .raw-link { opacity: 1; }
  .raw-link:hover { color: #6366f1; }

  .back-link {
    display: inline-block;
    margin-bottom: 12px;
    font-size: 13px;
    color: #64748b;
    text-decoration: none;
  }
  .back-link:hover { color: #2563eb; text-decoration: underline; }

  .tab-nav {
    display: flex;
    gap: 4px;
    margin-bottom: 20px;
    background: white;
    padding: 6px;
    border-radius: 10px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }
  .tab-btn {
    flex: 1;
    padding: 8px 0;
    text-align: center;
    cursor: pointer;
    border-radius: 7px;
    border: none;
    background: none;
    font-size: 13px;
    font-weight: 500;
    color: #64748b;
    transition: all .15s;
  }
  .tab-btn:hover { background: #f1f5f9; }
  .tab-btn.active { background: #1e293b; color: white; }

  .tab-panel { display: none; }
  .tab-panel.active { display: block; }

  .story-section {
    background: white;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }

  .story-body {
    max-width: 720px;
    font-size: 15px;
    line-height: 1.8;
    color: #1e293b;
  }

  .story-p {
    margin: 0 0 1.2em;
  }
CSS

CSS_A11Y = <<~'CSS'
  .badge-success { color: #2563eb; }
  .badge-fail    { color: #ea580c; }
  .diff-add  { background: #1e3a5f; color: #93c5fd; }
  .diff-del  { background: #431407; color: #fed7aa; }
  .diff-add::before { content: "+"; }
  .diff-del::before { content: "−"; }
  .jn    { color: #fbbf24; }
  .js    { color: #93c5fd; }
  .grep-match { background: #312e81; color: #c7d2fe; }
CSS

JS = <<~'JS'
  function showTab(name, pushState) {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    document.querySelector('[data-tab="' + name + '"]').classList.add('active');
    document.getElementById('panel-' + name).classList.add('active');
    if (pushState !== false) location.hash = name;
  }

  function applyHash() {
    const name = location.hash.slice(1);
    if (name && document.querySelector('[data-tab="' + name + '"]')) showTab(name, false);
  }

  window.addEventListener('hashchange', applyHash);
  applyHash();

  function goToRaw(id) {
    showTab('raw', false);
    const el = document.getElementById(id);
    if (!el) return;
    el.open = true;
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('raw-highlight');
    setTimeout(() => el.classList.remove('raw-highlight'), 2000);
  }

  function copyCmd(btn, text) {
    navigator.clipboard.writeText(text).then(() => {
      const prev = btn.textContent;
      btn.textContent = '✓';
      btn.classList.add('copy-btn-ok');
      setTimeout(() => { btn.textContent = prev; btn.classList.remove('copy-btn-ok'); }, 1500);
    });
  }
JS

OVERVIEW_CSS = <<~'CSS'
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #f1f5f9;
    color: #1e293b;
    line-height: 1.6;
    font-size: 14px;
  }
  .container { margin: 0 auto; padding: 24px 16px 64px; }
  .overview-section {
    background: white;
    border-radius: 12px;
    padding: 28px;
    margin-bottom: 28px;
    box-shadow: 0 1px 4px rgba(0,0,0,.08);
  }
  .page-title { font-size: 1.6rem; font-weight: 700; margin-bottom: 8px; }
  .page-meta { color: #64748b; font-size: 13px; margin-bottom: 16px; }
  .toolbar { display: flex; gap: 10px; align-items: center; margin-bottom: 20px; }
  .search-bar {
    flex: 1;
    padding: 8px 12px;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    font-size: 14px;
    outline: none;
    background: #f8fafc;
    transition: border-color .15s;
  }
  .search-bar:focus { border-color: #6366f1; background: white; }
  .btn {
    padding: 6px 12px;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    background: #f8fafc;
    color: #475569;
    font-size: 12px;
    cursor: pointer;
    white-space: nowrap;
  }
  .btn:hover { background: #e2e8f0; }
  .sessions-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .sessions-table th {
    text-align: left;
    padding: 8px 12px;
    border-bottom: 2px solid #e2e8f0;
    color: #475569;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .4px;
    font-size: 11px;
    white-space: nowrap;
    cursor: pointer;
    user-select: none;
  }
  .sessions-table th:hover { color: #1e293b; }
  .sessions-table th.sort-active { color: #6366f1; }
  .sort-ind { opacity: .55; }
  .sessions-table td { padding: 9px 12px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
  .data-row:hover td { background: #f8fafc; }
  .ts { white-space: nowrap; color: #64748b; font-variant-numeric: tabular-nums; }
  .cwd { white-space: nowrap; color: #64748b; font-size: 12px; max-width: 160px; overflow: hidden; text-overflow: ellipsis; }
  .model { white-space: nowrap; color: #7c3aed; font-size: 12px; }
  .activity { white-space: nowrap; color: #64748b; font-variant-numeric: tabular-nums; text-align: right; }
  .story-indicator { white-space: nowrap; text-align: center; width: 1%; }
  .prompt { color: #334155; }
  .prompt a { color: inherit; text-decoration: none; }
  .prompt a:hover { color: #2563eb; text-decoration: underline; }
  .group-header td {
    background: #f1f5f9;
    padding: 7px 12px;
    border-bottom: 1px solid #e2e8f0;
    font-size: 12px;
    cursor: pointer;
  }
  .group-header:hover td { background: #e2e8f0; }
  .group-toggle { display: inline-block; width: 14px; font-size: 10px; color: #64748b; }
  .group-count { color: #94a3b8; font-weight: normal; margin-left: 6px; font-size: 11px; }
  .mu-section { margin-top: 0; }
  .mu-title { font-size: 1rem; font-weight: 700; margin-bottom: 12px; color: #1e293b; }
  .mu-table { border-collapse: collapse; font-size: 13px; }
  .mu-table th {
    text-align: left;
    padding: 6px 16px 6px 0;
    border-bottom: 2px solid #e2e8f0;
    color: #475569;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .4px;
    font-size: 11px;
    white-space: nowrap;
  }
  .mu-table td { padding: 6px 16px 6px 0; border-bottom: 1px solid #f1f5f9; white-space: nowrap; }
  .mu-table .num { text-align: right; padding-right: 0; font-variant-numeric: tabular-nums; }
  .mu-premium { color: #7c3aed; font-weight: 600; }
  .mu-total td { border-top: 2px solid #e2e8f0; border-bottom: none; font-weight: 600; }
CSS

OVERVIEW_JS = <<~'JS'
  const DATA = __DATA__;
  let sortCol = 0;
  let sortAsc = false;
  let query = '';
  const collapsed = new Set();

  function getGroupKey(item, col) {
    if (col === 0) return item.ts.slice(0, 10);
    if (col === 1) return item.cwd || '(none)';
    if (col === 2) return item.model || '(unknown)';
    if (col === 3) return String(item.activity_total);
    if (col === 4) return item.has_story ? 'yes' : 'no';
    const words = (item.prompt || '').trim().split(/\s+/);
    return words.slice(0, 6).join(' ') + (words.length > 6 ? '…' : '') || '(empty)';
  }

  function getSortVal(item, col) {
    if (col === 0) return item.ts_raw;
    if (col === 1) return (item.cwd || '').toLowerCase();
    if (col === 2) return (item.model || '').toLowerCase();
    if (col === 3) return item.activity_total;
    if (col === 4) return item.has_story ? 1 : 0;
    if (col === 5) return (item.prompt || '').toLowerCase();
    return '';
  }

  function escHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function toggleGroup(gk) {
    if (collapsed.has(gk)) collapsed.delete(gk); else collapsed.add(gk);
    render();
  }

  function render() {
    const q = query.toLowerCase();
    const filtered = DATA.filter(item =>
      !q ||
      item.ts.includes(q) ||
      (item.cwd    || '').toLowerCase().includes(q) ||
      (item.model  || '').toLowerCase().includes(q) ||
      (item.prompt || '').toLowerCase().includes(q)
    );

    filtered.sort((a, b) => {
      const av = getSortVal(a, sortCol), bv = getSortVal(b, sortCol);
      const cmp = av < bv ? -1 : av > bv ? 1 : 0;
      return sortAsc ? cmp : -cmp;
    });

    const useGroups = true;
    const groupCounts = {};
    if (useGroups) {
      filtered.forEach(item => {
        const gk = getGroupKey(item, sortCol);
        groupCounts[gk] = (groupCounts[gk] || 0) + 1;
      });
    }

    const frag = document.createDocumentFragment();
    let curGroup;

    filtered.forEach(item => {
      const gk = useGroups ? getGroupKey(item, sortCol) : null;

      if (gk !== null && gk !== curGroup) {
        curGroup = gk;
        const isCollapsed = collapsed.has(gk);
        const cnt = groupCounts[gk];
        const tr = document.createElement('tr');
        tr.className = 'group-header';
        tr.dataset.group = gk;
        tr.innerHTML =
          `<td colspan="6">` +
          `<span class="group-toggle">${isCollapsed ? '\u25b6' : '\u25bc'}</span> ` +
          `<strong>${escHtml(gk)}</strong>` +
          `<span class="group-count">${cnt} session${cnt === 1 ? '' : 's'}</span></td>`;
        tr.addEventListener('click', () => toggleGroup(gk));
        frag.appendChild(tr);
      }

      if (!useGroups || !collapsed.has(gk)) {
        const tr = document.createElement('tr');
        tr.className = 'data-row';
        if (gk !== null) tr.dataset.group = gk;
        const promptHtml = item.prompt ? escHtml(item.prompt) : '<em>\u2014</em>';
        tr.innerHTML =
          `<td class="ts">${escHtml(item.ts)}</td>` +
          `<td class="cwd" title="${escHtml(item.cwd)}">${escHtml(item.cwd_display)}</td>` +
          `<td class="model">${escHtml(item.model)}</td>` +
          `<td class="activity" title="user prompts + agent intents">${escHtml(item.activity)}</td>` +
          `<td class="story-indicator" title="${item.has_story ? 'Story available' : 'No story'}">${item.has_story ? '📖' : ''}</td>` +
          `<td class="prompt"><a href="file://${escHtml(item.link)}">${promptHtml}</a></td>`;
        frag.appendChild(tr);
      }
    });

    document.querySelector('#sessions-table tbody').replaceChildren(frag);

    document.querySelectorAll('#sessions-table th[data-col]').forEach(th => {
      const col = parseInt(th.dataset.col);
      th.classList.toggle('sort-active', col === sortCol);
      th.querySelector('.sort-ind').textContent =
        col !== sortCol ? ' \u2195' : sortAsc ? ' \u2191' : ' \u2193';
    });
  }

  document.querySelectorAll('#sessions-table th[data-col]').forEach(th => {
    th.addEventListener('click', () => {
      const col = parseInt(th.dataset.col);
      if (col === sortCol) { sortAsc = !sortAsc; }
      else { sortCol = col; sortAsc = col !== 0; }
      render();
    });
  });

  document.getElementById('search').addEventListener('input', e => {
    query = e.target.value;
    render();
  });

  document.getElementById('btn-expand').addEventListener('click', () => {
    collapsed.clear();
    render();
  });

  document.getElementById('btn-collapse').addEventListener('click', () => {
    const q = query.toLowerCase();
    DATA.filter(item =>
      !q ||
      item.ts.includes(q) ||
      (item.cwd    || '').toLowerCase().includes(q) ||
      (item.model  || '').toLowerCase().includes(q) ||
      (item.prompt || '').toLowerCase().includes(q)
    ).forEach(item => {
      const gk = getGroupKey(item, sortCol);
      if (gk !== null) collapsed.add(gk);
    });
    render();
  });

  render();
JS

def parse_ts(ts_str)
  return nil if ts_str.nil? || ts_str.empty?

  text = ts_str.sub(/Z\z/, '')
  text = "#{text}Z" unless text.match?(/(?:Z|[+-]\d{2}:?\d{2})\z/)
  Time.iso8601(text).utc
rescue ArgumentError
  nil
end

def fmt_ts(ts_str)
  dt = parse_ts(ts_str.to_s)
  dt ? dt.strftime('%H:%M:%S') : ts_str.to_s
end

def fmt_ts_long(ts_str)
  dt = parse_ts(ts_str.to_s)
  dt ? dt.strftime('%Y-%m-%d %H:%M') : ts_str.to_s
end

def fmt_duration(ms)
  return '?' if ms.nil?

  seconds = ms.to_f / 1000.0
  return format('%.1fs', seconds) if seconds < 60

  minutes, rem_seconds = seconds.divmod(60)
  return format('%dm %ds', minutes.to_i, rem_seconds.to_i) if minutes < 60

  hours, rem_minutes = minutes.divmod(60)
  format('%dh %dm %ds', hours.to_i, rem_minutes.to_i, rem_seconds.to_i)
end

def fmt_number(number)
  s = (number || 0).to_i.to_s
  s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def escape(text)
  text.nil? ? '' : CGI.escapeHTML(text.to_s)
end

def js_string(text)
  text.to_s.gsub('\\', '\\\\').gsub("'", "\\\\'").gsub("\n", '\\n').delete("\r")
end

def abbreviate(text, max_len = ABBREV_LEN)
  cleaned = text.to_s.strip.gsub("\n", ' ').delete("\r")
  cleaned.gsub!(/ {2,}/, ' ')
  cleaned.length <= max_len ? cleaned : "#{cleaned[0, max_len].rstrip}…"
end

def json_html(obj)
  text = JSON.pretty_generate(obj, ascii_only: false)
  result = +''
  i = 0
  while i < text.length
    ch = text[i]
    if ch == '"'
      j = i + 1
      while j < text.length
        if text[j] == '\\'
          j += 2
          next
        end
        if text[j] == '"'
          j += 1
          break
        end
        j += 1
      end
      token = text[i...j]
      klass = text[j..].to_s.lstrip.start_with?(':') ? 'jk' : 'js'
      result << %(<span class="#{klass}">#{escape(token)}</span>)
      i = j
    elsif ch.match?(/[0-9-]/)
      j = i + 1
      j += 1 while j < text.length && text[j].match?(/[0-9.eE+-]/)
      result << %(<span class="jn">#{escape(text[i...j])}</span>)
      i = j
    elsif text[i, 4] == 'true'
      result << '<span class="jb">true</span>'
      i += 4
    elsif text[i, 5] == 'false'
      result << '<span class="jb">false</span>'
      i += 5
    elsif text[i, 4] == 'null'
      result << '<span class="jnull">null</span>'
      i += 4
    elsif '{}[],:'.include?(ch)
      result << %(<span class="jp">#{escape(ch)}</span>)
      i += 1
    else
      result << escape(ch)
      i += 1
    end
  end
  result
end

def tool_icon(name)
  TOOL_ICONS.fetch(name, '🔧')
end

def subagent_icon(name)
  SUBAGENT_ICONS.fetch(name, '🤖')
end

def tool_bg(name)
  TOOL_COLORS.fetch(name, TOOL_COLORS['default'])
end

def tool_border(name)
  TOOL_BORDER_COLORS.fetch(name, TOOL_BORDER_COLORS['default'])
end

def build_overview(events)
  overview = {
    'session_id' => nil,
    'copilot_version' => nil,
    'start_time' => nil,
    'end_time' => nil,
    'duration_ms' => nil,
    'cwd' => nil,
    'branch' => nil,
    'head_commit' => nil,
    'shutdown_type' => nil,
    'total_premium_requests' => 0,
    'total_api_duration_ms' => nil,
    'files_modified' => [],
    'lines_added' => 0,
    'lines_removed' => 0,
    'model_metrics' => {},
    'event_counts' => {},
    'user_messages' => [],
    'tools_used' => {},
    'intents' => [],
    'subagents' => []
  }

  events.each do |event|
    type = event['type'].to_s
    data = event['data'] || {}
    overview['event_counts'][type] = overview['event_counts'].fetch(type, 0) + 1

    case type
    when 'session.start'
      overview['session_id'] = data['sessionId']
      overview['copilot_version'] = data['copilotVersion']
      overview['start_time'] = event['timestamp']
      context = data['context'] || {}
      overview['cwd'] = context['cwd']
      overview['branch'] = context['branch']
      overview['head_commit'] = context['headCommit']
    when 'user.message'
      overview['user_messages'] << data.fetch('content', '')
    when 'session.shutdown'
      overview['end_time'] = event['timestamp']
      overview['shutdown_type'] = data['shutdownType']
      overview['total_premium_requests'] = data.fetch('totalPremiumRequests', 0)
      overview['total_api_duration_ms'] = data['totalApiDurationMs']
      code = data['codeChanges'] || {}
      overview['files_modified'] = code.fetch('filesModified', [])
      overview['lines_added'] = code.fetch('linesAdded', 0)
      overview['lines_removed'] = code.fetch('linesRemoved', 0)
      overview['model_metrics'] = data.fetch('modelMetrics', {})
    when 'tool.execution_start'
      name = data['toolName'].to_s
      if !name.empty? && name != 'report_intent'
        overview['tools_used'][name] = overview['tools_used'].fetch(name, 0) + 1
      end
      if name == 'report_intent'
        intent = (data['arguments'] || {})['intent']
        overview['intents'] << intent if intent
      end
    when 'subagent.started'
      overview['subagents'] << {
        'name' => data['agentDisplayName'] || data['agentName'] || '',
        'ts' => event['timestamp']
      }
    end
  end

  if overview['start_time'] && overview['end_time']
    start_t = parse_ts(overview['start_time'])
    end_t = parse_ts(overview['end_time'])
    overview['duration_ms'] = ((end_t - start_t) * 1000).to_i if start_t && end_t
  end

  overview
end

def build_turns(events)
  exec_starts = {}
  exec_ends = {}
  subagent_starts = {}
  subagent_ends = {}

  events.each do |event|
    type = event['type'].to_s
    data = event['data'] || {}
    cid = data['toolCallId']
    next unless cid

    case type
    when 'tool.execution_start' then exec_starts[cid] = event
    when 'tool.execution_complete' then exec_ends[cid] = event
    when 'subagent.started' then subagent_starts[cid] = event
    when 'subagent.completed' then subagent_ends[cid] = event
    end
  end

  turns = []
  current_user = nil
  current_steps = []
  current_text_parts = []
  current_text_event_id = nil

  flush_text = lambda do
    unless current_text_parts.empty?
      text = current_text_parts.join("\n").strip
      current_steps << { 'kind' => 'text', 'content' => text, 'event_id' => current_text_event_id || '' } unless text.empty?
    end
    current_text_parts = []
    current_text_event_id = nil
  end

  flush_turn = lambda do
    flush_text.call
    turns << { 'user_message' => current_user, 'steps' => current_steps } if current_user || !current_steps.empty?
    current_user = nil
    current_steps = []
    current_text_parts = []
    current_text_event_id = nil
  end

  events.each do |event|
    type = event['type'].to_s
    data = event['data'] || {}

    case type
    when 'user.message'
      flush_turn.call
      current_user = {
        'content' => data.fetch('content', ''),
        'timestamp' => event['timestamp'],
        'interaction_id' => data['interactionId'],
        'event_id' => event.fetch('id', '')
      }
    when 'assistant.message'
      text = data.fetch('content', '').strip
      unless text.empty?
        current_text_event_id ||= event.fetch('id', '')
        current_text_parts << text
      end

      (data['toolRequests'] || []).each do |request|
        next if request['name'] == 'report_intent'

        flush_text.call
        cid = request['toolCallId']
        end_event = exec_ends.fetch(cid, {})
        end_data = end_event.fetch('data', {})
        start_event = exec_starts.fetch(cid, {})
        sub_start = subagent_starts[cid]
        sub_end = subagent_ends[cid]

        if sub_start
          current_steps << {
            'kind' => 'subagent',
            'name' => sub_start.fetch('data', {}).fetch('agentDisplayName', request['name']),
            'arguments' => request.fetch('arguments', {}),
            'ts_start' => sub_start['timestamp'],
            'ts_end' => sub_end && sub_end['timestamp'],
            'result' => end_data['result'],
            'success' => end_data.fetch('success', true),
            'event_id' => sub_start.fetch('id', '')
          }
        else
          event_id = start_event.fetch('id', '')
          event_id = end_event.fetch('id', '') if event_id.to_s.empty?
          current_steps << {
            'kind' => 'tool',
            'name' => request.fetch('name', ''),
            'arguments' => request.fetch('arguments', {}),
            'intent_summary' => request['intentionSummary'],
            'ts_start' => start_event['timestamp'],
            'ts_end' => end_event['timestamp'],
            'result' => end_data['result'],
            'success' => end_data.fetch('success', true),
            'event_id' => event_id
          }
        end
      end
    end
  end

  flush_turn.call
  turns
end

def highlight_grep_match(text, pattern)
  return escape(text) if pattern.to_s.empty?

  parts = text.split(Regexp.new("(#{pattern})", Regexp::IGNORECASE))
  parts.each_with_index.map do |part, idx|
    idx.odd? ? %(<mark class="grep-match">#{escape(part)}</mark>) : escape(part)
  end.join
rescue RegexpError
  escape(text)
end

def render_grep_result(content, args)
  stripped = content.to_s.strip
  return %(<pre class="result-pre">#{escape(content)}</pre>) if stripped.empty? || stripped == 'No matches found.'

  mode = args.is_a?(Hash) ? args.fetch('output_mode', 'files_with_matches') : 'files_with_matches'
  has_linenum = args.is_a?(Hash) ? !!args['-n'] : false
  pattern = args.is_a?(Hash) ? args.fetch('pattern', '') : ''

  rows = content.to_s.lines(chomp: true).map do |line|
    if mode == 'files_with_matches'
      %(<span class="grep-file">#{escape(line)}</span>)
    elsif mode == 'count'
      idx = line.rindex(':')
      if idx && idx.positive?
        %(<span class="grep-file">#{escape(line[0...idx])}</span><span class="grep-sep">:</span><span class="grep-count">#{escape(line[(idx + 1)..])}</span>)
      else
        escape(line)
      end
    elsif has_linenum
      parts = line.split(':', 3)
      if parts.length == 3
        %(<span class="grep-file">#{escape(parts[0])}</span><span class="grep-sep">:</span><span class="grep-lnum">#{escape(parts[1])}</span><span class="grep-sep">:</span>#{highlight_grep_match(parts[2], pattern)})
      else
        escape(line)
      end
    else
      idx = line.index(':')
      if idx && idx.positive?
        %(<span class="grep-file">#{escape(line[0...idx])}</span><span class="grep-sep">:</span>#{highlight_grep_match(line[(idx + 1)..], pattern)})
      else
        escape(line)
      end
    end
  end

  %(<pre class="grep-block">#{rows.join("\n")}\n</pre>)
end

def looks_like_unified_diff(text)
  lines = text.to_s.lines.map(&:rstrip).reject(&:empty?).first(8)
  return false if lines.empty?

  lines.any? { |line| line.start_with?('diff --git ') } ||
    (lines.any? { |line| line.start_with?('--- ') } && lines.any? { |line| line.start_with?('+++ ') }) ||
    lines.any? { |line| line.start_with?('@@') }
end

def render_unified_diff_text(text)
  rows = text.to_s.lines.map do |line|
    if line.start_with?('diff --git ', 'index ', '--- ', '+++ ')
      %(<span class="diff-meta">#{escape(line)}</span>)
    elsif line.start_with?('@@')
      %(<span class="diff-hunk">#{escape(line)}</span>)
    elsif line.start_with?('+')
      %(<span class="diff-add">#{escape(line)}</span>)
    elsif line.start_with?('-')
      %(<span class="diff-del">#{escape(line)}</span>)
    else
      escape(line)
    end
  end
  %(<pre class="diff-block">#{rows.join}</pre>)
end

def render_result_text(content, tool_name = '', args = nil)
  return render_grep_result(content, args) if tool_name == 'grep'
  return %(<div class="sql-result md-body">#{markdown_to_html(content.to_s)}</div>) if tool_name == 'sql'
  return %(<div class="agent-result md-body">#{markdown_to_html(content.to_s)}</div>) if MARKDOWN_AGENT_NAMES.include?(tool_name)
  return render_unified_diff_text(content) if tool_name == 'bash' && looks_like_unified_diff(content.to_s)

  clipped = content.to_s[0, 4000]
  suffix = content.to_s.length > 4000 ? '...' : ''
  %(<pre class="result-pre">#{escape(clipped)}#{suffix}</pre>)
end

def render_tool_result(result, tool_name = '', args = nil)
  return '<em>No result</em>' if result.nil?

  if result.is_a?(Hash)
    text = result['content'] || result['detailedContent']
    return render_result_text(text, tool_name, args) if text

    return %(<div class="json-block">#{json_html(result)}</div>)
  end

  %(<pre class="result-pre">#{escape(result.to_s[0, 4000])}</pre>)
end

def lcs_rows(old_lines, new_lines)
  n = old_lines.length
  m = new_lines.length
  dp = Array.new(n + 1) { Array.new(m + 1, 0) }

  (n - 1).downto(0) do |i|
    (m - 1).downto(0) do |j|
      dp[i][j] = if old_lines[i] == new_lines[j]
                   dp[i + 1][j + 1] + 1
                 else
                   [dp[i + 1][j], dp[i][j + 1]].max
                 end
    end
  end

  rows = []
  i = 0
  j = 0
  while i < n && j < m
    if old_lines[i] == new_lines[j]
      rows << [' ', old_lines[i]]
      i += 1
      j += 1
    elsif dp[i + 1][j] >= dp[i][j + 1]
      rows << ['-', old_lines[i]]
      i += 1
    else
      rows << ['+', new_lines[j]]
      j += 1
    end
  end
  while i < n
    rows << ['-', old_lines[i]]
    i += 1
  end
  while j < m
    rows << ['+', new_lines[j]]
    j += 1
  end
  rows
end

def render_edit_diff(old_text, new_text)
  return '<pre class="arg-pretty-val" style="color:#94a3b8">  (no changes)</pre>' if old_text.to_s == new_text.to_s

  rows = lcs_rows(old_text.to_s.lines, new_text.to_s.lines).map do |prefix, line|
    if prefix == '+'
      %(<span class="diff-add">#{escape("#{prefix}#{line}")}</span>)
    elsif prefix == '-'
      %(<span class="diff-del">#{escape("#{prefix}#{line}")}</span>)
    else
      escape("#{prefix}#{line}")
    end
  end
  %(<pre class="diff-block">#{rows.join}</pre>)
end

def render_apply_patch_diff(patch)
  rows = patch.to_s.lines.map do |line|
    if line.start_with?('*** Begin Patch', '*** End Patch', '*** Update File:', '*** Add File:', '*** Delete File:', '*** Move to:', '*** End of File')
      %(<span class="diff-meta">#{escape(line)}</span>)
    elsif line.start_with?('@@')
      %(<span class="diff-hunk">#{escape(line)}</span>)
    elsif line.start_with?('+')
      %(<span class="diff-add">#{escape(line)}</span>)
    elsif line.start_with?('-')
      %(<span class="diff-del">#{escape(line)}</span>)
    else
      escape(line)
    end
  end
  %(<pre class="diff-block">#{rows.join}</pre>)
end

def render_sql_query(query)
  token_re = /'(?:''|[^'])*'|"(?:\"\"|[^"])*"|\b[A-Z][A-Z0-9_]*\b/
  out = +''
  pos = 0
  query.to_s.to_enum(:scan, token_re).map { Regexp.last_match }.each do |match|
    out << escape(query[pos...match.begin(0)])
    token = match[0]
    klass = token.start_with?("'", '"') ? 'sql-str' : 'sql-kw'
    out << %(<span class="#{klass}">#{escape(token)}</span>)
    pos = match.end(0)
  end
  out << escape(query[pos..])
  %(<div class="code-block sql-block">#{out}</div>)
end

def has_multiline_str?(args)
  args.values.any? { |value| value.is_a?(String) && value.include?("\n") }
end

def render_args_pretty(args)
  args.map do |key, value|
    key_html = %(<div class="arg-pretty-key">#{escape(key)}</div>)
    if value.is_a?(String)
      %(#{key_html}<pre class="arg-pretty-val">#{escape(value)}</pre>)
    else
      %(#{key_html}<div class="json-block">#{json_html(value)}</div>)
    end
  end.join("\n")
end

def render_args(args, tool_name = '')
  return '' if args.nil? || (args.respond_to?(:empty?) && args.empty?)

  if tool_name == 'bash' && args.is_a?(Hash) && args.key?('command') && args.key?('description')
    return %(<div class="code-block">#{escape(args['command'])}</div>)
  end
  if tool_name == 'sql' && args.is_a?(Hash) && args.length == 2 && args.key?('description') && args.key?('query')
    return render_sql_query(args['query'])
  end
  if tool_name == 'edit' && args.is_a?(Hash) && args.key?('old_str') && args.key?('new_str')
    return render_edit_diff(args['old_str'], args['new_str'])
  end
  if tool_name == 'apply_patch' && args.is_a?(String)
    return render_apply_patch_diff(args)
  end
  if args.is_a?(String)
    return args.include?("\n") ? %(<pre class="arg-pretty-val">#{escape(args)}</pre>) : %(<div class="json-block">#{json_html(args)}</div>)
  end
  return %(<div class="json-block">#{json_html(args)}</div>) unless args.is_a?(Hash)

  if args.length == 1
    key, value = args.first
    if value.is_a?(String) && value.length < 100 && !value.include?("\n")
      return %(<span class="arg-inline"><span class="arg-key">#{escape(key)}</span>: <span class="arg-val">#{escape(value)}</span></span>)
    end
  end
  return render_args_pretty(args) if has_multiline_str?(args)

  %(<div class="json-block">#{json_html(args)}</div>)
end

def md_inline(text)
  placeholder_map = {}
  counter = 0
  protect = lambda do |replacement|
    key = "\0P#{counter}\0"
    counter += 1
    placeholder_map[key] = replacement
    key
  end

  text = text.to_s.gsub(/(`+)(.+?)\1/m) { protect.call(%(<code class="md-code">#{escape(Regexp.last_match(2))}</code>)) }
  text = text.gsub(/\[([^\]\n]+)\]\(([^)\n]+)\)/) do
    protect.call(%(<a href="#{escape(Regexp.last_match(2))}" target="_blank" rel="noopener">#{escape(Regexp.last_match(1))}</a>))
  end

  text = escape(text)
  text.gsub!(/\*\*\*(.+?)\*\*\*/m, '<strong><em>\1</em></strong>')
  text.gsub!(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
  text.gsub!(/__(.+?)__/m, '<strong>\1</strong>')
  text.gsub!(/\*([^*\s][^*\n]*?[^*\s]|\S)\*/, '<em>\1</em>')
  text.gsub!(/(?<!\w)_([^_\s][^_\n]*?[^_\s]|\S)_(?!\w)/, '<em>\1</em>')
  text.gsub!(/~~(.+?)~~/m, '<del>\1</del>')
  placeholder_map.each { |key, value| text.gsub!(key, value) }
  text
end

def md_table(lines)
  split_row = lambda do |line|
    line.strip.sub(/\A\|/, '').sub(/\|\z/, '').split('|').map(&:strip)
  end
  rows = lines.map { |line| split_row.call(line) }
  return "<p>#{md_inline(lines.join(' '))}</p>" if rows.length < 2

  sep_idx = nil
  rows[1..].to_a.each_with_index do |row, idx|
    if row.reject(&:empty?).all? { |cell| cell.strip.match?(/\A:?-+:?\z/) }
      sep_idx = idx + 1
      break
    end
  end

  aligns = []
  if sep_idx
    rows[sep_idx].each do |cell|
      trimmed = cell.strip
      aligns << if trimmed.start_with?(':') && trimmed.end_with?(':')
                  'style="text-align:center"'
                elsif trimmed.end_with?(':')
                  'style="text-align:right"'
                else
                  ''
                end
    end
  end

  cell_attr = lambda do |idx|
    idx < aligns.length && !aligns[idx].empty? ? " #{aligns[idx]}" : ''
  end

  header_row = rows[0]
  data_rows = rows.each_with_index.reject { |_, idx| idx.zero? || idx == sep_idx }.map(&:first)

  thead = '<tr>' + header_row.each_with_index.map { |cell, idx| %(<th#{cell_attr.call(idx)}>#{md_inline(cell)}</th>) }.join + '</tr>'
  tbody_rows = data_rows.map do |row|
    cells = row.each_with_index.map { |cell, idx| %(<td#{cell_attr.call(idx)}>#{md_inline(cell)}</td>) }.join
    "<tr>#{cells}</tr>"
  end

  %(<div class="md-table-wrap"><table class="md-table"><thead>#{thead}</thead><tbody>#{tbody_rows.join}</tbody></table></div>)
end

def block_starter?(line)
  line.start_with?('```', '>') ||
    line.match?(/^\#{1,6}\s/) ||
    line.match?(/^[-*_]{3,}\s*$/) ||
    line.match?(/^[-*+]\s/) ||
    line.match?(/^\d+\.\s/) ||
    line.strip.empty?
end

def md_list_items(lines, ordered:)
  tag = ordered ? 'ol' : 'ul'
  css = ordered ? 'md-ol' : 'md-ul'
  item_re = /^(\d+\.\s+|[-*+]\s+)/
  items_html = []
  current = []
  sub = []

  flush_item = lambda do
    return if current.empty?

    body = md_inline(current.join(' '))
    unless sub.empty?
      body += md_list_items(sub, ordered: sub.first.match?(/^\d+\.\s/))
    end
    items_html << %(<li class='md-li'>#{body}</li>)
    current.clear
    sub.clear
  end

  lines.each do |line|
    if (match = item_re.match(line))
      flush_item.call
      current << line[match.end(0)..].to_s.rstrip
    elsif line.start_with?('  ') || line.start_with?("\t")
      sub << (line.start_with?('  ') ? line[2..] : line[1..]) if current.any?
    elsif current.any?
      current << line.strip
    end
  end
  flush_item.call
  %(<#{tag} class="#{css}">#{items_html.join}</#{tag}>)
end

def markdown_to_html(text)
  lines = text.to_s.split("\n", -1)
  out = []
  i = 0
  while i < lines.length
    line = lines[i]

    if line.match?(/^```/)
      lang = line[3..].to_s.strip
      lang_class = lang.empty? ? 'lang-text' : "lang-#{escape(lang)}"
      i += 1
      code_lines = []
      while i < lines.length && !lines[i].match?(/^```\s*$/)
        code_lines << lines[i]
        i += 1
      end
      i += 1
      out << %(<pre class="code-block #{lang_class}">#{escape(code_lines.join("\n"))}</pre>)
      next
    end

    if (match = /^(#+)\s+(.*)/.match(line))
      level = match[1].length
      out << %(<h#{level} class="md-h#{level}">#{md_inline(match[2])}</h#{level}>)
      i += 1
      next
    end

    if line.match?(/^([-*_])\1{2,}\s*$/)
      out << '<hr class="md-hr">'
      i += 1
      next
    end

    if line.start_with?('>')
      blockquote = []
      while i < lines.length && lines[i].start_with?('>')
        blockquote << lines[i][1..].to_s.lstrip
        i += 1
      end
      out << %(<blockquote class="md-blockquote">#{markdown_to_html(blockquote.join("\n"))}</blockquote>)
      next
    end

    if line.match?(/^[-*+]\s/)
      list = []
      while i < lines.length && (lines[i].match?(/^[-*+]\s/) || (!list.empty? && (lines[i].start_with?('  ') || lines[i].start_with?("\t"))))
        list << lines[i]
        i += 1
      end
      out << md_list_items(list, ordered: false)
      next
    end

    if line.match?(/^\d+\.\s/)
      list = []
      while i < lines.length && (lines[i].match?(/^\d+\.\s/) || (!list.empty? && (lines[i].start_with?('  ') || lines[i].start_with?("\t"))))
        list << lines[i]
        i += 1
      end
      out << md_list_items(list, ordered: true)
      next
    end

    if line.include?('|') && i + 1 < lines.length && lines[i + 1].match?(/^\|?[\s:|-]+\|?\s*$/)
      table = []
      while i < lines.length && lines[i].include?('|')
        table << lines[i]
        i += 1
      end
      out << md_table(table)
      next
    end

    if line.strip.empty?
      i += 1
      next
    end

    paragraph = []
    while i < lines.length && !lines[i].strip.empty? && !block_starter?(lines[i])
      paragraph << lines[i]
      i += 1
    end
    if paragraph.any?
      out << %(<p class="md-p">#{md_inline(paragraph.join(' '))}</p>)
    else
      i += 1
    end
  end
  out.join("\n")
end

def render_overview(overview)
  dt_start = parse_ts(overview['start_time'])
  date_str = dt_start ? dt_start.strftime('%A, %B %-d %Y at %H:%M UTC') : 'unknown'

  metrics_html = ''
  unless overview['model_metrics'].empty?
    rows = overview['model_metrics'].map do |model, metrics|
      req_count = metrics.fetch('requests', {}).fetch('count', 0)
      premium = metrics.fetch('requests', {}).fetch('cost', 0)
      input_tok = metrics.fetch('usage', {}).fetch('inputTokens', 0)
      output_tok = metrics.fetch('usage', {}).fetch('outputTokens', 0)
      <<~HTML
        <tr>
          <td>#{escape(model)}</td>
          <td class="num">#{fmt_number(req_count)}</td>
          <td class="num metrics-premium">#{fmt_number(premium)}</td>
          <td class="num">#{fmt_number(input_tok)}</td>
          <td class="num">#{fmt_number(output_tok)}</td>
        </tr>
      HTML
    end.join
    metrics_html = <<~HTML
      <table class="metrics-table">
        <thead><tr><th style="text-align: left">Model</th><th>Requests</th><th>Premium</th><th>Input tokens</th><th>Output tokens</th></tr></thead>
        <tbody>#{rows}</tbody>
      </table>
    HTML
  end

  files_html = ''
  unless overview['files_modified'].empty?
    items = overview['files_modified'].map { |file| "<li><code>#{escape(file)}</code></li>" }.join
    files_html = <<~HTML
      <div class="overview-block">
        <div class="overview-block-title">📝 Code changes</div>
        <div class="code-changes">
          <span class="added">+#{fmt_number(overview['lines_added'])} lines</span>
          <span class="removed">−#{fmt_number(overview['lines_removed'])} lines</span>
          <span class="files">#{overview['files_modified'].length} file(s)</span>
        </div>
        <ul class="file-list">#{items}</ul>
      </div>
    HTML
  end

  tools_html = overview['tools_used'].sort_by { |name, count| [-count, name] }.map do |name, count|
    %(<span class="tool-badge" style="border-color:#{tool_border(name)};background:#{tool_bg(name)}">#{tool_icon(name)} #{escape(name)} <strong>#{count}</strong></span>)
  end.join

  intents_html = if overview['intents'].empty?
                   ''
                 else
                   items = overview['intents'].map { |intent| %(<li class="intent-item">#{escape(intent)}</li>) }.join
                   %(<ol class="intent-list">#{items}</ol>)
                 end

  msgs_html = if overview['user_messages'].empty?
                ''
              else
                items = overview['user_messages'].map do |message|
                  suffix = message.length > 200 ? '…' : ''
                  %(<li class="user-msg-summary">#{escape(message[0, 200])}#{suffix}</li>)
                end.join
                %(<ol class="user-msg-list">#{items}</ol>)
              end

  event_count_items = overview['event_counts'].sort.map do |key, value|
    %(<tr><td>#{escape(key)}</td><td class="num">#{value}</td></tr>)
  end.join

  resume_command = 'cd ' + escape(overview['cwd'] || '') + '; copilot --resume ' + escape(overview['session_id'])
  story_command = 'session_view --story ' + escape(overview['session_id'])

  <<~HTML
    <section class="overview-section">
      <h1 class="page-title">#{COPILOT_IMG} Copilot Session</h1>
      <div class="overview-meta">
        <span>📅 #{date_str}</span>
        <span>⏱ Duration: <strong>#{fmt_duration(overview['duration_ms'])}</strong></span>
        #{overview['shutdown_type'] ? "<span>🔄 Shutdown: <strong>#{escape(overview['shutdown_type'])}</strong></span>" : ''}
        #{overview['copilot_version'] ? "<span>🔖 Version: <strong>#{escape(overview['copilot_version'])}</strong></span>" : ''}
      </div>

      <div class="overview-grid">
        <div class="overview-block overview-block-full">
          <div class="overview-block-title">📍 Context</div>
          <table class="kv-table">
            <tr><td>Working directory</td><td><code>#{escape(overview['cwd'] || '—')}</code></td></tr>
            <tr><td>Branch</td><td><code>#{escape(overview['branch'] || '—')}</code></td></tr>
            <tr><td>Commit</td><td><code>#{escape((overview['head_commit'] || '—')[0, 12])}</code></td></tr>
            <tr><td>Session ID</td><td><code>#{escape(overview['session_id'] || '—')}</code></td></tr>
            <tr>
              <td>Resume</td>
              <td>
                <span class="resume-cmd">
                  <code>
                    #{resume_command}
                  </code>
                  <button class="copy-btn" onclick="copyCmd(this, '#{js_string(resume_command)}')" title="Copy">⎘</button>
                </span>
              </td>
            </tr>
            <tr>
              <td>Generate story</td>
              <td>
                <span class="resume-cmd">
                  <code>
                    #{story_command}
                  </code>
                  <button class="copy-btn" onclick="copyCmd(this, '#{js_string(story_command)}')" title="Copy">⎘</button>
                </span>
              </td>
            </tr>
          </table>
        </div>

        #{msgs_html.empty? ? '' : "<div class=\"overview-block overview-block-full\"><div class=\"overview-block-title\">💬 User messages</div>#{msgs_html}</div>"}

        <div class="overview-block">
          <div class="overview-block-title">📊 Event summary</div>
          <table class="kv-table">
            #{event_count_items}
          </table>
        </div>

        #{intents_html.empty? ? '' : "<div class=\"overview-block\"><div class=\"overview-block-title\">🎯 Agent intents</div>#{intents_html}</div>"}

        #{files_html}

        #{metrics_html.empty? ? '' : "<div class=\"overview-block\"><div class=\"overview-block-title\">🧮 Model usage</div>#{metrics_html}</div>"}

        #{tools_html.empty? ? '' : "<div class=\"overview-block\"><div class=\"overview-block-title\">🛠 Tools used</div><div class=\"tool-badges\">#{tools_html}</div></div>"}
      </div>
    </section>
  HTML
end

def render_steps(steps, turn_idx)
  steps.each_with_index.map do |step, idx|
    step_id = "step-#{turn_idx}-#{idx}"
    event_id = step['event_id'].to_s
    raw_link = event_id.empty? ? '' : %(<a class="raw-link" href="#" onclick="goToRaw('ev-#{escape(event_id)}');return false;" title="View raw event">⌗</a>)

    case step['kind']
    when 'text'
      %(<div class="text-step md-body">#{markdown_to_html(step['content'])}#{raw_link}</div>)
    when 'subagent'
      name = step.fetch('name', 'Sub-agent')
      ts_start = fmt_ts(step['ts_start'])
      ts_end = fmt_ts(step['ts_end'])
      duration = ''
      if step['ts_start'] && step['ts_end']
        start_t = parse_ts(step['ts_start'])
        end_t = parse_ts(step['ts_end'])
        duration = fmt_duration(((end_t - start_t) * 1000).to_i) if start_t && end_t
      end
      args = step.fetch('arguments', {})
      result = step['result']
      <<~HTML
        <details class="tool-step subagent-step" id="#{step_id}">
          <summary class="tool-summary" style="background:#f0f9ff;border-left:3px solid #0ea5e9">
            <span class="tool-icon">#{subagent_icon(name)}</span>
            <span class="tool-name">#{escape(name)}</span>
            <span class="tool-meta">#{ts_start} → #{ts_end} #{duration.empty? ? '' : "(#{duration})"}</span>
            #{raw_link}
          </summary>
          <div class="tool-body">
            <div class="tool-section-label">Arguments</div>
            #{render_args(args, name)}
            #{result.nil? ? '' : "<div class=\"tool-section-label\">Result</div>#{render_tool_result(result, name, args)}"}
          </div>
        </details>
      HTML
    when 'tool'
      name = step.fetch('name', '')
      summary = step['intent_summary'].to_s
      args = step.fetch('arguments', {})
      result = step['result']
      status_badge = step.fetch('success', true) ? '<span class="badge-success">✓</span>' : '<span class="badge-fail">✗</span>'
      summary_html = summary.empty? ? '' : %(<span class="tool-intent">#{escape(summary)}</span>)
      <<~HTML
        <details class="tool-step" id="#{step_id}">
          <summary class="tool-summary" style="background:#{tool_bg(name)};border-left:3px solid #{tool_border(name)}">
            <span class="tool-icon">#{tool_icon(name)}</span>
            <span class="tool-name">#{escape(name)}</span>
            #{summary_html}
            #{status_badge}
            <span class="tool-meta">#{fmt_ts(step['ts_start'])} → #{fmt_ts(step['ts_end'])}</span>
            #{raw_link}
          </summary>
          <div class="tool-body">
            <div class="tool-section-label">Arguments</div>
            #{render_args(args, name)}
            #{result.nil? ? '' : "<div class=\"tool-section-label\">Result</div>#{render_tool_result(result, name, args)}"}
          </div>
        </details>
      HTML
    else
      ''
    end
  end.join("\n")
end

def render_turns(turns)
  turns.each_with_index.map do |turn, idx|
    html = +%(<div class="turn" id="turn-#{idx}">)
    user_message = turn['user_message']
    if user_message
      event_id = user_message['event_id'].to_s
      raw_link = event_id.empty? ? '' : %(<a class="raw-link" href="#" onclick="goToRaw('ev-#{escape(event_id)}');return false;" title="View raw event">⌗</a>)
      html << <<~HTML
        <div class="user-bubble">
          <div class="bubble-header">
            <span class="bubble-role user-role">👤 User</span>
            <span class="bubble-ts">#{fmt_ts(user_message['timestamp'])}</span>
            #{raw_link}
          </div>
          <div class="bubble-content md-body">#{markdown_to_html(user_message['content'])}</div>
        </div>
      HTML
    end
    steps = turn.fetch('steps', [])
    unless steps.empty?
      html << <<~HTML
        <div class="assistant-turn">
          <div class="turn-header">
            <span class="bubble-role assistant-role">#{COPILOT_IMG} Copilot</span>
            <span class="turn-label">Turn #{idx + 1} — #{steps.length} step(s)</span>
          </div>
          #{render_steps(steps, idx)}
        </div>
      HTML
    end
    html << '</div>'
    html
  end.join("\n")
end

def render_raw_events(events)
  events.map do |event|
    event_id = event.fetch('id', '')
    short_id = event_id[0, 8]
    <<~HTML
      <details class="raw-event" id="ev-#{escape(event_id)}">
        <summary><span class="raw-ts">#{fmt_ts(event.fetch('timestamp', ''))}</span> <span class="raw-type">#{escape(event.fetch('type', ''))}</span> <span class="raw-id">#{short_id}…</span></summary>
        <div class="json-block">#{json_html(event)}</div>
      </details>
    HTML
  end.join("\n")
end

def render_html(overview, turns, events, source_path, a11y: false, story_text: nil)
  story_tab_btn = ''
  story_tab_panel = ''
  if story_text
    paragraphs = story_text.split("\n\n").filter_map do |paragraph|
      trimmed = paragraph.strip
      trimmed.empty? ? nil : %(<p class="story-p">#{escape(trimmed)}</p>)
    end.join("\n")
    story_tab_btn = '<button class="tab-btn" data-tab="story" onclick="showTab(\'story\')">📖 Story</button>'
    story_tab_panel = %(<div id="panel-story" class="tab-panel"><section class="story-section"><h2 class="section-title">📖 Story</h2><div class="story-body">#{paragraphs}</div></section></div>)
  end

  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Copilot Session — #{escape(File.basename(source_path))}</title>
      <link rel="icon" type="image/svg+xml" href="#{FAVICON_URI}">
      <style>#{CSS}#{a11y ? CSS_A11Y : ''}</style>
    </head>
    <body>
    <div class="container">

      <a href="file://#{escape(OVERVIEW_OUTPUT)}" class="back-link">← All sessions</a>

      <nav class="tab-nav">
        <button class="tab-btn active" data-tab="overview" onclick="showTab('overview')">📊 Overview</button>
        <button class="tab-btn" data-tab="turns" onclick="showTab('turns')">💬 Conversation</button>
        <button class="tab-btn" data-tab="raw" onclick="showTab('raw')">📜 Raw Events</button>
        #{story_tab_btn}
      </nav>

      <div id="panel-overview" class="tab-panel active">
        #{render_overview(overview)}
      </div>

      <div id="panel-turns" class="tab-panel">
        <section class="turns-section">
          <h2 class="section-title">💬 Conversation</h2>
          #{render_turns(turns)}
        </section>
      </div>

      <div id="panel-raw" class="tab-panel">
        <section class="raw-section">
          <h2 class="section-title">📜 Raw Events (#{events.length} total)</h2>
          #{render_raw_events(events)}
        </section>
      </div>

      #{story_tab_panel}

    </div>
    <script>#{JS}</script>
    </body>
    </html>
  HTML
end

def story_path(jsonl_path)
  File.join(File.dirname(jsonl_path), 'story.txt')
end

def parsed_json_path(jsonl_path)
  File.join(File.dirname(jsonl_path), 'events.txt')
end

def parse_json_events(jsonl_path)
  events = File.readlines(jsonl_path, chomp: true).map { |line| JSON.parse(line) }

  user_name = begin
    Etc.getlogin
  rescue StandardError
    ENV['USER'] || 'unknown'
  end

  File.open(parsed_json_path(jsonl_path), 'w:UTF-8') do |file|
    file.write("Session with user '#{user_name}' and Copilot\n\n")
    events.each_with_index do |event, idx|
      event_type = event.fetch('type', '')
      data = event.fetch('data', {})
      case event_type
      when 'session.start'
        context = data.fetch('context', {})
        file.write("Event #{idx}: SESSION START - Current Working Directory: #{context.fetch('cwd', '')}, Repository: #{context.fetch('repository', '')}\n")
      when 'user.message'
        file.write("Event #{idx}: USER MESSAGE: #{data.fetch('content', '')}\n")
      when 'assistant.message'
        tools = (data.fetch('toolRequests', []) || []).map { |request| request['name'] }
        content = data.fetch('content', '')
        file.write("Event #{idx}: ASSISTANT MESSAGE - Tools: #{tools}, Reasoning: '#{data.fetch('reasoningText', {})}', Content: #{content[0, 300]}\n")
      when 'assistant.turn_end', 'assistant.turn_start'
        next
      when 'tool.execution_complete'
        result = data.fetch('result', {}).fetch('detailedContent', '')[0, 200]
        file.write("Event #{idx}: TOOL COMPLETE: #{result}\n")
      end
    end
  end
end

def read_story(jsonl_path)
  path = story_path(jsonl_path)
  File.exist?(path) ? File.read(path, encoding: 'UTF-8') : nil
end

def generate_story(jsonl_path, force: false, language: nil)
  cache = story_path(jsonl_path)
  return File.read(cache, encoding: 'UTF-8') if File.exist?(cache) && !force

  model = 'claude-haiku-4.5'
  language ||= 'English'
  parse_json_events(jsonl_path)
  events_txt = File.read(parsed_json_path(jsonl_path), encoding: 'UTF-8')
  prompt = "Read the Copilot session below and write a text in the #{language} language suitable for text-to-speech. Describe the conversation between the user and Copilot: what the user asked, what problems were solved, what tools Copilot used, and how things progressed step by step. Include details from all the events. Do not include code blocks or markdown formatting. Keep technical details from the code, which are hard for a text-to-speech function to pronounce, to a minimum. Avoid esoteric characters like '→'. Start with the heading 'Story generated by #{model}' (heading in English). Output the story directly as plain text in your response — do not write it to any file and do not use any tools.\n\n<session_events>\n#{events_txt}\n\n</session_events>\n"

  print '  ✦ Generating story… '
  $stdout.flush

  stdout = stderr = nil
  status = nil
  begin
    Timeout.timeout(600) do
      stdout, stderr, status = Open3.capture3('copilot', '--yolo', "--model=#{model}", '--prompt', prompt)
    end
    unless status.success?
      puts "failed (exit #{status.exitstatus})"
      warn "    #{stderr.strip}" unless stderr.to_s.strip.empty?
      return nil
    end

    heading_seen = false
    text = stdout.to_s.strip.split("\n").filter_map do |line|
      heading_seen = true if line.start_with?('Story generated by')
      line if heading_seen
    end.join("\n").strip

    if text.empty?
      puts 'failed (empty output)'
      return nil
    end

    File.write(cache, text, mode: 'w:UTF-8')
    puts 'done'
    text
  rescue Errno::ENOENT
    puts 'failed (copilot not found)'
    nil
  rescue Timeout::Error
    puts 'failed (timeout)'
    nil
  end
end

def load_events(input_path)
  events = []
  File.foreach(input_path, encoding: 'UTF-8').with_index(1) do |line, lineno|
    line = line.strip
    next if line.empty?

    begin
      events << JSON.parse(line)
    rescue JSON::ParserError => e
      warn "Warning: skipping malformed line #{lineno} in #{input_path}: #{e.message}"
    end
  end
  events
end

def process_file(input_path, output_path, a11y: false, story: false, force: false, language: nil)
  events = load_events(input_path)
  if events.empty?
    warn "  ⚠ No events found, skipping: #{input_path}"
    return
  end

  turns = build_turns(events)
  story_text = story ? generate_story(input_path, force: force, language: language) : read_story(input_path)
  html_content = render_html(build_overview(events), turns, events, input_path, a11y: a11y, story_text: story_text)
  File.write(output_path, html_content, mode: 'w:UTF-8')
  puts "  ✓ #{output_path}  (#{events.length} events, #{turns.length} turn(s))"
end

def read_session(session_dir)
  info = {
    'id' => File.basename(session_dir),
    'events_html' => File.join(session_dir, 'events.html'),
    'start_time' => '',
    'cwd' => '',
    'first_prompt' => '',
    'model' => '',
    'user_prompt_count' => 0,
    'intent_count' => 0,
    'has_story' => File.exist?(File.join(session_dir, 'story.txt')),
    'total_premium_requests' => 0,
    'model_metrics' => {}
  }

  jsonl_path = File.join(session_dir, 'events.jsonl')
  return info unless File.exist?(jsonl_path)

  begin
    File.foreach(jsonl_path, encoding: 'UTF-8') do |raw_line|
      raw_line = raw_line.strip
      next if raw_line.empty?

      begin
        event = JSON.parse(raw_line)
      rescue JSON::ParserError
        next
      end

      etype = event.fetch('type', '')
      data = event.fetch('data', {})

      if etype == 'session.start'
        info['start_time'] = data['startTime'] || event['timestamp'] || ''
        info['cwd'] = data.fetch('context', {}).fetch('cwd', '')
        info['model'] = data.fetch('selectedModel', '')
      elsif etype == 'user.message'
        info['user_prompt_count'] += 1
        if info['first_prompt'].empty?
          content = data.fetch('content', '')
          info['first_prompt'] = abbreviate(content) unless content.empty?
        end
      elsif info['model'].empty? && data.key?('model')
        info['model'] = data['model']
      elsif etype == 'tool.execution_start'
        if data['toolName'] == 'report_intent' && (data['arguments'] || {})['intent']
          info['intent_count'] += 1
        end
      elsif etype == 'session.shutdown'
        info['total_premium_requests'] = data.fetch('totalPremiumRequests', 0)
        info['model_metrics'] = data.fetch('modelMetrics', {})
      end
    end
  rescue OSError
    nil
  end

  info
end

def build_overview_html(sessions)
  home = File.expand_path('~')
  data = []
  sessions.each do |session|
    next if session['first_prompt'].start_with?('Read the Copilot session')

    cwd = session['cwd']
    data << {
      ts: fmt_ts_long(session['start_time']),
      ts_raw: session['start_time'],
      cwd: cwd,
      cwd_display: cwd.empty? ? '' : cwd.sub(home, '~').split('/').last(2).join('/'),
      model: session['model'],
      activity: "#{session['user_prompt_count']}+#{session['intent_count']}",
      activity_total: session['user_prompt_count'] + session['intent_count'],
      has_story: session['has_story'],
      prompt: session['first_prompt'],
      link: session['events_html']
    }
  end

  agg = {}
  sessions.each do |session|
    session.fetch('model_metrics', {}).each do |model, metrics|
      bucket = agg[model] ||= { requests: 0, premium: 0, input_tokens: 0, output_tokens: 0 }
      bucket[:requests] += metrics.fetch('requests', {}).fetch('count', 0)
      bucket[:premium] += metrics.fetch('requests', {}).fetch('cost', 0)
      bucket[:input_tokens] += metrics.fetch('usage', {}).fetch('inputTokens', 0)
      bucket[:output_tokens] += metrics.fetch('usage', {}).fetch('outputTokens', 0)
    end
  end

  model_usage_html = ''
  unless agg.empty?
    rows = agg.sort.map do |model, metrics|
      "<tr><td>#{escape(model)}</td><td class=\"num\">#{fmt_number(metrics[:requests])}</td><td class=\"num mu-premium\">#{fmt_number(metrics[:premium])}</td><td class=\"num\">#{fmt_number(metrics[:input_tokens])}</td><td class=\"num\">#{fmt_number(metrics[:output_tokens])}</td></tr>"
    end.join
    totals = {
      requests: agg.values.sum { |metrics| metrics[:requests] },
      premium: agg.values.sum { |metrics| metrics[:premium] },
      input_tokens: agg.values.sum { |metrics| metrics[:input_tokens] },
      output_tokens: agg.values.sum { |metrics| metrics[:output_tokens] }
    }
    if agg.length > 1
      rows << "<tr class=\"mu-total\"><td>Total</td><td class=\"num\">#{fmt_number(totals[:requests])}</td><td class=\"num mu-premium\">#{fmt_number(totals[:premium])}</td><td class=\"num\">#{fmt_number(totals[:input_tokens])}</td><td class=\"num\">#{fmt_number(totals[:output_tokens])}</td></tr>"
    end
    model_usage_html = <<~HTML
      <div class="overview-section mu-section">
        <h2 class="mu-title">🧮 Model usage</h2>
        <table class="mu-table">
          <thead><tr>
            <th>Model</th>
            <th>Requests</th>
            <th>Premium</th>
            <th>Input tokens</th>
            <th>Output tokens</th>
          </tr></thead>
          <tbody>#{rows}</tbody>
        </table>
      </div>
    HTML
  end

  js = OVERVIEW_JS.sub('__DATA__', JSON.generate(data, ascii_only: false))
  generated = Time.now.strftime('%Y-%m-%d %H:%M:%S')

  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Copilot Sessions Overview</title>
      <link rel="icon" type="image/svg+xml" href="#{FAVICON_URI}">
      <style>#{OVERVIEW_CSS}</style>
    </head>
    <body>
      <div class="container">
        <div class="overview-section">
          <h1 class="page-title"><img src="#{FAVICON_URI}" style="height:1.2em;vertical-align:middle;margin-right:8px;"> Copilot Sessions</h1>
          <p class="page-meta">#{sessions.length} sessions &nbsp;·&nbsp; generated #{generated}</p>
          <div class="toolbar">
            <input class="search-bar" type="search" placeholder="Filter by prompt, directory, or model…" id="search" autofocus>
            <button class="btn" id="btn-expand">Expand all</button>
            <button class="btn" id="btn-collapse">Collapse all</button>
          </div>
          <table class="sessions-table" id="sessions-table">
            <thead>
              <tr>
                <th data-col="0">Started <span class="sort-ind"> ↓</span></th>
                <th data-col="1">Directory <span class="sort-ind"> ↕</span></th>
                <th data-col="2">Model <span class="sort-ind"> ↕</span></th>
                <th data-col="3" title="user prompts + agent intents">Prompts+Intents <span class="sort-ind"> ↕</span></th>
                <th data-col="4" title="story available">📖 <span class="sort-ind"> ↕</span></th>
                <th data-col="5">First prompt <span class="sort-ind"> ↕</span></th>
              </tr>
            </thead>
            <tbody></tbody>
          </table>
        </div>
        #{model_usage_html}
      </div>
      <script>#{js}</script>
    </body>
    </html>
  HTML
end

def generate_overview
  paths = Dir.glob(File.expand_path('~/.copilot/session-state/*/events.html')).sort
  if paths.empty?
    warn 'No events.html files found.'
    return
  end

  warn "Found #{paths.length} session(s) for overview…"
  sessions = paths.map { |path| read_session(File.dirname(path)) }
  sessions.sort_by! { |session| session['start_time'] || '' }
  sessions.reverse!
  FileUtils.mkdir_p(File.dirname(OVERVIEW_OUTPUT))
  File.write(OVERVIEW_OUTPUT, build_overview_html(sessions), mode: 'w:UTF-8')
  puts OVERVIEW_OUTPUT
end

def parse_options(argv)
  options = { input: nil, a11y: false, story: false, force: false, language: nil }
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: session_view [options] [input]'
    opts.on('--a11y', 'Use colorblind-friendly palette (red/green → orange/blue)') { options[:a11y] = true }
    opts.on('--story', 'Generate a Story tab using the storyteller agent (cached in story.txt; use --force to regenerate)') { options[:story] = true }
    opts.on('-f', '--force', 'Re-generate story even if story.txt exists.') { options[:force] = true }
    opts.on('-l', '--language LANGUAGE', 'Language for the generated story (default is English).') { |value| options[:language] = value }
    opts.on('-h', '--help', 'Show this help') do
      puts opts
      puts
      puts DOC
      exit
    end
  end
  parser.parse!(argv)
  options[:input] = argv.shift
  parser.error('too many arguments') unless argv.empty?
  options
end

def main(argv = ARGV)
  options = parse_options(argv.dup)
  self_mtime = File.mtime(__FILE__).to_f

  if options[:input]
    input_path = File.expand_path(options[:input])
    unless File.exist?(input_path)
      candidate = File.expand_path("~/.copilot/session-state/#{options[:input]}/events.jsonl")
      input_path = candidate if File.file?(candidate)
    end

    unless File.file?(input_path)
      warn "Error: file not found: #{input_path}"
      exit 1
    end
    if options[:language] && !options[:story]
      warn 'Error: -l/--language is not valid together with --story.'
      exit 1
    end
    if options[:force] && !options[:story]
      warn 'Error: -f/--force is not valid together with --story.'
      exit 1
    end

    output_path = File.join(File.dirname(input_path), 'events.html')
    if File.exist?(output_path) && !options[:story]
      out_mtime = File.mtime(output_path).to_f
      if File.mtime(input_path).to_f <= out_mtime && self_mtime <= out_mtime
        puts "Up to date: #{output_path}"
        return
      end
    end
    process_file(input_path, output_path, a11y: options[:a11y], story: options[:story], force: options[:force], language: options[:language])
  else
    if options[:story]
      warn 'Error: --story is not valid in batch mode.'
      exit 1
    end
    paths = Dir.glob(File.expand_path(DEFAULT_GLOB)).sort
    if paths.empty?
      warn "No files matched: #{DEFAULT_GLOB}"
      exit 1
    end

    puts "Processing #{paths.length} session file(s)…"
    ok = 0
    skipped = 0
    generated = 0

    paths.each do |path|
      output_path = File.join(File.dirname(path), 'events.html')
      if File.exist?(output_path)
        out_mtime = File.mtime(output_path).to_f
        if File.mtime(path).to_f <= out_mtime && self_mtime <= out_mtime
          skipped += 1
          next
        end
      end

      begin
        process_file(path, output_path, a11y: options[:a11y])
        ok += 1
        generated += 1
      rescue StandardError => e
        warn "  ✗ #{path}: #{e}"
        skipped += 1
      end
    end

    puts "\nDone: #{ok} written, #{skipped} skipped."
    generate_overview if generated.positive?
  end
end

main if $PROGRAM_NAME == __FILE__
