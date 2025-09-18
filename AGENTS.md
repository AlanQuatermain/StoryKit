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

## Haunted House Tutorials — Active TODOs & Working Notes

This section captures the current state of work on the Haunted House story suite and DocC tutorials so the next session can resume smoothly.

### Status Snapshot (as of last edit)

- Variants and bundle live under `StoryKit.docc/Resources/`:
  - `haunted-before/` — deliberately broken variant used in Tutorial 1.
  - `haunted-after/` — repaired variant; should match `haunted-final`.
  - `haunted-final/` — canonical working story; should validate/compile.
  - `HauntedHouseBundle/` — compiled bundle output for reference.
- Node counts (via `jq '.nodes | length'`):
  - `haunted-before`: 33
  - `haunted-final`: 102
  - `haunted-after`: 151
- Requirement per `.build/Instructions/Story-Design.md`: total 300–350 nodes with distribution by area and a healthy set of endings.
- Tutorials exist under `StoryKit.docc/Tutorials/` and reference code/output snippets under `StoryKit.docc/Resources/`.

### Immediate Actions (next session)

1. Align variants: make `haunted-final` match `haunted-after` exactly (graph + prose). Keep `haunted-before` broken per `.build/Instructions/Story-Variants.md`.
2. Expand content to meet node targets (300–350) using `.build/Instructions/Story-Design.md` for canonical design:
   - Ground: grow from ~54 (after) toward 100–120.
   - Upper: grow from ~38 (after) toward 100–120.
   - Basement: grow from ~42 (after) toward 85–95 (Catacombs already ~35 OK; expand Boiler, Stairs, Ritual Chamber micro-scenes).
   - Endings: expand from 14 toward 20–25 (8–10 Madness, 6–8 Scarred, plus All-Good + Death).
3. Maintain reachability and guard rails:
   - Every non-ending node must have at least one outgoing choice.
   - No unreachable or orphaned nodes/sections. Keep choice ids unique per node.
   - All nodes in `story.json` must have a corresponding Markdown section in `haunted.md`.
4. Re-run validation and compile after each batch:
   - `swift run storykit validate StoryKit.docc/Resources/haunted-final`
   - `swift run storykit compile StoryKit.docc/Resources/haunted-final --out StoryKit.docc/Resources/HauntedHouseBundle`
5. Verify DocC tutorials still resolve all `@Code(file:)` references. Update snippets only if tutorial narrative changes (counts are not asserted in current snippets).
6. If `haunted-after` is used as the working base, update `haunted-final` by copying graph + markdown; then delete any drift between the two.

### Targets by Area (from Story-Design.md)

- Ground Floor (target 100–120): Foyer, Dining, Kitchen & Pantry, Study, Parlor & Conservatory, Cellar Entrance.
- Upper Floor (target 100–120): Landing, Bedroom A/B, Nursery, Library, Master Suite, Balcony.
- Basement (target 85–95): Basement Stairs, Boiler Room, Catacombs (30–35 OK), Ritual Chamber.
- Endings (target 20–25): All-Good (1), Death (1), Madness (8–10), Scarred (6–8).

Current rough counts in `haunted-after` (for planning): foyer 3, dining 9, kitchen 8, pantry 4, study 9, parlor 7, conservatory 7, garden 3, cellar entrance 4, stairs 3; landing 3, bedroom A 6, bedroom B 4, nursery 8, library 9, master 6, balcony 2; basement stairs 1, boiler 5, catacombs 35, ritual chamber 1; endings 14.

### Authoring Conventions (must follow)

- IDs: group by area prefix (e.g., `dining_*`, `study_*`, `library_*`, `catacombs_#`). Prefer readable, stable ids.
- Choice ids: unique per node; convention `to_<dest>` or a short verb phrase (`search_drawer`, `return_study`).
- Prose length: aim for 80+ words for most nodes; 200+ words for room “arrival” descriptions (first node per area). Keep tone consistent (Lovecraftian, 1920s New Orleans).
- Endings: only `end_*` nodes should have zero choices. All others must present at least one exit path.
- Mechanics alignment: predicates/effects/actions may be referenced by id; ensure any used in `story.json` are defined in code or explained in tutorials (roll-under checks, combat rounds, ritual sequence).

### File Map (quick reference)

- Story variants and bundle:
  - `StoryKit.docc/Resources/haunted-before/story.json`
  - `StoryKit.docc/Resources/haunted-before/texts/haunted.md`
  - `StoryKit.docc/Resources/haunted-after/story.json`
  - `StoryKit.docc/Resources/haunted-after/texts/haunted.md`
  - `StoryKit.docc/Resources/haunted-final/story.json`
  - `StoryKit.docc/Resources/haunted-final/texts/haunted.md`
  - `StoryKit.docc/Resources/HauntedHouseBundle/`
- Tutorials and resources:
  - `StoryKit.docc/Tutorials/Tutorial-1-Building-Your-First-Story.tutorial`
  - `StoryKit.docc/Tutorials/Tutorial-2-Playing-a-Story-in-Swift.tutorial`
  - `StoryKit.docc/Tutorials/Tutorial-3-Adding-State-and-Skill-Checks.tutorial`
  - `StoryKit.docc/Resources/*.swift` (code excerpts), `*.txt` (validator/compiler outputs)
- Binding instructions (read first): `.build/Instructions/Master-Instructions.md`, `Story-Design.md`, `Story-Variants.md`

### Working Loop

1. Pick an area (e.g., Library) and draft 3–6 new micro-scenes (`library_*`).
2. For each new node: add entry to `story.json` and write the corresponding Markdown section in `texts/haunted.md`.
3. Wire choices both ways to maintain reachability and area flow; keep ids unique.
4. Validate (`swift run storykit validate ...`), fix any structural/content issues.
5. Periodically compile to refresh `HauntedHouseBundle` and sanity-check structure.

### Risks / Watchouts

- Variant drift: ensure `haunted-after` and `haunted-final` remain identical; tutorials assume “after” equals “final”.
- Orphan sections: adding text sections without nodes triggers content warnings; keep graph and Markdown in lockstep.
- Endings inflation: keep within Story-Design ranges; avoid overwhelming the endings category while under-filling core areas.
- Choice id collisions: duplicate ids per node are validator errors.

### Definition of Done

- `haunted-final` has 300–350 nodes with distribution per Story-Design.
- `haunted-after` is identical to `haunted-final`.
- `haunted-before` fails validation exactly as defined in Story-Variants.
- All three tutorials build in DocC and all `@Code(file:)` references resolve to existing files.
- `swift run storykit validate StoryKit.docc/Resources/haunted-final` yields no errors; only expected warnings for ending nodes with no choices.
- Compiled bundle updated and consistent with final.
