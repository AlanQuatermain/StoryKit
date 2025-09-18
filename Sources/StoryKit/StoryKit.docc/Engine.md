# Engine

Drive the story forward with the actor‑based runtime.

## Overview

The engine runtime provides ``StoryKit/StoryEngine`` — a Swift `actor` that executes transitions, evaluates predicates, applies effects, and triggers autosave.

``StoryKit/StoryEngine`` is generic over your app’s ``StoryKit/StoryState`` so you can model state that fits your rules.

## Key Types

- ``StoryKit/StoryEngine``: The main controller.
- ``StoryKit/EngineError``: Errors for unknown nodes/choices or blocked selections.

## Initialization

Initialize the engine with a loaded ``StoryKit/Story``, your initial state, registries, and an optional autosave handler:

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

- ``StoryKit/StoryEngine/currentNode()``: Returns the current node, if available.
- ``StoryKit/StoryEngine/availableChoices()``: Filters choices by evaluating registered predicates.
- ``StoryKit/StoryEngine/select(choiceID:)``: Applies choice effects, transitions to the destination, applies destination on‑enter effects, then invokes autosave.
- ``StoryKit/StoryEngine/performAction(id:parameters:)``: Invokes a registered action, allows state mutation, then invokes autosave.
- ``StoryKit/StoryEngine/performGlobalAction(id:)``: Transitions to a globally declared action’s destination and applies on‑enter effects, then autosaves.

All engine methods are isolated to the actor, ensuring thread safety.
