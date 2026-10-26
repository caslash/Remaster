# Edition schema (client contract)

The normalized shape the backend returns for a disc edition, and the rules for mapping UPCMDB responses into it (RMSTR-8). The iOS client (RMSTR-11) decodes against this document.

Source of truth for the type: [`src/upc/types/edition.d.ts`](../src/upc/types/edition.d.ts). If this document and the type disagree, fix whichever is wrong in the same change.

## Conventions

- **Absent means unknown.** A field the source doesn't tell us about is left out of the JSON. Clients decode it as optional (`nil` in Swift). The server never invents a value to fill a gap.
- **Empty is not absent.** An empty list is a known answer. The important case is `hdr`: an empty list means the disc is SDR, and an absent `hdr` means we don't know.
- **True / false / unknown.** Every boolean in `packaging` and `editionFlags`, plus `hasDigital`, has three states: `true`, `false`, or absent.
- **Why the type says `| undefined` and not `?:`.** It forces the mapper to set every key explicitly, so a forgotten field is a compile error instead of a silently missing key. It serializes the same way (undefined keys are dropped from the JSON). Don't convert these to optional properties.
- **Canonical values only.** Enum values are the backend's own spellings (`4K UHD`, `Blu-ray`, `Dolby Vision`), never the source's (`4KUHD`, `BLURAY`). An unrecognised source value is left out and logged, never guessed.
- **Dates are calendar dates.** `releaseDate` is a date-only ISO 8601 string (`YYYY-MM-DD`). Clients decode it as a calendar date, not a point in time, so it shows the same day in every time zone.

## Fields

### Identity

| Field          | Type                   | Notes                                                                                                               |
| -------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `id`           | string, always present | Canonical GTIN-13 of the requested code, so `043396647640` and `0043396647640` are the same edition. See [`upc-endpoint.md`](upc-endpoint.md) for how codes are normalized. |
| `barcodes.upc` | string or absent       | As printed on the case (12 digits).                                                                                 |
| `barcodes.ean` | string or absent       | 13 digits.                                                                                                          |
| `asin`         | string or absent       | Amazon product ID, for retailer links (R2).                                                                         |
| `imdbId`       | string or absent       | The only title key until TMDB mapping (RMSTR-13). Missing on some records (Loki S2, SpongeBob).                     |

### Title

| Field           | Type                       | Notes                                                                                                   |
| --------------- | -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `title`         | string, always present     | Retail title as printed, e.g. "Loki: The Complete Second Season".                                       |
| `enrichedTitle` | string or absent           | Name of the work, e.g. "WandaVision".                                                                   |
| `kind`          | `movie` \| `tv`, or absent | Absent when the record has no type signal (Loki S2). Not guessed from the title. Matches TMDB's naming. |
| `year`          | integer or absent          | Year of the work, not the disc release.                                                                 |

### Disc facts (used for upgrade detection)

| Field                                                                       | Type                                                     | Notes                                                                                                                                                                                                                                        |
| --------------------------------------------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `format`                                                                    | `DVD` \| `Blu-ray` \| `4K UHD`, or absent                | Primary format. For a combo pack, the highest format in the set.                                                                                                                                                                             |
| `discContents`                                                              | list of discs, or absent                                 | One entry per physical disc (so the list length is the disc count). Each entry has a `format` (always present) and a `region`. Absent when the source has no disc breakdown. A disc whose format can't be identified is left out and logged. |
| `discContents[].region`                                                     | `Region free`, a list of region codes, or absent         | Codes are `A`/`B`/`C` for Blu-ray and `1`–`8` for DVD. Notes like "(C untested)" are dropped.                                                                                                                                                |
| `hdr`                                                                       | list of `HDR10` \| `HDR10+` \| `Dolby Vision`, or absent | No duplicates. Empty list = SDR. DVD and Blu-ray editions always get an empty list (those formats can't carry HDR). Absent only for a 4K edition with no HDR information.                                                                    |
| `packaging.steelbook`                                                       | true / false / absent                                    |                                                                                                                                                                                                                                              |
| `packaging.slipcover`                                                       | true / false / absent                                    |                                                                                                                                                                                                                                              |
| `packaging.memorabilia`                                                     | true / false / absent                                    | Figures, replicas, props or a collector's box in the package.                                                                                                                                                                                |
| `editionFlags.limited`, `.collector`, `.special`, `.anniversary`, `.boxset` | true / false / absent                                    |                                                                                                                                                                                                                                              |
| `masterResolution`                                                          | `native` \| `upscaled`, or absent                        | 4K only: whether the 4K disc comes from a native 4K master or is upscaled from 2K. Absent for DVD and Blu-ray.                                                                                                                               |

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
| `id`                    | none (the request)                                                                          | The normalized request code. If UPCMDB's `ean` differs from it, log a warning; don't use UPCMDB's value.                                                      |
| `kind`                  | `type`, `omdbType`, `seriesInfo`                                                            | `movie` → `movie`; `series` or `tv` → `tv`. Nothing present → absent.                                                                                          |
| `year`                  | `year`, then `omdbYear`, then `altYear`                                                     | `altYear` can be an open range ("2013–"); take the first four digits.                                                                                          |
| `format`                | `format`                                                                                    | `DVD` → DVD; `BLURAY` → Blu-ray; `4KUHD` or `UHD4K` → 4K UHD. Anything else → absent and logged.                                                               |
| `discContents`          | `discs`, `playback`                                                                         | See [Disc contents](#disc-contents).                                                                                                                           |
| `hdr`                   | `hdr`                                                                                       | Split the comma-separated string, map each token, drop and log unknown tokens. Missing `hdr` → empty list for DVD and Blu-ray, absent for 4K.                  |
| `packaging.steelbook`   | `steelbook`, `packaging`, `special_features`                                                | True if the boolean is true or "SteelBook" appears in the text (case-insensitive). False only on an explicit false. If they conflict, resolve to true and log. |
| `packaging.slipcover`   | `slipcover`, `packaging`                                                                    | `slipcover` is either `"true"` or descriptive text ("Slipcover in original pressing"); both mean true. Also true if the packaging text mentions a slipcover.   |
| `packaging.memorabilia` | `packaging`                                                                                 | True if the text mentions figures, replicas, props or memorabilia. Otherwise absent (no field ever states false).                                              |
| `editionFlags.*`        | `limited_edition`, `collectors_edition`, `special_edition`, `anniversary_edition`, `boxset` | `true` or `"true"` → true; `false` or `"false"` → false; `"null"` or missing → absent.                                                                         |
| `masterResolution`      | `resolution`                                                                                | "Native 4K" → native; "Upscaled 4K" → upscaled; anything else → absent.                                                                                        |
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

## Open items

- **Response wrapper.** The endpoint response needs an envelope with a schema version (and source and fetch time) so clients can detect breaking changes. Not defined yet.
- **Provenance.** RMSTR-8 calls for per-field provenance (source + last checked). The type has none yet. With UPCMDB as the only source, record-level provenance in the wrapper would carry the same information.
- **Cover image privacy.** `productImageUrl` points at `imagestorage.org/<UPC>.jpg`. If the app loads it directly, a third party sees the user's IP and the UPCs in their library, which breaks the privacy model (AGENTS.md §2). The backend should proxy or re-host images before any public build. The same applies to TMDB posters later.
- **New enum values.** Adding an `HDRFormat` or `DiscFormat` value breaks clients that decode those enums strictly. Either the client tolerates unknown values or the schema version is bumped.
- **TMDB.** A TMDB ID and poster will be added when RMSTR-13 maps IMDb IDs to TMDB. New optional fields are non-breaking if the client ignores unknown keys.
