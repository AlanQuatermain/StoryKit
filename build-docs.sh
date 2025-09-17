#!/bin/bash
set -euo pipefail

# Clean out any old build artifacts
rm -rf .derivedData docs

# Build the .doccarchive using xcodebuild
xcodebuild docbuild \
  -scheme StoryKit \
  -destination 'generic/platform=macOS' \
  -derivedDataPath .derivedData

# Locate the generated .doccarchive
DOC_ARCHIVE=$(find .derivedData -name "StoryKit.doccarchive" -type d | head -n 1)

if [ -z "$DOC_ARCHIVE" ]; then
  echo "Error: No .doccarchive found"
  exit 1
fi

echo "Found doccarchive at: $DOC_ARCHIVE"

# Transform it for static hosting (generates index.html etc.)
mkdir -p docs
xcrun docc process-archive transform-for-static-hosting \
  "$DOC_ARCHIVE" \
  --output-path docs \
  --hosting-base-path storykit

echo "✅ Documentation built at ./docs/"
echo "You can preview it by opening ./docs/index.html in a browser."
