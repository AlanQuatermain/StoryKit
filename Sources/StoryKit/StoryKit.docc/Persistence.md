# Persistence

Save and load story state with pluggable backends.

## Overview

The Persistence module defines protocols and default implementations for saving snapshots of your story state.

## Key Types

- ``SaveProvider``: Protocol for asynchronous save/load/list operations.
- ``StorySave``: Codable container that wraps `storyID`, your state, and a timestamp.
- ``InMemorySaveProvider``: Lightweight in‑process backend for tests and previews.
- ``JSONFileSaveProvider``: Writes snapshots to JSON files in a directory.

## Autosave Integration

Use ``makeAutoSaveHandler(storyID:slot:provider:)`` to create a closure you can pass to ``StoryEngine``’s initializer. The engine calls this after transitions and actions.

## Slots

Backends support multiple slots (e.g., `autosave`, `slot1`), enabling per‑profile or per‑checkpoint saving.
