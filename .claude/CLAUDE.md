# Remaster

SwiftUI iOS app (iOS 27 deployment target, Swift 5 language mode) that scans a movie barcode and looks it up via the upcmdb API.

## Layout
- `Remaster/RemasterApp.swift` — app entry point
- `Remaster/ContentView.swift` — main screen
- `Remaster/ContentViewModel.swift` — `@Observable` view model; barcode lookup over `URLSession` + Combine
- `Remaster/BarcodeScanner.swift` — camera barcode scanner
- Single target / scheme: `Remaster`

## Build
```sh
xcodebuild -scheme Remaster -destination 'generic/platform=iOS Simulator' build
```
There is no test target yet.

## Conventions
- Use the Observation framework (`@Observable`, `@ObservationIgnored`) rather than `ObservableObject`.
- Keep new source files in `Remaster/`. The project uses synchronized folders, so new files there are picked up automatically; no `project.pbxproj` edit needed.

## Secrets
- API keys go in `Config/Secrets.xcconfig` (gitignored; template in `Config/Secrets.example.xcconfig`), included by `Config/Remaster.xcconfig`.
- They reach code via `Config/Info.plist` (merged with the generated Info.plist) and `Bundle.main.object(forInfoDictionaryKey:)`. Never hardcode keys in Swift.
