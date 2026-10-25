# AGENTS.md — Remaster

> Working name: TBD (candidates discussed: Double Dip, Remaster, Shelf Life, Next Pressing, Spine). The repo and Xcode project are named **Remaster**.
> Status: proof of concept (barcode scan → UPCMDB lookup → raw JSON on screen, running on iPhone).

This file is the shared context for agents working in this repo: how to build and work in the code, and the product context for planning and building the app. Items in the product context are labelled **Decided** (the product owner has committed to them) or **Proposed** (suggested, not yet confirmed). Treat Proposed items as defaults that may change, and flag any story or change that depends on one.

---

## Ground rule: agents never write code

The owner writes all of the app's code by hand. This rule overrides any other instruction, skill, or command.

- **Never write, generate, or edit code.** This covers Swift, TypeScript, and any other source, project files (`project.pbxproj`, entitlements, Info.plist, `package.json`, `tsconfig.json`, `nest-cli.json`), build settings, and tests. Don't run code generators either (`nest new`, `nest generate`, …). Don't use `Edit`/`Write` or the Xcode write tools (`XcodeWrite`, `XcodeUpdate`, `XcodeInsertFile`, `AddEntitlement`, `AddInfoPlist`, `RunCodeSnippet`, …) on code.
- **Never give code snippets,** including one-liners, pseudo-code that's really Swift, "here's roughly what it looks like" examples, and diffs.
- **When asked for help, point the way.** Explain the concept, name the relevant API, type, or modifier, link Apple's documentation, ask a guiding question, or describe the steps in prose. Name the file and line to look at instead of showing the change.
- **Reviews are welcome, but say what's wrong without writing the fix.** Reviewing code and PRs is in scope. Describe each problem (`file:line`, what's wrong, why, and which direction to fix it in) without writing the fixed code.
- **Everything around the code is in scope:** stories and acceptance criteria, Jira, designs and mockups, documentation (including this file), agent config, research, builds, and reading code and build logs to diagnose problems.

If a request would need code written, say so and offer guidance instead.

## Working in this repo

Monorepo with two projects:

- `ios/` — SwiftUI iOS app (iOS 27 deployment target, Swift 5 language mode)
- `backend/` — NestJS v12 API, hosted on Railway (not scaffolded yet)

Agent config (`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.mcp.json`) and `.gitignore` live at the repo root.

### iOS layout
- `ios/Remaster.xcodeproj` — Xcode project; single target / scheme: `Remaster`
- `ios/Remaster/RemasterApp.swift` — app entry point
- `ios/Remaster/ContentView.swift` — main screen
- `ios/Remaster/ContentViewModel.swift` — `@Observable` view model; barcode lookup over `URLSession` + Combine
- `ios/Remaster/BarcodeScanner.swift` — camera barcode scanner
- `ios/Config/` — xcconfig files and the partial Info.plist (see Secrets)

### iOS build
From the repo root:
```sh
xcodebuild -project ios/Remaster.xcodeproj -scheme Remaster -destination 'generic/platform=iOS Simulator' build
```
There is no test target yet.

### iOS conventions
- Use the Observation framework (`@Observable`, `@ObservationIgnored`) rather than `ObservableObject`.
- Keep new source files in `ios/Remaster/`. The project uses synchronized folders, so new files there are picked up automatically; no `project.pbxproj` edit needed. Don't put `Info.plist` or `.xcconfig` files in `ios/Remaster/` (they'd be copied into the bundle as resources).

### Backend
- NestJS v12 in `backend/`; the owner scaffolds it with the Nest CLI. See `backend/README.md` and section 3.
- Railway deploys it with the service root directory set to `backend/`.
- Third-party keys live in Railway service variables; locally in `backend/.env` (gitignored). Never commit them.

### Agent config
- `CLAUDE.md` (which imports this file) and `.claude/` (`settings.json`, `commands/`) are shared by Claude Code in the terminal and the Claude agent inside Xcode. Both run from the repo root.
- Xcode's agent keeps its user-level config in `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/`, not `~/.claude/`. Anything that should apply in both places belongs in the repo.
- Inside Xcode, prefer the `mcp__xcode-tools__*` tools (`BuildProject`, `XcodeRead`, etc.) over shell `xcodebuild`.

### Secrets
- iOS API keys go in `ios/Config/Secrets.xcconfig` (gitignored; template in `ios/Config/Secrets.example.xcconfig`), included by `ios/Config/Remaster.xcconfig`.
- They reach code via `ios/Config/Info.plist` (merged with the generated Info.plist) and `Bundle.main.object(forInfoDictionaryKey:)`. Never hardcode keys in Swift.
- **Known PoC gap:** the app currently calls UPCMDB directly, so the UPCMDB key ships inside the app binary. The target architecture (section 3) routes lookups through the backend, which holds third-party keys; App Attest protects the backend.

