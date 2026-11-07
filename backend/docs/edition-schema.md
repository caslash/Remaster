# Edition schema (client contract)

The normalized shape the backend returns for a disc edition, and the rules for mapping UPCMDB responses into it (RMSTR-8). The iOS client (RMSTR-11) decodes against this document.

Source of truth for the type: [`src/upc/types/edition.ts`](../src/upc/types/edition.ts). If this document and the type disagree, fix whichever is wrong in the same change.

## Conventions

- **Absent means unknown.** A field the source doesn't tell us about is left out of the JSON. Clients decode it as optional (`nil` in Swift). The server never invents a value to fill a gap.
- **Empty is not absent.** An empty list is a known answer. The important case is `hdr`: an empty list means the disc is SDR, and an absent `hdr` means we don't know.
- **True / false / unknown.** Every boolean in `packaging` and `editionFlags`, plus `hasDigital`, has three states: `true`, `false`, or absent.
- **Why the type says `| undefined` and not `?:`.** It forces the mapper to set every key explicitly, so a forgotten field is a compile error instead of a silently missing key. It serializes the same way (undefined keys are dropped from the JSON). Don't convert these to optional properties.
- **Canonical values only.** Enum values are the backend's own spellings (`4K UHD`, `Blu-ray`, `Dolby Vision`), never the source's (`4KUHD`, `BLURAY`). An unrecognised source value is left out and logged, never guessed.
- **Dates are calendar dates.** `releaseDate` is a date-only ISO 8601 string (`YYYY-MM-DD`). Clients decode it as a calendar date, not a point in time, so it shows the same day in every time zone.

## Fields

### Identity

