# ``StoryKit``

@Metadata {
  @TechnologyRoot
  @Title("StoryKit")
  @Abstract("An extensible engine and toolchain for building choose-your-own-adventure style interactive stories.")
}

Build rich, data‑driven “choose your own adventure” experiences with a small, composable core and first‑class tooling.

## Overview

StoryKit is a small, composable toolkit for building data‑driven “choose your own adventure” experiences. It models stories as graphs of nodes and choices, provides an actor‑based engine to run the flow, and includes tools to author, validate, and package content.

All public APIs are accessed from the single `StoryKit` module. You can work with the story graph types (``Story``, ``Node``, ``Choice``), drive progression using ``StoryEngine``, save and load state with ``SaveProvider`` implementations, and load/compile content with types like ``StoryLoader`` and ``StoryCompiler``.

Author your story using a `story.json` graph and Markdown prose with lightweight section delimiters, then compile to a directory‑based ``StoryBundleLayout`` for distribution.

## Topics

### Authoring & Formats
- <doc:DataFormats>

### Validation
- <doc:Validation>

### Extensibility
- <doc:Extensibility>

### Encounters
- <doc:Encounters>

### CLI
- <doc:CLI>
