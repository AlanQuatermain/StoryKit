# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by Keep a Changelog. The project follows Semantic Versioning.

## [0.1.0] - 2025-09-16

### Overview
- Initial public scaffold of StoryKit, an extensible, data-first engine and toolchain for “choose your own adventure”-style stories.
- Targets: `Core`, `Engine`, `Persistence`, `ContentIO`, umbrella `StoryKit`, and CLI tool `storykit`.
- Platforms: iOS 26.0, macOS 26.0. Swift Concurrency throughout. Swift 6.2 toolchain.

### Added
- Core models and IDs
  - `Story`, `Node`, `Choice`, `TextRef`, `NodeID`, `ChoiceID`.
  - Codable schema with `Story.nodes` decoding/encoding as string-keyed dictionaries for authoring ergonomics.
- Extensibility registries
  - Predicates, effects, and actions via string-identified `@Sendable` closures.
- Engine
  - `StoryEngine<State: StoryState>` actor with choice gating, on-enter effects, and generic actions.
  - Autosave hook via `@Sendable (State) async throws -> Void` called after transitions/actions.
- Persistence
  - `SaveProvider` protocol; `InMemorySaveProvider` and `JSONFileSaveProvider` implementations.
  - Helper: `makeAutoSaveHandler(storyID:slot:provider:)`.
- Content I/O
  - `StoryLoader` (source) and `StoryBundleLoader` (compiled bundle).
  - Compiler to directory-based `.storybundle` (`graph.json`, `manifest.json`, `texts/`).
  - `StoryBundleManifest` with schema version, story metadata, and SHA-256 of `graph.json`.
  - `TextSectionParser` for multi-section Markdown using `=== node: <id> ===` delimiters.
  - Text providers: non-cached and actor-based cached providers with LRU eviction and memory-pressure purge.
- Validation
  - `StoryValidator` with severities (error/warning): missing start, missing destinations, unreachable nodes, duplicate choice IDs, key/id mismatch, empty choices, no-exit cycles, missing/orphan text sections, orphan markdown files.
- CLI (`storykit`)
  - `validate <path>`: validates source folder, compiled bundle, or `story.json`; supports `--format text|json` (JSON prints machine-friendly report; exit non-zero only on errors).
  - `graph <path> [--format text|dot|json] [--out <file>]`: exports edges; writes to stdout when `--out` omitted; DOT declares nodes and edges.
  - `compile <source> --out <bundle-dir>`: builds a directory-based `.storybundle`.

### Testing
- Uses `swift-testing`; tests organized in suites with descriptive names.
- Coverage (local run): ~93% lines.
- Includes engine flow, registry behavior, autosave, validator severities and cycles, text parsing, manifest/hash, persistence backends, cached providers (LRU + memory pressure), and CLI exit/stdout tests for graph/validate/compile.

### Notes
- Localization hooks and advanced packaging (single-file archive) planned for future versions.
- CLI DOT output suitable for GraphViz; JSON graph is a simple edge list.

[0.1.0]: https://example.com/storykit/releases/0.1.0