| Field          | Type                   | Notes                                                                                                                                                                       |
| -------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`           | string, always present | Canonical GTIN-13 of the requested code, so `043396647640` and `0043396647640` are the same edition. See [`upc-endpoint.md`](upc-endpoint.md) for how codes are normalized. |
| `barcodes.upc` | string or absent       | As printed on the case (12 digits).                                                                                                                                         |
| `barcodes.ean` | string or absent       | 13 digits.                                                                                                                                                                  |
| `asin`         | string or absent       | Amazon product ID, for retailer links (R2).                                                                                                                                 |
| `imdbId`       | string or absent       | The only title key until TMDB mapping (RMSTR-13). Missing on some records (Loki S2, SpongeBob).                                                                             |

### Title

| Field           | Type                       | Notes                                                                                                   |
| --------------- | -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `title`         | string, always present     | Retail title as printed, e.g. "Loki: The Complete Second Season".                                       |
| `enrichedTitle` | string or absent           | Name of the work, e.g. "WandaVision".                                                                   |
| `kind`          | `movie` \| `tv`, or absent | Absent when the record has no type signal (Loki S2). Not guessed from the title. Matches TMDB's naming. |
| `year`          | integer or absent          | Year of the work, not the disc release.                                                                 |

#### Planned: nested title (RMSTR-13, decided 2026-11-01)

Not implemented yet. Clients shouldn't rely on it until this marker is removed.

The edition and the work it's a release of are split, matching the Title and Edition tables in PostgreSQL:

- **Retail title renamed.** `title` (the retail title as printed) becomes `upcTitle`. This is a **breaking change** for the iOS `Edition` decoder, which reads `title` as a string.
- **`title` becomes an object** describing the work, filled from TMDB via the edition's IMDb ID (`/find/{imdb_id}?external_source=imdb_id`). It's absent when the edition has no IMDb ID or TMDB has no match.
- **Fields of the nested `title`:** kind (`movie` | `tv`, from which TMDB result list matched), TMDB ID, name, year (from `release_date` or `first_air_date`), IMDb ID, and poster URL.
- **TMDB IDs are only unique per kind** (movie 1399 and TV 1399 are different works), so a Title is identified by kind + TMDB ID. Clients should compare both.
- **Poster URL is built at response time.** The database stores TMDB's `poster_path`; the base URL and size are applied when the response is built, so a later change (e.g. a backend image proxy, RMSTR-62) needs no data migration.
- **TV editions link to the show**, not a season: Loki S2's title is "Loki". The season or scope appears only in `upcTitle` for now (see AGENTS.md §5, TV).

#### TMDB matching (RMSTR-67)

`TMDBService.getTitle(imdbId, kind)` in [`src/upc/tmdb.service.ts`](../src/upc/tmdb.service.ts) turns an edition's IMDb ID into a Title. The `/upc` lookup calls it on a cache miss when the edition has an IMDb ID, before anything is saved (RMSTR-68; see [Lookup flow](upc-endpoint.md#lookup-flow-rmstr-68)). A match is saved to the `titles` table and linked to the edition in the same transaction. No IMDb ID, or no match, saves the edition with no title.

**Request.** `GET {TMDB_FIND_URL}{imdbId}?external_source=imdb_id` with `Authorization: Bearer {TMDB_READ_ACCESS_TOKEN}` and a 5-second timeout, which covers reading the body as well as the headers. Only the IMDb ID and the server's token are sent.

**Outcomes.** These three stay separate so the caller can tell "TMDB doesn't know this work" from "TMDB is down". A failure must never be saved as a partial match, or the cached edition would stay unmatched after TMDB recovers.

| Outcome          | Result                           | When                                                                                                                                                                                                  |
| ---------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Match            | a `Title`                        | A result list has a usable first entry (see below).                                                                                                                                                   |
| No match         | `undefined`                      | Both lists are empty, or the first entry of each non-empty list isn't an object, has no numeric `id`, or has no name.                                                                                 |
| Upstream failure | throws `BadGatewayException`     | TMDB returned a non-2xx status (including 401, 404 and 429), the network request failed, the body isn't JSON or isn't a JSON object, or `movie_results` or `tv_results` is missing or isn't an array. |
| Upstream failure | throws `GatewayTimeoutException` | TMDB didn't respond, or didn't finish sending the body, within 5 seconds.                                                                                                                             |

**Choosing a result.** `/find` normally puts an IMDb ID in at most one list. Only the first entry of `movie_results` and `tv_results` is considered; `person_results`, `tv_episode_results` and `tv_season_results` are ignored.

- **`kind` is `tv`:** the TV result, else the movie result.
- **`kind` is `movie`:** the movie result, else the TV result.
- **`kind` is absent:** the movie result, else the TV result. When both lists have a result, the movie wins.

The edition's `kind` comes from UPCMDB and thin records can get it wrong, so it sets the order but doesn't filter. When the result returned isn't the hinted kind, a warning is logged.

**Field mapping.**

| Title field  | From TMDB                                                                                                                                                                                                                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tmdbId`     | `id` (a number in TMDB), stored as a string.                                                                                                                                                                                                                                              |
| `kind`       | The result's `media_type`; if that's missing, the list it came from.                                                                                                                                                                                                                      |
| `name`       | `title` for a movie, `name` for TV.                                                                                                                                                                                                                                                       |
| `year`       | Year of `release_date` (movie) or `first_air_date` (TV), parsed as `YYYY-MM-DD`. Absent if the date is missing; a date in another format is also left absent and logged.                                                                                                                  |
| `imdbId`     | The IMDb ID that was looked up.                                                                                                                                                                                                                                                           |
| `posterPath` | `poster_path`, or absent. The full URL is built at response time (see above) by `TMDBService.getPosterURL`, which prefixes TMDB's image host (`https://image.tmdb.org/t/p/`) and a fixed size. The size and host live only in that method, so the RMSTR-62 image proxy changes one place. |
| `raw`        | The whole `/find` response, not just the chosen entry, so the choice between lists can be redone when re-normalizing.                                                                                                                                                                     |

**Logging.** Log lines name the status code, the network error code (e.g. `ECONNREFUSED`), the body length or the invalid field names. They never include the IMDb ID, the request URL or any of the body's contents, since those would record what was looked up (AGENTS.md §2). Client-facing messages are fixed strings ("TMDB request timed out", "TMDB request failed", "TMDB returned an error", "TMDB returned an invalid response").

Still open: whether partial matches carry an explicit `unmatchedTitle` flag (named in the RMSTR-13 acceptance criteria) or whether an absent `title` object is the signal, and whether the edition-level `enrichedTitle`, `kind`, `year` and `imdbId` stay as UPCMDB fallbacks next to the nested `title`.

### Disc facts (used for upgrade detection)

