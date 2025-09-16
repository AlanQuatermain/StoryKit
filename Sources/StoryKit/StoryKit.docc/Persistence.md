# Persistence

Save and load story state with pluggable backends.

## Overview

The Persistence module defines protocols and default implementations for saving snapshots of your story state.

## Key Types

- ``Persistence/SaveProvider``: Protocol for asynchronous save/load/list operations.
- ``Persistence/StorySave``: Codable container that wraps `storyID`, your state, and a timestamp.
- ``Persistence/InMemorySaveProvider``: Lightweight in‑process backend for tests and previews.
- ``Persistence/JSONFileSaveProvider``: Writes snapshots to JSON files in a directory.

## Autosave Integration

Use ``Persistence/makeAutoSaveHandler(storyID:slot:provider:)`` to create a closure you can pass to ``Engine/StoryEngine``’s initializer. The engine calls this after transitions and actions.

## Slots

Backends support multiple slots (e.g., `autosave`, `slot1`), enabling per‑profile or per‑checkpoint saving.

