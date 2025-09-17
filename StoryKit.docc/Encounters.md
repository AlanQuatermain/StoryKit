# Encounters and Globals

Model multi‑step battles in your app while keeping content data‑only.

## Goals

- Keep `story.json` declarative: names/ids/tags only — no mechanics.
- Let the client run encounters turn‑by‑turn without advancing the engine.
- Provide global outcomes (e.g., “player died”) that can transition from anywhere.

## Data Shape (content)

- Top‑level `entities`: canonical entities to reference (labels/tags/art keys).
- Per‑node `actors`: which entities are present at the location.
- Top‑level `globals.globalActions`: global outcomes mapping to destination nodes.

```json
{
  "entities": { "goblin": { "name": "Goblin", "tags": ["hostile"] } },
  "nodes": {
    "cellar": { "id": "cellar", "text": {"file":"t.md","section":"cellar"},
      "actors": [ { "id": "g1", "ref": "goblin" } ],
      "choices": [ { "id": "fight", "title": "Fight", "destination": "cellar" } ]
    }
  },
  "globals": { "globalActions": { "playerDied": { "destination": "fail" } } }
}
```

## Minimal Client Implementation

Define state that can hold an encounter sub‑state. Your app controls the rules.

```swift
import Core
import Engine

struct EncounterState: Sendable, Codable {
    struct Participant: Sendable, Codable { var id: String; var hp: Int }
    var participants: [Participant]
    var turn: Int = 0
}

struct GameState: StoryState {
    var currentNode: NodeID
    var activeEncounter: EncounterState? = nil
}

enum BattleMove { case attack(targetID: String); case defend }
```

Register actions that mutate `GameState`. Return values are for your UI; the engine does not advance nodes.

```swift
var actions = ActionRegistry<GameState>()

actions.register("startEncounter") { state, params in
    // Seed from current node's actors (or params). Mechanics are yours.
    guard state.activeEncounter == nil else { return .completed }
    let actorsHere = /* resolve from story.nodes[state.currentNode].actors */ [] as [String]
    state.activeEncounter = EncounterState(
        participants: actorsHere.map { .init(id: $0, hp: 10) }, turn: 0
    )
    return .requiresUserInput(hint: "encounter-begun")
}

actions.register("encounterTurn") { state, params in
    guard var enc = state.activeEncounter else { return .completed }
    // Decode your move (String params -> your domain).
    let target = params["target"] ?? ""
    // Apply your rules.
    if let i = enc.participants.firstIndex(where: { $0.id == target }) {
        enc.participants[i].hp -= 3
    }
    enc.turn += 1
    state.activeEncounter = enc
    return .requiresUserInput(hint: "turn-complete")
}
```

Drive the UI loop while staying on the same node. When a terminal condition happens, trigger a global action.

```swift
let engine = StoryEngine(
    story: story,
    initialState: GameState(currentNode: story.start),
    actionRegistry: actions
)

// Start encounter (e.g., on tapping a choice)
_ = try await engine.performAction(id: "startEncounter")

// Turn loop (UI driven)
while let enc = await engine.state.activeEncounter, enc.participants.contains(where: { $0.hp > 0 }) {
    // Render UI from state.
    // On player input, call encounterTurn with parameters.
    _ = try await engine.performAction(id: "encounterTurn", parameters: ["target": "g1"]) // example

    // Check terminal conditions and transition via a global action if needed.
    if /* player HP <= 0 */ false {
        _ = try await engine.performGlobalAction(id: "playerDied")
        break
    }
}

// On victory, your action/logic can set flags and then normal choice selection can continue.
```

Notes:

- Actions run on the engine actor and autosave (if configured) after each call.
- Global actions apply on‑enter effects of their destination and autosave, just like normal transitions.
- Encode richer parameters by convention (e.g., JSON in a string) if you need more structure.

