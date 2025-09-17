# StoryKit

StoryKit is an extensible, data‑first engine and toolchain for building “choose your own adventure”‑style interactive stories. It models stories as graphs, executes flow deterministically with your own app‑defined state, and ships with authoring utilities to validate, visualize, and package content.

- Platforms: iOS 26.0, macOS 26.0
- Language: Swift 6 + Concurrency
- Targets: `Core`, `Engine`, `Persistence`, `ContentIO`, umbrella `StoryKit`, CLI `storykit`

## Why StoryKit?

- Data‑driven: author content as JSON + Markdown with simple, portable schemas.
- Deterministic engine: host app controls state, actions, and randomness.
- Extensible: register your own predicates, effects, and actions.
- Batteries included: validation, graph export (text/DOT/JSON), and packaging to a directory `.storybundle`.

## High‑Level API

- Core data model
  - `Story` (metadata, start, nodes), `Node`, `Choice`, `TextRef`, `NodeID`, `ChoiceID`.
- Extensibility
  - `PredicateRegistry`, `EffectRegistry`, `ActionRegistry` map string ids to your `@Sendable` closures.
- Engine
  - `StoryEngine<State>` actor runs the story: `availableChoices()`, `select(choiceID:)`, `performAction(id:)`, optional autosave closure.
- Persistence
  - `SaveProvider` protocol with `InMemorySaveProvider` and `JSONFileSaveProvider`; helper `makeAutoSaveHandler`.
- Content I/O
  - `StoryLoader` (source), `StoryBundleLoader` (compiled), `StoryCompiler`, `StoryBundleManifest`.
  - `TextSectionParser` and text providers (simple/cached with LRU + memory pressure).

See the DocC articles in `Sources/StoryKit/StoryKit.docc` for deeper explanations (Core, Engine, Persistence, ContentIO, Validation, Extensibility, CLI, DataFormats).

## Installing

### Swift Package Manager (Package.swift)

Add StoryKit to your package dependencies and targets. Replace the URL with your repository URL.

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/your-org/StoryKit.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "StoryKit", package: "StoryKit")
            ]
        )
    ]
)
```

### Xcode (Add Package Dependencies)

- In Xcode, choose: File → Add Package Dependencies…
- Enter your repository URL (e.g. `https://github.com/your-org/StoryKit.git`).
- Pick version `0.1.0` (or a compatible range) and add the `StoryKit` product to your app.

## Quick Start

1) Load a story (source JSON shown here):

```swift
import StoryKit

let source = StorySourceLayout(root: URL(fileURLWithPath: "/path/to/source"))
let story = try StoryLoader().loadStory(from: source.storyJSON)
```

2) Define your state and registries:

```swift
struct GameState: StoryState, Codable, Sendable { var currentNode: NodeID; var gold = 0 }
var preds = PredicateRegistry<GameState>()
var effs = EffectRegistry<GameState>()

preds.register("hasGold") { state, _ in state.gold > 0 }
effs.register("addGold") { state, params in state.gold += Int(params["amount"] ?? "0") ?? 0 }
```

3) Create the engine and run:

```swift
let engine = StoryEngine(
    story: story,
    initialState: GameState(currentNode: story.start),
    predicateRegistry: preds,
    effectRegistry: effs
)

let node = await engine.currentNode()
let choices = await engine.availableChoices()
if let first = choices.first { _ = try await engine.select(choiceID: first.id) }
```

## Authoring & Formats

- `story.json`: metadata, start id, nodes map (string‑keyed), choices with optional predicates/effects.
- Markdown: multiple sections per file using lines like `=== node: <section-id> ===`.
- `.storybundle`: directory with `graph.json`, `manifest.json`, and `texts/` produced by the compiler.

See <doc:DataFormats> (DocC) for complete details and examples.

## CLI

Install and run via SwiftPM:

```bash
swift run storykit validate /path/to/source --format json
swift run storykit graph /path/to/source --format dot > graph.dot
swift run storykit compile /path/to/source --out My.storybundle
```

## License

Copyright (c) 2025. All rights reserved. (License to be finalized.)

