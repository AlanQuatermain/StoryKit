# SyncSnippets — Tutorial Snippet Synchronizer

SyncSnippets keeps the DocC tutorial code listings and the actual story source in sync. It can:

- Extract snippets from a story source (zip or directory) into the DocC `@Code` files.
- Apply edits you make to the tutorial `@Code` files back into the story source (zip or directory).

It understands both JSON graph snippets and Markdown text snippets and matches content by node IDs or section headers.

## Requirements

- Swift 6.2 toolchain (same as the package)
- macOS with `/usr/bin/unzip` and `/usr/bin/zip` available (for zip mode)

## Build

```
swift build -c debug --product SyncSnippets
# or
swift build -c release --product SyncSnippets
```

Binary path examples:
- `.build/debug/SyncSnippets`
- `.build/release/SyncSnippets`

## Concepts

- Tutorial snippets live next to the `.tutorial` files:
  - `Sources/StoryKit/StoryKit.docc/Tutorials/*.json|*.txt|*.swift`
- Packaged story zips live under:
  - `Sources/StoryKit/StoryKit.docc/Resources/zips/haunted-before.zip`
  - `Sources/StoryKit/StoryKit.docc/Resources/zips/haunted-after.zip`
- A story directory must contain:
  - `story.json`, `texts/haunted.md` (and optionally `graph.json` which will be mirrored from `story.json`)

## Usage

```
SyncSnippets \
  --direction source-to-snippets|snippets-to-source \
  [--zip haunted-before|haunted-after | --dir /path/to/story-root] \
  [--changed <path>] ...
```

- `--direction` (required):
  - `source-to-snippets`: read the story source and update tutorial files.
  - `snippets-to-source`: read the tutorial files and update the story source.
- `--zip`: choose a packaged story by name (looked up under `Resources/zips/`).
- `--dir`: point to a directory containing `story.json` and `texts/haunted.md`.
- `--changed`: limit what to sync (repeatable). Defaults to `story.json` and `texts/haunted.md` when omitted in source→snippets direction.

You must supply either `--zip` or `--dir`.

## What gets synchronized

- JSON snippets (`*.json` next to `.tutorial` pages):
  - If the snippet contains a top-level `nodes` dictionary, only those node IDs are synchronized.
  - If the snippet is a single node object (has an `id`), that node is synchronized.
  - `start` is synchronized when present in the snippet.
- Markdown snippets (`*.txt` next to `.tutorial` pages):
  - Sections are matched by headers like `=== node: <id> ===` and replaced with the source version.
  - Order of sections in the snippet is preserved.

When writing to source:
- `story.json` is updated and `graph.json` is refreshed to match it.
- `texts/haunted.md` is updated by merging or replacing the snippet’s sections.
- Unknown nodes/sections are left untouched unless explicitly provided by a snippet.

## Examples

- Extract both graph + text snippets from the fixed story zip:
```
swift run SyncSnippets --direction source-to-snippets --zip haunted-after
```

- Apply an edited tutorial JSON snippet back into the fixed story zip:
```
swift run SyncSnippets \
  --direction snippets-to-source \
  --zip haunted-after \
  --changed Sources/StoryKit/StoryKit.docc/Tutorials/01-building-code-03.json
```

- Extract snippets from a directory story root:
```
swift run SyncSnippets --direction source-to-snippets --dir /absolute/path/to/haunted-after
```

- Apply an edited Markdown snippet back into a directory story root:
```
swift run SyncSnippets \
  --direction snippets-to-source \
  --dir /absolute/path/to/haunted-after \
  --changed Sources/StoryKit/StoryKit.docc/Tutorials/01-building-code-04.txt
```

## Notes & Tips

- For zip mode, the tool unpacks into a temporary directory and (when applying) re-creates the zip in place.
- For directory mode, files are modified in place. Commit or back up before applying changes.
- The Markdown snippet matcher is strict about section headers (`=== node: <id> ===`) and will only update sections present in the snippet file.
- The JSON node matcher synchronizes only the nodes and keys present in the snippet; it does not remove other nodes from `story.json`.

## Troubleshooting

- "error: provide either --zip or --dir" → pass exactly one source selector.
- "SyncSnippets error: …" → most commonly unzip/zip failures or missing files (`story.json`, `texts/haunted.md`).
- If you rename `texts/haunted.md`, update `--changed` and adjust the tool as needed.

## License

This utility is part of the StoryKit repository and follows the repository’s license.
