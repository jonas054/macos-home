---
name: mermaid-inline-svg
description: Create or update Markdown files with Mermaid diagrams rendered by mmdc and embedded as raw inline SVG. Use whenever a task needs a diagram or visual explanation, including flowcharts in coding plans.
---

Use this skill whenever a Markdown document would benefit from a diagram, such as a coding task flowchart, architecture overview, sequence diagram, state
transition diagram, or data model.

## Required output

- Put the diagram in the requested Markdown file at the point where it explains the surrounding text.
- Embed the rendered element directly as `<svg>...</svg>` in the Markdown.
- Do not leave a Mermaid fenced code block, an external `.svg` link, a Markdown image reference, or a data URI in the final document unless the user explicitly requests it.
- Keep the diagram readable at normal Markdown zoom. Split a diagram into smaller diagrams when one becomes too dense.
- Add a short caption or explanatory sentence when the diagram's meaning is not obvious from nearby text.

## Workflow

1. Identify the Markdown destination and the diagram's purpose. Choose the simplest suitable Mermaid diagram type. For an unspecified process or plan, prefer `flowchart TD`.

2. Check that Mermaid CLI is available before rendering:

   ```sh
   command -v mmdc
   mmdc --version
   ```

   If `mmdc` is unavailable, stop and report that Mermaid CLI must be installed. Do not fabricate SVG output or silently fall back to a Mermaid code block.

3. Write the Mermaid source to a uniquely named temporary `.mmd` file. Documentation of the Mermaid syntax can be found starting at
   `~/dev/mermaid/docs/intro/index.md`. The source must contain Mermaid syntax only, without Markdown fences. For flowcharts, prefer native SVG text to
   avoid renderer-dependent `foreignObject` clipping:

   ```mermaid
   %%{init: {"htmlLabels": false}}%%
   flowchart TD
       A["Short line<br/>explicitly wrapped"]
   ```

   Split long labels with explicit `<br/>` breaks before they approach the node's edge; do not rely on automatic wrapping for important text.

4. Render it with Mermaid CLI:

   ```sh
   mmdc -i path/to/diagram.mmd -o path/to/diagram.svg
   ```

   Use a transparent background if the installed `mmdc` supports that option.

5. Validate and inspect the generated SVG. Run `xmllint --noout path/to/diagram.svg`; it must parse as XML with one `<svg>` root and a closing
   `</svg>`. For flowcharts, confirm that native text is used and no `<foreignObject>` labels remain. If text is close to a node edge or appears clipped,
   shorten the label or add an explicit `<br/>` in the Mermaid source and rerender. If it contains an XML declaration or doctype before the root, remove
   only those wrappers before embedding it. Preserve the SVG namespaces, `viewBox`, styles, and generated geometry.

6. Insert the SVG contents directly into the Markdown. Preserve the generated SVG rather than hand-editing paths or coordinates. Do not reference the
   temporary files from the Markdown.

7. Make the inline diagram accessible where practical: use a meaningful caption or sentence, and add a concise `<title>` plus
   `role="img"`/`aria-labelledby` without changing the generated geometry when the surrounding Markdown renderer supports those attributes.

8. Verify that the Markdown contains exactly one intended `<svg>` and `</svg>` pair, that the diagram is in the intended location, and that no external
   image or temporary-file reference remains. Clean up only the temporary files created for the render.

## Editing and regeneration

Treat Mermaid as the source of truth. When a diagram changes, update the Mermaid source and rerun `mmdc`; do not manually patch the generated SVG.

If rendering fails, correct the Mermaid syntax and rerun the command. If it still fails, report the exact `mmdc` error and leave the Markdown unchanged
rather than inserting incomplete SVG.
