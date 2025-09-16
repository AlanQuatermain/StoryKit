# CLI

Use the `storykit` command to validate, visualize, and compile stories.

## Overview

The CLI targets everyday authoring workflows and CI checks. It relies on the same JSON and Markdown formats as the library.

## Commands

### Validate

Validate a path to a source folder, a compiled `.storybundle`, or a `story.json` file.

```
storykit validate <path> [--format text|json]
```

- `--format text` (default): Human‑readable output with `[ERROR]` and `[WARNING]` lines.
- `--format json`: Machine‑readable report with `ok`, `errors`, `warnings`, and `issues` array.

### Graph

Export the graph in various formats and write to stdout (default) or a file.

```
storykit graph <path> [--format text|dot|json] [--out <file>]
```

- `text`: Lines like `from -> to`.
- `dot`: GraphViz DOT (declares nodes and edges).
- `json`: Array of `{ "from": String, "to": String }`.

### Compile

Compile a source folder into a directory‑based bundle containing `graph.json`, `manifest.json`, and `texts/`.

```
storykit compile <source> --out <bundle-dir>
```

## Tips

- Use the JSON validator output in CI to fail builds on errors while allowing warnings.
- Pipe DOT output into GraphViz or graph tools for quick visualization.

