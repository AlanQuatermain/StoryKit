# Content I/O

Load, compile, and serve story content and text.

## Overview

The ContentIO module handles authoring and runtime content formats, text parsing, and compiled bundle manifests.

## Layouts and Loaders

- ``ContentIO/StorySourceLayout``: Describes a source folder with `story.json` and `texts/`.
- ``ContentIO/StoryBundleLayout``: Describes a compiled `.storybundle` directory.
- ``ContentIO/StoryLoader``: Loads a ``Core/Story`` from a `story.json` file.
- ``ContentIO/StoryBundleLoader``: Loads a ``Core/Story`` from a bundle’s `graph.json`.

## Compiler and Manifest

- ``ContentIO/StoryCompiler``: Compiles a source folder into a bundle.
- ``ContentIO/StoryBundleManifest``: Records schema version, story metadata, build time, and the SHA‑256 hash of `graph.json`.

## Markdown Text

- ``ContentIO/TextSectionParser``: Splits Markdown files into named sections using lines of the form `=== node: <section-id> ===`.

### Text Providers

- ``ContentIO/SourceTextProvider`` and ``ContentIO/BundleTextProvider``: Minimal providers that parse a file on each request.
- ``ContentIO/CachedSourceTextProvider`` and ``ContentIO/CachedBundleTextProvider``: Actor‑based providers with LRU caches and memory‑pressure purging.

Both cached providers accept a `maxBytes` budget and evict least‑recently‑used files when the cache exceeds this size. Memory pressure notifications trigger a full purge.

## Errors

- ``ContentIO/StoryIOError``: Throws when a requested text section is missing.

