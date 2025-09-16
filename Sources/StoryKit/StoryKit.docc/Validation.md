# Validation

Catch issues early with structural and content checks.

## Overview

The validator analyzes your story graph and referenced text to detect common problems before runtime.

## Key Types

- ``ContentIO/StoryValidator``: Runs validations and returns a list of issues.
- ``ContentIO/StoryIssue``: Describes a single issue with a `kind`, human‑readable `message`, and `severity` (error or warning).

## Structural Checks

- Missing start node
- Missing choice destinations
- Unreachable nodes from the start
- Duplicate choice IDs per node
- Node dictionary key/id mismatches (data hygiene)

## Flow Checks

- Nodes with empty choices (warning)
- Cycles with no exits (warning)

## Content Checks

- Missing text sections referenced by nodes
- Orphan text sections present in Markdown
- Orphan Markdown files with no references

## Using the CLI

The CLI provides `storykit validate <path>` with `--format text|json`. JSON output includes aggregated counts and issue details, and exits non‑zero only when errors are present.

