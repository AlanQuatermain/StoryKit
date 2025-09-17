# StoryKit — Agent Guide

This repository is a Swift Package for a data‑driven, extensible “choose your own adventure” engine and tooling. It is organized as multiple sub‑modules that compose into a single umbrella library, plus a CLI tool for authoring tasks.

## Targets and Layout

- Library product `StoryKit` composed of sub‑targets:
  - `Core`: Data models (Story/Node/Choice), `TextRef`, predicate/effect/action descriptors, `StoryState` protocol, and registries for extensibility.
  - `Engine`: `StoryEngine<State>` actor orchestrating flow, predicates, effects, and autosave hooks.
  - `Persistence`: `SaveProvider` protocol with `InMemorySaveProvider` and `JSONFileSaveProvider` + autosave helper.
  - `ContentIO`: Loaders (source JSON and compiled bundle), compiler to directory `.storybundle`, Markdown section parser, and validator.
  - `StoryKit`: Umbrella target re‑exporting submodules for a single `import StoryKit` usage.
- Executable `storykit` (target `StoryKitCLI`) providing authoring commands.
- Tests use `swift-testing` (import `Testing`).

Repository layout at a glance:

- `Package.swift` (Swift tools 6.2)
- `Sources/Core/*`
- `Sources/Engine/*`
- `Sources/Persistence/*`
- `Sources/ContentIO/*`
- `Sources/StoryKit/*` (umbrella)
- `Sources/StoryKitCLI/*` (CLI entry)
- `Tests/StoryKitTests/*` (swift-testing)

## Platforms and Build

- Minimum platforms: `.macOS("26.0")`, `.iOS("26.0")`.
- Dependencies: Apple’s `swift-argument-parser` for CLI.
- Concurrency: Swift Concurrency throughout; closures stored in registries are `@Sendable`. Public models are `Sendable` where applicable.

Build and test:

- `swift build`
- `swift test`

Run the CLI (examples):

- `swift run storykit validate <source-or-bundle-path>`
- `swift run storykit graph <path> [--format text|dot|json] [--out <file>]`
- `swift run storykit compile <source-path> --out <bundle-dir>`

Note: `storykit graph` writes to stdout by default; provide `--out` to write to a file. DOT output declares nodes and edges; JSON emits an array of `{from,to}`.

## Authoring Model (for reference)

- `story.json` defines the graph and metadata: nodes with `TextRef { file, section }`, choices with destination IDs, optional predicates/effects.
- Markdown text lives in `texts/*.md`, with multiple sections per file delimited by lines like:
  `=== node: <section-id> ===`
- Compiled `.storybundle` (directory) contains `graph.json`, `manifest.json`, and a `texts/` copy.

Data format notes:

- Story nodes are encoded/decoded as a string-keyed dictionary in JSON (e.g., `"nodes": { "a": { ... } }`), but exposed in Swift as `[NodeID: Node]`.
- `manifest.json` includes schemaVersion, story metadata, a SHA-256 hash of `graph.json`, and a build timestamp.

## Validation

Implemented checks:

- Structural: missing start node, missing choice destinations, unreachable nodes, duplicate choice IDs per node, dictionary key/id mismatch.
- Flow: nodes with empty choices, cycles with no exits (SCC detection).
- Content: missing or orphan Markdown sections, orphan Markdown files.

CLI behavior:

- `validate` accepts a source directory (uses `story.json` + `texts/`) or a directory `.storybundle` (detected via `manifest.json` + `graph.json`).
- `validate` supports `--format text|json`. JSON reports `ok`, `errors`, `warnings`, and an `issues` array, and exits non-zero on errors only.

## Engine and Extensibility

- `StoryEngine<State: StoryState>` runs the story; state is app‑defined. On transitions, applies destination on‑enter effects and optional autosave.
- Extensibility via registries:
  - Predicates: `@Sendable (State, [String:String]) -> Bool`
  - Effects: `@Sendable (inout State, [String:String]) -> Void`
  - Actions: `@Sendable (inout State, [String:String]) throws -> ActionOutcome`
- Persistence: `SaveProvider` protocol, in‑memory and JSON file backends, autosave helper factory.

Cache behavior (ContentIO):

- `CachedSourceTextProvider` and `CachedBundleTextProvider` are actors that cache parsed Markdown per file.
- They implement LRU eviction by approximate byte size and purge on system memory pressure via `DispatchSource.makeMemoryPressureSource`.
- The dispatch handler hops into the actor context; be mindful when changing this code to preserve actor isolation.

## Coding Conventions

- Swift 6, module boundaries respected; prefer small, composable types.
- Concurrency safety: favor `Sendable` data, `actor` for mutable shared state. Mark closures `@Sendable` when stored.
- Keep Core dependency‑light; CLI may add authoring dependencies as needed.
- Tests: use `swift-testing` (`import Testing`), prefer deterministic fixtures.
  - Name tests in camelCase and group them using `@Suite("Name")`.
  - Provide human-readable labels with `@Test("Label")`.
  - For CLI tests, prefer spawning the `storykit` binary and capturing stdout; common build paths:
    - `.build/debug/storykit`
    - `.build/arm64-apple-macosx/debug/storykit`
    - `.build/x86_64-apple-macosx/debug/storykit`
  - In constrained CI, `swift test --disable-sandbox` may be required for process-spawn/coverage to work.

### Coverage

- Run with: `swift test --enable-code-coverage [--disable-sandbox]`
- Coverage JSON path: `swift test --show-codecov-path`
- Recent local snapshot: ~93% lines.

## Roadmap Notes / TODOs

- Tutorials (next session): step-by-step guides for integrating StoryKit in apps.
- Optional: Single-file bundle packaging (archive) and integrity checks.
- Optional: Additional lints (asset references, localization keys) and richer issue metadata.

## Tutorials (to be written soon)

We will add step‑by‑step tutorials covering:

- Implementing custom predicates, effects, and actions with examples.
- Designing and plugging in a concrete `StoryState` (e.g., RPG stats/inventory).
- Wiring autosave and save/load flows via `SaveProvider`.
- Loading and presenting Markdown text with `TextProvider`.
- Validating content during authoring and integrating `storykit` into build scripts.
- Compiling source to `.storybundle` and loading it in an app.

These tutorials are a priority for onboarding story authors and app teams.

## Documentation

- Umbrella DocC articles live under `Sources/StoryKit/StoryKit.docc` (no per-module catalogs).
- Symbol-level docs are present across public APIs in `Core`, `Engine`, `Persistence`, and `ContentIO`.

