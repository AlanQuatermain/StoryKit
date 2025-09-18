# Validation

Catch issues early with structural and content checks.

## Overview

The validator analyzes your story graph and referenced text to detect common problems before runtime.

## Key Types

- ``StoryValidator``: Runs validations and returns a list of issues.
- ``StoryIssue``: Describes a single issue with a `kind`, human‑readable `message`, and `severity` (error or warning).

## Structural Checks

- Missing start node
- Missing choice destinations
- Unreachable nodes from the start
- Duplicate choice IDs per node
- Node dictionary key/id mismatches (data hygiene)
- Duplicate actor IDs per node
- Unknown entity ids referenced by node actors
- Global actions pointing to missing destination nodes

## Flow Checks

- Nodes with empty choices (warning). Suppressed when a node is explicitly marked `terminal: true` (e.g., ending nodes).
- Cycles with no exits (warning)

## Content Checks

- Missing text sections referenced by nodes
- Orphan text sections present in Markdown
- Orphan Markdown files with no references

## Using the CLI

The CLI provides `storykit validate <path>` with `--format text|json`. JSON output includes aggregated counts and issue details, and exits non‑zero only when errors are present.

Tip: Mark ending nodes with `"terminal": true` in `story.json` to indicate that the node intentionally has no outgoing choices. The validator will not emit the “Node has no choices” warning for terminal nodes.
