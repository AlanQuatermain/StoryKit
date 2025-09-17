# Extensibility

Customize logic with predicates, effects, and actions.

## Overview

StoryKit separates data from behavior. Authors reference symbolic ids in content; apps register concrete logic at runtime.

## Registries

- ``PredicateRegistry``: Register visibility/eligibility checks. Signature: `@Sendable (State, [String: String]) -> Bool`.
- ``EffectRegistry``: Register state mutations. Signature: `@Sendable (inout State, [String: String]) -> Void`.
- ``ActionRegistry``: Register richer interactions that can throw and return an ``ActionOutcome``. Signature: `@Sendable (inout State, [String: String]) throws -> ActionOutcome`.

Parameters are `String`‑keyed for portability; you can adopt your own encoding/decoding and look up values by convention.

## State

Define a type conforming to ``StoryState`` to represent your game’s state. Keep it `Codable` and `Sendable` to work well with autosave and concurrency.

## Determinism

For deterministic tests, avoid randomness in registry closures or route any randomness through state so tests can substitute deterministic values.

## Encounters and Global Actions

- Declare who/what is present using data‑only fields in content: top‑level `entities` and per‑node `actors`. These carry identifiers, labels, and tags — not mechanics.
- Drive multi‑step encounters entirely in your client using registered actions that mutate your ``StoryState``. The engine can remain on the same node between turns.
- When an out‑of‑band outcome should transition regardless of the current node (e.g., “player died”), declare a `globals.globalActions` entry in content and call `StoryEngine.performGlobalAction(id:)` to jump to its destination (on‑enter effects and autosave apply).
