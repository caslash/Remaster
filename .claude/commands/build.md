---
description: Build the Remaster app for the iOS Simulator and report errors
---
Run `xcodebuild -scheme Remaster -destination 'generic/platform=iOS Simulator' build -quiet` from the project root. If it fails, summarize each error with `file:line` and propose fixes. If it succeeds, say so in one line.
