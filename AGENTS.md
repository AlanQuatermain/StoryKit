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
- `swift run storykit graph <source-path>`
- `swift run storykit compile <source-path> --out <bundle-dir>`

## Authoring Model (for reference)

- `story.json` defines the graph and metadata: nodes with `TextRef { file, section }`, choices with destination IDs, optional predicates/effects.
- Markdown text lives in `texts/*.md`, with multiple sections per file delimited by lines like:
  `=== node: <section-id> ===`
- Compiled `.storybundle` (directory) contains `graph.json`, `manifest.json`, and a `texts/` copy.

## Validation

Implemented checks:

- Structural: missing start node, missing choice destinations, unreachable nodes, duplicate choice IDs per node, dictionary key/id mismatch.
- Flow: nodes with empty choices, cycles with no exits (SCC detection).
- Content: missing or orphan Markdown sections, orphan Markdown files.

CLI behavior:

- `validate` accepts a source directory (uses `story.json` + `texts/`) or a directory `.storybundle` (detected via `manifest.json` + `graph.json`).

## Engine and Extensibility

- `StoryEngine<State: StoryState>` runs the story; state is app‑defined. On transitions, applies destination on‑enter effects and optional autosave.
- Extensibility via registries:
  - Predicates: `@Sendable (State, [String:String]) -> Bool`
  - Effects: `@Sendable (inout State, [String:String]) -> Void`
  - Actions: `@Sendable (inout State, [String:String]) throws -> ActionOutcome`
- Persistence: `SaveProvider` protocol, in‑memory and JSON file backends, autosave helper factory.

## Coding Conventions

- Swift 6, module boundaries respected; prefer small, composable types.
- Concurrency safety: favor `Sendable` data, `actor` for mutable shared state. Mark closures `@Sendable` when stored.
- Keep Core dependency‑light; CLI may add authoring dependencies as needed.
- Tests: use `swift-testing` (`import Testing`), prefer deterministic fixtures.

## Roadmap Notes / TODOs

- CLI: Add `--format json` and severity levels (warning vs error) for `validate` output. Provide machine‑readable schema for CI and editor integrations.
- DOT graph export for GraphViz.
- Bundle manifest schema: include story metadata, content hashes, build info.
- Optional caching for text providers to speed repeated lookups.

## Tutorials (to be written soon)

We will add step‑by‑step tutorials covering:

- Implementing custom predicates, effects, and actions with examples.
- Designing and plugging in a concrete `StoryState` (e.g., RPG stats/inventory).
- Wiring autosave and save/load flows via `SaveProvider`.
- Loading and presenting Markdown text with `TextProvider`.
- Validating content during authoring and integrating `storykit` into build scripts.
- Compiling source to `.storybundle` and loading it in an app.

These tutorials are a priority for onboarding story authors and app teams.