---

## 1. What the app is

An app that helps physical-media collectors manage and upgrade their movie and TV disc libraries.

- The user scans the barcode on a DVD / Blu-ray / 4K UHD case (or searches a title manually).
- The app identifies the release and saves it to the user's library.
- The app tells the user whether a better version exists: Blu-ray, 4K UHD, a Dolby Vision or HDR10+ release, or a steelbook / premium edition.
- The app alerts the user when new editions of titles they own or watch are announced.
- It also works as a general inventory app for a movie and TV collection.

### Target user

- **Segment:** Physical-media collectors upgrading DVD/Blu-ray libraries to 4K, HDR, and premium editions.
- **Persona:** A collector with a few hundred discs who wants the best version of what they own and cares about HDR format and packaging (steelbooks), without creating an account or putting their collection in someone's cloud.
- **Narrative:** "Know what I own, find out when a better version exists, and upgrade before it sells out."

### Why it's different

Existing apps (CLZ Movies, iCollect Movies, Disc Bin, Slipcover, Libib) are inventory-first and account/cloud-based. Disc Bin is the closest: it tracks HDR format and has a want list with preferred formats, but it is account-based and does not proactively detect upgrades. This app's differentiators:

1. **Automatic upgrade detection** (DVD → Blu-ray → 4K → DV/HDR10+, plus steelbooks) as the core feature, not a manual wishlist.
2. **No account; library stays on the device.**
3. **HDR format and packaging treated as first-class upgrade targets.**

---

## 2. Privacy model

**Decided**
- The user's library is stored locally on the device. No account is required.
- The backend accepts anonymous requests from any client. Requests carry no user or device identifier.
- The server does not group or correlate requests from the same client.
- The server drops client IP addresses and does not read or log them.

