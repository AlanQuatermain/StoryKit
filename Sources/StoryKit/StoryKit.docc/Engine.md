# Engine

Drive the story forward with the actor‑based runtime.

## Overview

The Engine module provides ``Engine/StoryEngine`` — a Swift `actor` that executes transitions, evaluates predicates, applies effects, and triggers autosave.

``Engine/StoryEngine`` is generic over your app’s ``Core/StoryState`` so you can model state that fits your rules.

## Key Types

- ``Engine/StoryEngine``: The main controller.
- ``Engine/EngineError``: Errors for unknown nodes/choices or blocked selections.

## Initialization

Initialize the engine with a loaded ``Core/Story``, your initial state, registries, and an optional autosave handler:

```swift
let engine = StoryEngine(
    story: story,
    initialState: MyState(currentNode: story.start),
    predicateRegistry: preds,
    effectRegistry: effs,
    actionRegistry: acts,
    autosave: { state in try await provider.save(slot: "autosave", snapshot: .init(storyID: story.metadata.id, state: state)) }
)
```

## Flow API

- ``Engine/StoryEngine/currentNode()``: Returns the current node, if available.
- ``Engine/StoryEngine/availableChoices()``: Filters choices by evaluating registered predicates.
- ``Engine/StoryEngine/select(choiceID:)``: Applies choice effects, transitions to the destination, applies destination on‑enter effects, then invokes autosave.
- ``Engine/StoryEngine/performAction(id:parameters:)``: Invokes a registered action, allows state mutation, then invokes autosave.
- ``Engine/StoryEngine/performGlobalAction(id:)``: Transitions to a globally declared action’s destination and applies on‑enter effects, then autosaves.

All engine methods are isolated to the actor, ensuring thread safety.