| Field                                                                       | Type                                                     | Notes                                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------- | -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `format`                                                                    | `DVD` \| `Blu-ray` \| `4K UHD`, or absent                | Primary format. For a combo pack, the highest format in the set.                                                                                                                                                                                                 |
| `discContents`                                                              | list of discs, or absent                                 | One entry per physical disc (so the list length is the disc count). Each entry has a `format` (always present) and a `region`. Absent when the source has no disc breakdown, or when any disc can't be identified (see [Building the list](#building-the-list)). |
| `discContents[].region`                                                     | `Region free`, a list of region codes, or absent         | Codes are `A`/`B`/`C` for Blu-ray and `1`–`8` for DVD. Notes like "(C untested)" are dropped.                                                                                                                                                                    |
| `hdr`                                                                       | list of `HDR10` \| `HDR10+` \| `Dolby Vision`, or absent | No duplicates. Empty list = SDR. DVD and Blu-ray editions always get an empty list (those formats can't carry HDR). Absent only for a 4K edition with no HDR information.                                                                                        |
| `packaging.steelbook`                                                       | true / false / absent                                    |                                                                                                                                                                                                                                                                  |
| `packaging.slipcover`                                                       | true / false / absent                                    |                                                                                                                                                                                                                                                                  |
| `packaging.memorabilia`                                                     | true / false / absent                                    | Figures, replicas, props or a collector's box in the package.                                                                                                                                                                                                    |
| `editionFlags.limited`, `.collector`, `.special`, `.anniversary`, `.boxset` | true / false / absent                                    |                                                                                                                                                                                                                                                                  |
| `masterResolution`                                                          | `native` \| `upscaled`, or absent                        | 4K only: whether the 4K disc comes from a native 4K master or is upscaled from 2K. Absent for DVD and Blu-ray.                                                                                                                                                   |

### Release and display details (shown, not used for logic)

| Field           | Type                        | Notes                                                  |
| --------------- | --------------------------- | ------------------------------------------------------ |
| `releaseDate`   | `YYYY-MM-DD` or absent      | Release date of this edition.                          |
| `distributor`   | string or absent            |                                                        |
| `country`       | string or absent            | Country of release, e.g. "United States".              |
| `coverImageURL` | string or absent            | Photo of this edition's case. See open items: privacy. |
| `runtime`       | integer (minutes) or absent | See the TV caveat under mapping rules.                 |
| `audio`         | string or absent            | Display string, not structured yet.                    |
| `subtitles`     | list of strings or absent   | Language names.                                        |
| `hasDigital`    | true / false / absent       | Whether a digital copy code is included.               |

## Mapping from UPCMDB

UPCMDB returns two record families with different keys and conventions:

- **Rich records** (Blu-ray.com style): real booleans, `hdr`, `discs`, `playback`, `packaging`, `releaseDate`, `videoCodec`, `resolution`, `audio`.
- **Thin records** (OMDb style): `"null"` strings for booleans, `type`, `altYear`, `runtime` as "90 min", no disc, HDR or packaging details.

Fields can come from either family, so every rule below must handle the key being absent.

| Field                   | UPCMDB source                                                                               | Rule                                                                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                    | none (the request)                                                                          | The normalized request code. If UPCMDB's `ean` differs from it, log a warning; don't use UPCMDB's value.                                                       |
| `kind`                  | `type`, `omdbType`, `seriesInfo`                                                            | `movie` → `movie`; `series` or `tv` → `tv`. Nothing present → absent.                                                                                          |
| `year`                  | `year`, then `omdbYear`, then `altYear`                                                     | `altYear` can be an open range ("2013–"); take the first four digits.                                                                                          |
| `format`                | `format`                                                                                    | `DVD` → DVD; `BLURAY` → Blu-ray; `4KUHD` or `UHD4K` → 4K UHD. Anything else → absent and logged.                                                               |
| `discContents`          | `discs`, `playback`                                                                         | See [Disc contents](#disc-contents).                                                                                                                           |
| `hdr`                   | `hdr`                                                                                       | Split the comma-separated string, map each token, drop and log unknown tokens. Missing `hdr` → empty list for DVD and Blu-ray, absent for 4K.                  |
| `packaging.steelbook`   | `steelbook`, `packaging`, `special_features`                                                | True if the boolean is true or "SteelBook" appears in the text (case-insensitive). False only on an explicit false. If they conflict, resolve to true and log. |
| `packaging.slipcover`   | `slipcover`, `packaging`                                                                    | `slipcover` is either `"true"` or descriptive text ("Slipcover in original pressing"); both mean true. Also true if the packaging text mentions a slipcover.   |
| `packaging.memorabilia` | `packaging`                                                                                 | True if the text mentions figures, replicas, props, memorabilia or a collector's box. Otherwise absent (no field ever states false).                           |
| `editionFlags.*`        | `limited_edition`, `collectors_edition`, `special_edition`, `anniversary_edition`, `boxset` | `true` or `"true"` → true; `false` or `"false"` → false (strings match case-insensitively); `"null"`, missing or any other value → absent.                     |
| `masterResolution`      | `resolution`                                                                                | 4K UHD editions only: "Native 4K" → native; "Upscaled 4K" → upscaled; anything else → absent. Always absent for DVD and Blu-ray.                               |
| `releaseDate`           | `releaseDate`                                                                               | "Mar 03, 2026" → `2026-03-03`. Read the month, day and year directly; don't go through a local-time date object, which shifts the day in some time zones.      |
| `distributor`           | `publisher`                                                                                 |                                                                                                                                                                |
| `coverImageURL`         | `productImageUrl`                                                                           |                                                                                                                                                                |
| `runtime`               | `runtime`                                                                                   | "108" or "90 min" → integer.                                                                                                                                   |
| `subtitles`             | `subtitles`                                                                                 | Split on commas, trim.                                                                                                                                         |
| `hasDigital`            | `has_digital_copy`                                                                          | Same as edition flags.                                                                                                                                         |

### Disc contents

The `discs` string looks like "4K Ultra HD | Blu-ray Disc | Two-disc set (1 BD-66, 1 BD-50)". The disc count is spelled out ("Two-disc", "Fourteen-disc").

The format labels at the start are **not** a reliable combo-pack signal. Loki S2 and WandaVision both say "4K Ultra HD | Blu-ray Disc", but their discs are "2 BD-100": two 4K discs, no Blu-ray. Use the `playback` string instead, which lists a region per disc type:

- "4K Blu-ray: Region free | 2K Blu-ray: Region A, B" → a 4K disc (region free) plus a Blu-ray disc (A, B). This is a combo pack.
- "4K Blu-ray: Region free" only → all discs are 4K.
- "Region 1 | (2,3,4,5,6,7,8 locked)" → DVD region 1.

Disc capacities (BD-66, BD-100 = 4K; BD-25 = Blu-ray) can back this up, but BD-50 is used for both 4K and Blu-ray discs, so capacity alone can't decide.

#### Building the list

1. **Guard.** If `discs` or `playback` is missing, `discContents` is absent.
2. **Count.** Take the last parenthesised group in `discs` ("1 BD-66, 1 BD-50"), split it on commas, and read the leading integer and capacity of each item. The total is the sum. If there's no group, or **any** item doesn't start with a number, log it and leave `discContents` absent. A partial count would make the list length wrong.
3. **Disc types.** Split `playback` on `|`. Skip segments wrapped in parentheses (notes such as "(C untested)" or "(2,3,4,5,6,7,8 locked)").
   - Labelled segments: "4K Blu-ray" → 4K UHD, "2K Blu-ray" → Blu-ray.
   - Unlabelled segments ("Region 1") belong to the edition's own `format`. If that format is unknown, log it and leave `discContents` absent.
   - Any other label (e.g. "3D Blu-ray"): log it and leave `discContents` **absent**. There's no way to tell how many discs the unknown type covers, so the rest can't be counted correctly either.
4. **Regions.** "Region free" (case-insensitive) → `Region free`. "Region A, B" → `["A", "B"]`; "Region 1" → `["1"]`. Anything else: log it and leave that type's region absent (the disc is kept).
5. **Splitting the count.**
   - One disc type: every disc is that type.
   - 4K + Blu-ray: the 4K count is the number of BD-66 and BD-100 discs, with a minimum of 1 (BD-50 can be either). The Blu-ray count is the rest, also with a minimum of 1. If the two don't add up to the total, log it and leave `discContents` absent.
   - Anything else (no types, or more than two): log it and leave `discContents` absent.
6. **Order.** 4K discs first, then Blu-ray.

Examples: "(1 BD-66, 1 BD-50)" with 4K + 2K playback → one 4K disc and one Blu-ray. "(1 BD-66, 2 BD-50)" → one 4K disc and two Blu-ray discs. "(2 BD-50)" → one of each.

A wrong list is worse than none: every rule that can't be applied leaves `discContents` absent, and logs the UPC with the raw `discs` and `playback` strings.

### TV runtime caveat

Thin TV records give the runtime of one episode (Rick and Morty S1: "23 min"), while rich TV records give the total (Loki S2: "297"). The schema has one `runtime` field and can't tell them apart. Treat `runtime` for `tv` editions as unreliable until this is resolved.

### Ignored fields

Not part of the contract. They stay in the raw JSON stored with each record (RMSTR-13): `plot`, `actors`, `writer`, `director`, `genre`, `rated`, `awards`, `imdbRating`, `rottenTomatoesId`, `metacriticUrl`, `metacricitUrl` (sic), `fandangoId`, `traktId`, `netflixId`, `wikiQid`, `allMovieId`, `wikiAllMovieId`, `videoCodec`, `videoSpecs`, `aspect_ratio`, `originalAspectRatio`, UPCMDB's own `digital` string ("Digital 4K | Movies Anywhere, Vudu"; the contract's `hasDigital` comes from `has_digital_copy`), `special_features` (except as a steelbook signal), `blu_ray_included`.

## Fixtures

Recorded UPCMDB responses in [`src/upc/mock/`](../src/upc/mock/), with the expected normalized values that matter most:

| Fixture           | Record                                                                    | Expected                                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `movie4kdv.json`  | Zootopia 2, rich                                                          | 4K UHD · HDR {Dolby Vision, HDR10} · steelbook true · upscaled · discs: 4K (region free) + Blu-ray (A, B) · digital true                   |
| `movie4khdr.json` | Black Panther: Wakanda Forever, rich                                      | 4K UHD · HDR {HDR10} · steelbook false · slipcover true · native · discs: 4K + Blu-ray, both region free · flags all false                 |
| `tv4kdv.json`     | Loki: The Complete Second Season, rich                                    | 4K UHD · HDR {Dolby Vision, HDR10} · steelbook true · memorabilia true · native · discs: two 4K, region free · kind absent · imdbId absent |
| `tv4khdr.json`    | WandaVision: The Complete Series, rich                                    | 4K UHD · HDR {HDR10} · steelbook true · memorabilia true · collector true · kind tv · discs: two 4K, region free                           |
| `moviebr.json`    | Barnyard, thin                                                            | Blu-ray · HDR empty (SDR) · packaging and flags all absent · runtime 90 · discContents absent                                              |
| `tvbr.json`       | Rick and Morty: Season 1, thin                                            | Blu-ray · HDR empty · kind tv · runtime 23 (per episode, see caveat)                                                                       |
| `moviedvd.json`   | Austin Powers in Goldmember, thin                                         | DVD · HDR empty · packaging and flags all absent                                                                                           |
| `tvdvd.json`      | SpongeBob SquarePants: The First 100 Episodes, rich but no title metadata | DVD · HDR empty · slipcover true · fourteen DVD discs, region 1 · imdbId, year, kind absent                                                |

**Missing fixture:** a 4K record with no `hdr` field, needed to test that HDR comes out absent rather than empty.

Recorded TMDB `/find` responses, used by `tmdb.service.spec.ts`:

| File             | Response                | Expected Title                                                  |
| ---------------- | ----------------------- | --------------------------------------------------------------- |
| `tmdbmovie.json` | Zootopia 2, movie match | kind `movie` · tmdbId `1084242` · name "Zootopia 2" · year 2025 |
| `tmdbtv.json`    | WandaVision, TV match   | kind `tv` · tmdbId `85271` · name "WandaVision" · year 2021     |
| `tmdbempty.json` | Every result list empty | no match (`undefined`)                                          |

## Open items

- **Response wrapper.** The endpoint response needs an envelope with a schema version (and source and fetch time) so clients can detect breaking changes. Not defined yet. Deferred (2026-11-01): not part of RMSTR-13, even though the nested title is a breaking change. That's acceptable while the only client is the unreleased iOS app.
- **Provenance.** RMSTR-8 calls for per-field provenance (source + last checked). The type has none yet. With UPCMDB as the only source, record-level provenance in the wrapper would carry the same information.
- **Cover image privacy.** `productImageUrl` points at `imagestorage.org/<UPC>.jpg`. If the app loads it directly, a third party sees the user's IP and the UPCs in their library, which breaks the privacy model (AGENTS.md §2). The backend should proxy or re-host images before any public build. The same applies to TMDB posters later.
- **New enum values.** Adding an `HDRFormat` or `DiscFormat` value breaks clients that decode those enums strictly. Either the client tolerates unknown values or the schema version is bumped.
- **Structured audio.** `audio` stays a display string for MVP (decided 2026-10-26). UPCMDB runs tracks together with no delimiter ("English: Dolby Atmos English: Dolby TrueHD 7.1 … French (Canada): Dolby Digital 5.1 | Audio descriptive"), multi-word language names make the boundaries ambiguous, and nothing in MVP uses it. Revisit with the R2 edition detail story: likely a list of tracks (language + codec) plus an audio-description flag from the text after `|`. Changing the type then is a breaking change, so it goes with a schema version bump.
- **TMDB.** Decided 2026-11-01: TMDB identity and poster arrive as a nested `title` object (see [Planned: nested title](#planned-nested-title-rmstr-13-decided-2026-11-01)).
