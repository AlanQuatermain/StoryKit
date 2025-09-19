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

## Haunted House Tutorials — Status & Next Session

This section captures the current state of work on the Haunted House story suite and DocC tutorials, plus what we’ll do next.

### Status Snapshot (as of last edit)

- Story validates and compiles; node count ~322.
- All tutorials live under `Sources/StoryKit/StoryKit.docc/Tutorials/` with code/output snippets under `Sources/StoryKit/StoryKit.docc/Resources/`.
- Terminal endings are marked to suppress empty‑choice warnings.

### Tutorials — Completion

- Tutorial 1 (validating & repairing a story): friendlier tone, download/build steps, clear error explanations, and aligned snippets (arrival_road start, end_successful fix). Validator outputs are clean.
- Tutorial 2 (playing a story in Swift): multi‑step CLI section, casual rationale for StoryState and loader/caching, granular engine loop steps, refined outcome (what you built vs. what StoryKit handles).
- Tutorial 3 (state, checks, actions, battle, ritual, autosave): restructured into multi‑step sections with incremental snippets; emphasizes engine‑agnostic design (mechanics in client, content declarative).

### Next Session (Reader QA pass)

- Run through Tutorials 1–3 end‑to‑end as a reader:
  - Follow each step, run commands, and confirm snippets match current code and outputs.
  - Check tone/clarity/pacing; ensure each change is incremental and the “why” is obvious.
  - Verify all `@Code(file:)` references resolve; fix any drift.
- Validate and build docs post‑pass:
  - `swift build && swift test`
  - `swift package --disable-sandbox --allow-writing-to-directory docs generate-documentation --target StoryKit --output-dir docs --transform-for-static-hosting --hosting-base-path StoryKit`
  - Address any structural DocC warnings (e.g., ensure each Section has Steps).

#### QA Checklist (commands to run)

- Tutorial 1 (Validating a Story → Compiling)
  - Prepare a scratch folder (e.g., `~/Downloads/HauntedStarter`) with the starter zip (as described in the tutorial).
  - From StoryKit package root:
    - `swift build`
    - `swift run storykit validate ~/Downloads/HauntedStarter --format text`
    - `swift run storykit validate ~/Downloads/HauntedStarter --format json | jq .`
  - After each fix (per steps), re‑run validate and confirm outputs match snippets:
    - Post‑JSON fixes: `swift run storykit validate ~/Downloads/HauntedStarter --format text`
  - Compile and verify bundle structure:
    - `swift run storykit compile ~/Downloads/HauntedStarter --out HauntedHouse.storybundle`
    - `ls -R HauntedHouse.storybundle`

- Tutorial 2 (CLI + State + Loop)
  - In a separate temp directory, initialize a new executable package and add StoryKit as a path dependency (per snippet).
  - Build and run help:
    - `swift build`
    - `swift run haunted --help`
  - Play a bundle (use the one compiled above):
    - `swift run haunted ./HauntedHouse.storybundle`
  - Confirm loop shows header, text, and numbered choices; pick a few choices and verify output formatting.

- Tutorial 3 (Extended state, checks, actions, ritual, autosave)
  - Integrate snippet code into the CLI project from Tutorial 2 (or a scratch project):
    - Extend HauntedState; register predicates/effects/actions; wire autosave.
  - Sanity run with the same bundle:
    - `swift build`
    - `swift run haunted ./HauntedHouse.storybundle`
  - Confirm: checks gate choices as expected; melee‑round and flee actions advance narration; ritual action toggles flags based on order.

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

## DocC Tutorials — Agent Guide

This section captures how to author, structure, and maintain DocC tutorials for StoryKit. Agents should follow these rules when editing `.tutorial` files or documentation resources.

### Core Concepts

- Documentation kinds:
  - Tutorials: Interactive, step‑driven pages with code diffs and media.
  - Tutorials Table of Contents (ToC): The root `@Tutorials` page that organizes tutorials into chapters and references.
  - Articles: Free‑form `.md` pages (no steps) used for conceptual docs.
- File types:
  - `.tutorial` files contain one of: `@Tutorials`, `@Tutorial`, or `@Article` as the top‑level directive.
  - Assets live under the DocC catalog’s `Resources/` folder and are referenced by relative path.

### Tutorials Table of Contents

- Use `@Tutorials(name: "StoryKit")` to define the tutorial hierarchy for this package.
- Children of `@Tutorials`:
  - `@Intro(title: "…")`: short overview; can include `@Image`.
  - `@Chapter(name: "…")`: brief description and optional `@Image`.
    - Each chapter must include one or more `@TutorialReference(tutorial: "doc:YourTutorialFileName")` items that link to `@Tutorial` pages.

Official docs:
- https://www.swift.org/documentation/docc/tutorials
- https://www.swift.org/documentation/docc/intro
- https://www.swift.org/documentation/docc/chapter
- https://www.swift.org/documentation/docc/tutorialreference

### Tutorial Pages

