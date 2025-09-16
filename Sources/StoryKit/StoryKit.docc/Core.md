# Core

Understand StoryKit’s core data model and identifiers.

## Overview

The Core module defines the schema for stories and the foundational types used across the package. It is deliberately small and `Sendable` to support safe use with Swift Concurrency.

### Identifiers

- ``Core/NodeID``: Strongly‑typed identifier for nodes.
- ``Core/ChoiceID``: Strongly‑typed identifier for choices.

Both wrap `String` and conform to `Codable`, `Hashable`, and `Sendable`.

### Content References

- ``Core/TextRef``: Points to the prose for a node via `file` (Markdown filename) and `section` (a labeled region within the file).

### Story Graph

- ``Core/Choice``: A labeled edge from one node to another with optional predicates and effects.
- ``Core/Node``: A story node with text reference, optional tags, on‑enter effects, and a list of choices.
- ``Core/Story``: Aggregates metadata, the `start` node, and the `nodes` map.

``Core/Story`` encodes/decodes its `nodes` as a string‑keyed dictionary for authoring convenience while presenting a `[NodeID: Node]` API within Swift.

### Extensibility Descriptors

- ``Core/PredicateDescriptor`` and ``Core/EffectDescriptor``: Data‑only descriptors with an `id` and string parameters, used to bind to runtime logic registered by the host app.

### Registries and State

- ``Core/StoryState``: Protocol for app‑defined, `Codable` and `Sendable` story state. Must include a `currentNode`.
- ``Core/PredicateRegistry``: Maps predicate ids to `@Sendable` evaluation closures.
- ``Core/EffectRegistry``: Maps effect ids to `@Sendable` mutation closures.
- ``Core/ActionRegistry``: Maps action ids to `@Sendable` closures that can throw and return an ``Core/ActionOutcome``.
- ``Core/ActionOutcome``: Indicates action completion or requests host interaction.

All registries are value types and store `@Sendable` closures to be safe across concurrency domains.

