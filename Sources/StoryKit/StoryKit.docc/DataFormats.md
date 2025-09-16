# Data Formats

Understand the on‑disk formats used for authoring, compilation, and runtime.

## Authoring Source

An authoring source directory typically contains:

```
<story-root>/
  story.json
  texts/
    <markdown files>.md
  assets/            (optional)
```

### story.json

The structure file is a JSON object with these top‑level fields:

- `metadata`: `{ id: String, title: String, version: Int }`
- `start`: `String` — the NodeID where the story begins
- `nodes`: `Object` — mapping from NodeID (string) to node objects

Node objects:

- `id`: `String` — node identifier (should match the key)
- `text`: `{ file: String, section: String }` — Markdown location
- `tags`: `[String]` — optional labels
- `onEnter`: `[EffectDescriptor]` — effects applied when entering
- `choices`: `[Choice]` — outgoing edges

Choice objects:

- `id`: `String`
- `title`: `String` (optional)
- `titleKey`: `String` (optional, for future localization)
- `destination`: `String` — NodeID
- `predicates`: `[PredicateDescriptor]` — optional gating checks
- `effects`: `[EffectDescriptor]` — optional effects on select

Descriptor objects:

- `PredicateDescriptor`: `{ id: String, parameters: { String: String } }`
- `EffectDescriptor`: `{ id: String, parameters: { String: String } }`

Minimal example:

```json
{
  "metadata": { "id": "demo", "title": "Demo", "version": 1 },
  "start": "a",
  "nodes": {
    "a": {
      "id": "a",
      "text": { "file": "t.md", "section": "a" },
      "tags": [],
      "onEnter": [],
      "choices": [
        { "id": "go", "title": "Continue", "destination": "b", "predicates": [], "effects": [] }
      ]
    },
    "b": {
      "id": "b",
      "text": { "file": "t.md", "section": "b" },
      "tags": [],
      "onEnter": [],
      "choices": []
    }
  }
}
```

### Markdown text files

Markdown files can contain multiple sections, delimited by a line of the form:

```
=== node: <section-id> ===
```

Example (`texts/t.md`):

```
=== node: a ===
You wake up to the sound of rain.

=== node: b ===
You step into the hallway.
```

Encoding is assumed to be UTF‑8.

## Compiled Bundle (.storybundle)

The compiler produces a directory‑based bundle that mirrors the source in a normalized form:

```
My.storybundle/
  manifest.json
  graph.json
  texts/
    *.md
```

### graph.json

`graph.json` is the normalized story graph used by the runtime. It has the same JSON shape as `story.json` but is produced by the compiler (e.g., after transforms). In the initial implementation, it is a copy of `story.json`.

### manifest.json

The manifest records basic metadata about the compiled bundle:

```json
{
  "schemaVersion": 1,
  "storyID": "demo",
  "title": "Demo",
  "version": 1,
  "graphHashSHA256": "<hex sha256 of graph.json>",
  "builtAt": 1737072000
}
```

- `schemaVersion`: Monotonically increasing schema identifier.
- `storyID`, `title`, `version`: Copied from story metadata.
- `graphHashSHA256`: Hex‑encoded SHA‑256 of `graph.json` for integrity.
- `builtAt`: Build timestamp as encoded by `JSONEncoder` (numeric seconds by default).

### texts/

Markdown files are copied from the source `texts/` directory without modification. They are resolved at runtime by the text providers.

## Graph Exports (CLI)

The `storykit graph` command can export edges in several formats (written to stdout by default):

- `text`: One line per edge — `from -> to`.
- `dot`: GraphViz DOT — declares nodes and edges, suitable for visualization.
- `json`: Array of edges — `[ { "from": String, "to": String } ]`.

