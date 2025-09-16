# Extensibility

Customize logic with predicates, effects, and actions.

## Overview

StoryKit separates data from behavior. Authors reference symbolic ids in content; apps register concrete logic at runtime.

## Registries

- ``Core/PredicateRegistry``: Register visibility/eligibility checks. Signature: `@Sendable (State, [String: String]) -> Bool`.
- ``Core/EffectRegistry``: Register state mutations. Signature: `@Sendable (inout State, [String: String]) -> Void`.
- ``Core/ActionRegistry``: Register richer interactions that can throw and return an ``Core/ActionOutcome``. Signature: `@Sendable (inout State, [String: String]) throws -> ActionOutcome`.

Parameters are `String`‑keyed for portability; you can adopt your own encoding/decoding and look up values by convention.

## State

Define a type conforming to ``Core/StoryState`` to represent your game’s state. Keep it `Codable` and `Sendable` to work well with autosave and concurrency.

## Determinism

For deterministic tests, avoid randomness in registry closures or route any randomness through state so tests can substitute deterministic values.

