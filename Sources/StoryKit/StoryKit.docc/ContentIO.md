# Content I/O

Load, compile, and serve story content and text.

## Overview

StoryKit handles authoring and runtime content formats, text parsing, and compiled bundle manifests.

## Layouts and Loaders

- ``StorySourceLayout``: Describes a source folder with `story.json` and `texts/`.
- ``StoryBundleLayout``: Describes a compiled `.storybundle` directory.
- ``StoryLoader``: Loads a ``Story`` from a `story.json` file.
- ``StoryBundleLoader``: Loads a ``Story`` from a bundle’s `graph.json`.

## Compiler and Manifest

- ``StoryCompiler``: Compiles a source folder into a bundle.
- ``StoryBundleManifest``: Records schema version, story metadata, build time, and the SHA‑256 hash of `graph.json`.

## Markdown Text

- ``TextSectionParser``: Splits Markdown files into named sections using lines of the form `=== node: <section-id> ===`.

### Text Providers

- ``SourceTextProvider`` and ``BundleTextProvider``: Minimal providers that parse a file on each request.
- ``CachedSourceTextProvider`` and ``CachedBundleTextProvider``: Actor‑based providers with LRU caches and memory‑pressure purging.

Both cached providers accept a `maxBytes` budget and evict least‑recently‑used files when the cache exceeds this size. Memory pressure notifications trigger a full purge.

## Errors

- ``StoryIOError``: Throws when a requested text section is missing.