- Top‑level directive: `@Tutorial(time: <minutes>, resourceReference: "path/To/Zip")`.
  - `time`: Estimated minutes for an engaged reader to complete.
  - `resourceReference` (optional): Path under `Resources/` to a downloadable zip; DocC surfaces a “Download Materials” link.
- Title and overview: Provided by nested `@Intro(title: "…")` (do not put a `title:` on `@Tutorial`).
- Sections:
  - Each `@Section(title: "…")` may include a `@ContentAndMedia` block (context prose, inline media).
  - Every `@Section` must contain exactly one `@Steps` block.
- Steps:
  - Each `@Step` must contain exactly one instruction paragraph (DocC warns on lists or extra blocks) and may include a single `@Code(file:)` or `@Image`.
  - Keep changes per step small (1–2 lines) with a succinct explanation.

Official docs:
- https://www.swift.org/documentation/docc/tutorial
- https://www.swift.org/documentation/docc/code
- https://www.swift.org/documentation/docc/image
- Syntax overview: https://www.swift.org/documentation/docc/tutorial-syntax

### Code Snippets and Diffs

- `@Code(file: "…", name: "…")` must reference a complete file, not a fragment.
- For DocC to highlight diffs between steps:
  - Use the same logical filename across the steps of a section (e.g., `Main.swift`).
  - Provide complete, cumulative files for each step (i.e., each file contains everything from the previous step plus the new change).
  - You can use DocC’s step suffix convention (e.g., `Main.swift`, `Main@2.swift`, `Main@3.swift`) for resource files while keeping `file: "Main.swift"` in the directive. DocC pairs consecutive step resources to compute diffs.

### Images and Media

- Use `@Image(source: "Images/placeholder.svg", alt: "Accessible description")`.
- Store all images under `Resources/Images/`.

### Linking and Disambiguation

- Use `doc:` links for cross‑references (e.g., `@TutorialReference(tutorial: "doc:Tutorial-1-Building-Your-First-Story")`, or `- <doc:Validation>` in articles).
- If DocC reports an ambiguous link, adjust headings (e.g., “Validation Guide”) or provide anchors.

### Resource Hygiene (Important)

- DocC treats `.md` files under `Resources/` as articles and warns if they don’t start with a top‑level heading. For code/text excerpts, use `.txt` or another non‑article format.
- Keep only referenced assets in `Resources/`. Do not check in large unzipped project trees—zip them and reference via `resourceReference`.
- For this repo, organize resources as follows:
  - `Resources/Images/`: tutorial images (placeholder.svg, etc.).
  - `Resources/Tutorial-1/`, `Resources/Tutorial-2/`, `Resources/Tutorial-3/`: code/text snippets for each tutorial, grouped by logical file with step variants (e.g., `Main.swift`, `Main@2.swift`).
  - `Resources/Projects/`: downloadable zips:
    - Tutorial 1: broken starter zip (e.g., `HauntedStarter.zip`).
    - Tutorials 2–3: complete bundle zip (e.g., `HauntedHouseBundle.zip`).

### Common Pitfalls to Avoid

- Putting the title on `@Tutorial` instead of inside `@Intro(title:)`.
- Omitting `@Steps` or adding multiple `@Steps` within a `@Section`.
- Using lists or multiple paragraphs inside `@Step` (causes warnings).
- Using code fragments instead of complete files in `@Code(file:)`.
- Leaving unpacked `.md` story files in `Resources/` (DocC warns about missing titles). Prefer `.txt` for excerpts, and zipped projects for full content.
- Using `@TechnologyRoot`/unsupported `@Metadata` children in documentation extensions (not supported here).

### Checklist for Agents Editing Tutorials

- Update or add entries in the ToC (`@Tutorials`) for any new tutorials; keep chapter images/descriptions in sync.
- Ensure each tutorial has a realistic `time:` and a `resourceReference` if materials are needed.
- Validate that every `@Section` has exactly one `@Steps`, and every `@Step` has exactly one paragraph and one `@Code`/`@Image`.
- Verify snippet files exist under `Resources/Tutorial-X/` and represent complete files per step with diffs computable across steps.
- Rebuild docs and fix all warnings: `swift package --disable-sandbox --allow-writing-to-directory docs generate-documentation --target StoryKit --output-dir docs --transform-for-static-hosting --hosting-base-path StoryKit`.

### Official References

- Tutorial Syntax (overview): https://www.swift.org/documentation/docc/tutorial-syntax
- Code directive: https://www.swift.org/documentation/docc/code
- Tutorials root: https://www.swift.org/documentation/docc/tutorials
- Tutorial page: https://www.swift.org/documentation/docc/tutorial
- Intro directive: https://www.swift.org/documentation/docc/intro
- Chapter directive: https://www.swift.org/documentation/docc/chapter
- TutorialReference: https://www.swift.org/documentation/docc/tutorialreference
- Image directive: https://www.swift.org/documentation/docc/image
