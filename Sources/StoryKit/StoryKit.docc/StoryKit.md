# StoryKit

Build rich, data‑driven “choose your own adventure” experiences with a small, composable core and first‑class tooling.

## Overview

StoryKit is a Swift package that models interactive stories as graphs of nodes and choices, executes story flow with deterministic, testable state, and provides utilities to author, validate, and package content.

The package is organized into focused modules:

- ``Core``: Data model, identifiers, and extensibility registries.
- ``Engine``: The actor‑based story runtime.
- ``Persistence``: Save/Load protocols and default implementations.
- ``ContentIO``: Loaders, compilers, manifests, and text providers.
- ``StoryKit`` (umbrella): Re‑exports the other modules for convenience.

Author your story as a structure file (JSON) and Markdown text with lightweight section delimiters. Compile to a directory‑based story bundle layout for distribution.

## Topics

### Architecture

- <doc:Core>
- <doc:Engine>
- <doc:Persistence>
- <doc:ContentIO>

### Validation and Quality

- <doc:Validation>

### Extensibility

- <doc:Extensibility>

### CLI and Workflows

- <doc:CLI>