**Proposed**
- Ensure the whole hosting stack (load balancer, CDN, host) also has IP/path logging disabled, so the no-logging promise holds end to end. On Railway this means confirming what its built-in HTTP request logs record and whether they can be turned off (RMSTR-10).
- Privacy policy wording: "We don't collect or store what you look up." (A trust-based guarantee; the server could in principle see lookups but is built not to.)
- Optional future upgrade to a structural guarantee: clients download a shared "changes since version X" catalog feed and match locally, so recurring checks never send title IDs.
- Use Apple App Attest (and Play Integrity on Android, if built) so the server can verify requests come from a genuine app without identifying the user, and to prevent scraping of the edition database through the API.
- Multi-device sync via SwiftData/Core Data + CloudKit **private** database (data lives in the user's iCloud, unreadable by the developer).

Any story that sends data off the device must state what is sent and confirm it contains no library contents or identifiers.

---

## 3. Architecture

```
[iOS app]  ── anonymous, attested requests ──▶  [Backend API]
  • barcode scanner / manual search                  • UPC + title lookup
  • local library store (on device)                  • normalization layer
  • local upgrade matching                            • edition database (own schema)
  • local notifications                               • enrichment worker (background)
        ▲                                             • new-editions feed publisher
        └──── new-editions feed (same for all users) ◀┘
```

### Client (iOS app)
- **Decided:** Barcode scan or manual title search; library stored on device; no account.
- **Proposed:** All personal matching (library vs. available editions, alert rules) happens on device. Notifications are local notifications, triggered after the app pulls new data.

### Backend
- **Decided:** Written in **NestJS v12** and hosted on **Railway** (RMSTR-55). Third-party API keys live in Railway service variables, never in the repo. The datastore is not chosen yet.
- **Decided:** A hosted service that queries TMDB, a UPC lookup service (UPCMDB), and possibly scrapes Blu-ray.com. The edition database is filled **on demand** over time rather than enumerated up front; it will later be crowdsourced. The server runs in the background filling in upgrade data, and clients receive it as it comes in.
- **Proposed:**
  - **Normalization on the server.** Raw source responses are mapped into the app's own edition schema once, server-side. Clients only ever see the normalized schema. Keep the raw JSON alongside each normalized record so it can be reprocessed when mapping improves.
  - **Cache-style lookup.** First scan of a UPC triggers resolution and stores the result; later scans are instant hits.
  - **Fast path on a miss.** Return the basic match (title, poster, scanned format) immediately; fetch upgrade editions in the background and update when ready.
  - **Seed before launch.** Pre-populate editions for the most popular few thousand titles (TMDB popularity lists) so early users mostly hit cache.
  - **Log every lookup outcome**, including unresolved UPCs ("wanted" list) and records missing key fields (`hdr`, `format`). This log drives the enrichment worker and crowdsourcing priorities.
  - **Enrichment worker** re-checks titles periodically (sooner for frequently scanned titles) and watches release listings for new 4K / DV / steelbook announcements, limited to titles already in the database.
  - **New-editions feed:** one shared feed of newly announced editions. Devices download it (background refresh, plus a silent push sent to all devices when the feed updates) and match locally.

---

## 4. Data sources

| Source | Used for | Notes |
|---|---|---|
| **TMDB** | Canonical movie/show identity (TMDB ID), posters, metadata, manual search, popularity lists for seeding | Free API. No disc-edition or HDR data. |
| **UPCMDB** (upcmdb.com) | UPC → physical release lookup | REST API for DVD / Blu-ray / 4K. Returns IMDb IDs, so map to TMDB with `/find/{imdb_id}?external_source=imdb_id`. Used in the current PoC. |
| **Blu-ray.com** | Richest edition data: HDR format, steelbooks, region, distributor, release dates | No public API. Scraping may violate terms of service, risks IP blocks, and breaks when HTML changes. Proposed: ask about a data license first; if scraping, do it centrally with aggressive caching. Third-party paid wrappers exist. |
| **FlatpanelsHD UHD database** | 4K titles with HDR format and 4K vs. 2K digital intermediate | Strong seed for the 4K/HDR upgrade layer. Ask permission before use. |
| **TheDiscDB** | Cross-reference only | Open, community-run, ripper-oriented (disc hashes, track layouts), not retail editions. Treat as a possible partner, not an automated source. |
| **Crowdsourcing** (later) | Filling gaps, corrections | See section 6. |

### Observed UPCMDB quirks (from the PoC)

Raw UPCMDB records do not share a consistent schema; fields vary record by record (it appears to merge different upstream sources). Seen so far:

- Booleans arrive as both real booleans (`"steelbook": true`) and strings (`"collectors_edition": "true"`, `"limited_edition": "null"`).
- Format values are inconsistent (`"UHD4K"` vs. `"4KUHD"`).
- Some records have no `hdr` field at all; others have `"hdr": "Dolby Vision, HDR10"` as a comma-separated string.
- Numbers and dates are strings (`"runtime": "279"`, `"releaseDate": "Dec 03, 2024"`).
- Misspelled keys exist (`metacriciUrl`).
- Some records are rich (audio, discs, packaging, region, codec); others are thin retail listings.

Example records scanned in the PoC: *WandaVision: The Complete Series* 4K collector's edition (thin record, no HDR field), *Hawkeye: The Complete First Season* 4K steelbook (rich record with Dolby Vision, HDR10, packaging, region free).

Decode defensively, key decoding off real responses rather than docs, and log any response that fails to decode.

---

## 5. Data model

**Proposed:** Model editions, not just titles. Upgrades happen at the edition level (e.g., a 2017 4K in HDR10 only vs. a 2024 remaster with Dolby Vision vs. a steelbook).

```
Title (keyed by TMDB ID; movie or TV)
 └── Edition
      ├── upc / ean (one or more)
      ├── format: DVD | Blu-ray | 4K UHD          (enum, normalized)
      ├── hdr: [HDR10, HDR10+, Dolby Vision]      (set, may be unknown)
      ├── packaging: standard | steelbook | slipcover | collector's box | ...
      ├── disc contents (e.g., 4K + Blu-ray combo)
      ├── distributor, region, retailer exclusive
      ├── release date, announced/preorder status
      ├── audio, video specs (optional)
      └── provenance per field: source + last checked date
```

On-device library entries reference an Edition (or a Title + format when the exact edition is unknown).

**Upgrade check (on device):** for each owned title, compare the owned edition against available editions and flag anything with a higher format, a better HDR type, or (if the user wants it) premium packaging.

### Open modelling questions
- **Combo packs:** a 4K + Blu-ray set means the user owns both formats; upgrade logic must account for this.
- **TV:** complete-series box sets vs. individual seasons (WandaVision was a complete series, Hawkeye a single season).
- **Unknown HDR:** how to present an edition whose HDR type is not yet known.
- **Region:** avoid alerting users about region-locked or overseas-exclusive releases they can't easily buy.

---

## 6. Crowdsourcing (later release)

**Decided:** After initial data collection, future information can be crowdsourced.

**Proposed:**
- The natural trigger is a failed scan: when a UPC doesn't resolve, ask the user to confirm title, format, and packaging, and submit the mapping.
- Submissions are opt-in and anonymous and contain only UPC + edition facts, never anything about the user's library.
- An edit is accepted only after several independent submissions agree.
- Users can report wrong data.

---

## 7. Alerts

**Decided:** Alerts when new editions come out, including steelbook availability.

**Proposed:**
- Users can keep an on-device **watchlist** of titles they don't own yet.
- Alert filters: only 4K, only Dolby Vision, only steelbooks, only my region.
- Steelbooks sell out fast (often retailer-exclusive, region-locked), so they need more frequent scraping and prompt delivery. iOS background refresh is unreliable for this; a silent push to all devices when the feed updates wakes the app promptly without revealing anything.
- Later: price-drop alerts via on-device polling.

---

## 8. Release plan (from the user story map)

The story map backbone (user activities, left to right): **Catalog my collection → Find upgrades → Decide and upgrade → Track new releases → Keep my data right.** ⚙ = server / behind-the-scenes task.

### MVP — scan, catalog, see upgrades

| Activity | Step | Tasks |
|---|---|---|
| Catalog my collection | Scan a disc | Scan barcode with camera · ⚙ Look up UPC via UPCMDB, normalize & cache · Confirm match and save to library |
| | Add without a barcode | Search title manually (TMDB) · Pick the format I own |
| | Browse my library | Grid of posters, stored on device · Filter by format (DVD / BD / 4K) |
| Find upgrades | See what's better | Upgrade badge when a higher format exists · ⚙ Seed editions for popular titles |
| | Review my upgrade list | List of every upgradeable title |
| Decide and upgrade | Record the upgrade | Replace owned edition with the new one |
| Keep my data right | Handle a failed scan | Fall back to manual search · ⚙ Log unresolved UPCs |

### Release 2 — editions, alerts, contributions

| Activity | Step | Tasks |
|---|---|---|
| Catalog my collection | Scan a disc | Batch scan mode for a whole shelf |
| | Add without a barcode | Pick the exact edition (steelbook, collector's) |
| | Browse my library | Search & sort; group TV seasons · Collection stats |
| Find upgrades | See what's better | Show HDR type (Dolby Vision / HDR10+) · Show steelbook availability |
| | Review my upgrade list | Filter by upgrade type (4K, DV, steelbook) |
| Decide and upgrade | Compare editions | Edition detail: discs, audio, HDR, packaging |
| | Buy the upgrade | Link out to retailer |
| | Record the upgrade | Mark old copy kept / sold / donated |
| Track new releases | Build a watchlist | Add titles I don't own yet |
| | Set alert preferences | Choose alert types (4K, DV, steelbook) · Set my region |
| | Get notified | ⚙ Publish new-editions feed · On-device match + local notification |
| Keep my data right | Handle a failed scan | Submit UPC → edition anonymously (opt-in) |
| | Protect my library | Export / back up library (JSON) |

### Future — nice to have

| Activity | Step | Tasks |
|---|---|---|
| Catalog my collection | Scan a disc | Identify disc from cover photo |
| | Add without a barcode | Import from CLZ / other apps (CSV) |
| | Browse my library | Shelf / location tags |
| Find upgrades | See what's better | Filter by my region · Flag native 4K vs. 2K upscale |
| | Review my upgrade list | Rank by how big the upgrade is |
| Decide and upgrade | Compare editions | Current prices across retailers |
| | Buy the upgrade | Price-drop alerts |
| Track new releases | Get notified | ⚙ Silent push for preorders & sell-outs |
| Keep my data right | Handle a failed scan | Report wrong data · ⚙ Accept edits when submissions agree |
| | Protect my library | iCloud sync via CloudKit private DB |

### Known gaps to consider
- **First-run experience** with an empty library; batch scan may belong in MVP so a first session of scanning a shelf feels fast.
- **Combo packs** and **TV box sets vs. seasons** (see section 5).

---

## 9. Guidance for writing stories

- Write stories from the collector's point of view: *As a collector, I want …, so that …*
- Each story gets testable acceptance criteria (Given / When / Then is fine).
- Tag each story with its **release** (MVP / R2 / Future), its **activity** and **step** from the map, and whether it is **client**, **server**, or both.
- Split server work (⚙) into its own stories or sub-tasks rather than hiding it inside a UI story.
- For any story that sends data off the device, include an acceptance criterion confirming no library contents or identifiers are sent and nothing is logged.
- Where a story depends on a **Proposed** decision, say so in the story so it can be revisited.
- Prefer thin vertical slices that deliver something usable end to end.

---

## 10. Glossary

- **Double dip:** collector slang for buying a movie you already own again in a better edition.
- **4K UHD:** Ultra HD Blu-ray disc format (2160p).
- **HDR10 / HDR10+ / Dolby Vision (DV):** high-dynamic-range formats. HDR10 is the baseline; HDR10+ and Dolby Vision add dynamic metadata and are common upgrade targets.
- **Digital intermediate (DI):** the master a release is made from. A "2K DI" 4K disc is upscaled; a "4K DI" is native 4K.
- **Steelbook:** metal case premium packaging, often limited and retailer-exclusive.
- **Combo pack:** a release containing multiple formats (e.g., 4K + Blu-ray).
- **Edition:** a specific release of a title (format + HDR + packaging + distributor + region), identified by UPC.
- **UPC / EAN:** retail barcode numbers on the case.
