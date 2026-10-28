---
description: Build the Remaster app for the iOS Simulator and report errors
---
Build the app. Inside Xcode, use the `BuildProject` tool (then `GetBuildLog` for details). Otherwise, run `xcodebuild -project ios/Remaster.xcodeproj -scheme Remaster -destination 'generic/platform=iOS Simulator' build -quiet` from the repo root. If it fails, list each error with `file:line` and explain what's causing it and which direction to take, in prose only. Don't edit code or show code (see the ground rule in AGENTS.md). If it succeeds, say so in one line.
