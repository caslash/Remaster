# Title search endpoint (client contract)

How a client searches for a movie or TV show by name (RMSTR-56). Manual search (RMSTR-16) and matching an unmatched disc to its title (RMSTR-74) are built against this document. Each result has the same shape as the nested `title` in [`edition-schema.md`](edition-schema.md#nested-title-rmstr-69), so the client decodes both into one `Title` type.

Implementation: [`src/tmdb/tmdb.controller.ts`](../src/tmdb/tmdb.controller.ts), [`src/tmdb/tmdb.service.ts`](../src/tmdb/tmdb.service.ts), [`src/tmdb/dto/search-query.dto.ts`](../src/tmdb/dto/search-query.dto.ts), and for the 503, [`src/common/filters/retry-after.filter.ts`](../src/common/filters/retry-after.filter.ts). If this document and the code disagree, fix whichever is wrong in the same change.

Sections marked **Planned** describe agreed behaviour that isn't implemented yet. Clients shouldn't rely on it until the marker is removed.

## Request

`GET /search?q={text}`

| Part | Required | Values                               | Notes                                                                                      |
| ---- | -------- | ------------------------------------ | ------------------------------------------------------------------------------------------ |
| `q`  | yes      | at least 2 characters after trimming | The search text, URL-encoded. Sent once. Leading and trailing whitespace is removed first. |

The text is trimmed, then checked. A missing `q`, a `q` given more than once, or one shorter than 2 characters after trimming (so `" a "` and `"   "` both fail) is rejected with a 400 **before TMDB is called**. Clients should apply the same rule and not send those queries at all.

Punctuation and non-ASCII text are fine (`AC/DC`, `Fast & Furious`, `Amélie`) as long as the client URL-encodes them.

### What TMDB receives

The server calls TMDB's [multi search](https://developer.themoviedb.org/reference/search-multi) once per request: `GET {TMDB_BASE_URL}/search/multi` with the trimmed text as `query`, `include_adult=false`, `language=en-US` and `page=1`, the server's bearer token, and a 5-second timeout. Only the first page of TMDB's results is used (up to 20 entries), so a client gets at most 20 results.

Search results are **not stored**. Unlike `/upc`, there's no cache: every search goes to TMDB.

## Responses

### 200 OK

A JSON array of titles, in TMDB's order (TMDB's relevance ranking). An empty array means nothing matched; it's never used for an error.

| Field       | Type                            | Notes                                                                                                                    |
| ----------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `tmdbId`    | string, always present          | TMDB's numeric ID as a string. **Only unique per kind**, so compare `kind` + `tmdbId`.                                   |
| `kind`      | `movie` \| `tv`, always present | From TMDB's `media_type`.                                                                                                |
| `name`      | string, always present          | `title` for a movie, `name` for a TV show.                                                                               |
| `year`      | integer or absent               | From `release_date` (movie) or `first_air_date` (TV). Absent when TMDB has no date, which is common for upcoming titles. |
| `posterURL` | string or absent                | Full URL of TMDB's poster at size `w500`. Absent when TMDB has no poster.                                                |

`imdbId` is part of the nested `title` shape but is **always absent** here: TMDB's search results don't include it.

Which TMDB entries become results:

- **Kept:** every entry whose `media_type` is `movie` or `tv` and that has a numeric `id` and a name. Results with no date or no poster are kept, with `year` or `posterURL` left out.
- **Dropped:** people (`media_type: "person"`), any other media type, and entries that aren't objects, have no numeric `id` or have no name.

Example (`GET /search?q=Home%20Alone`, shortened):

```json
[
  {
    "tmdbId": "65282",
    "kind": "tv",
    "name": "Home Alone",
    "year": 2013,
    "posterURL": "https://image.tmdb.org/t/p/w500/1hqGagr94soBq70Lq7tPHvNmmxy.jpg"
  },
  {
    "tmdbId": "771",
    "kind": "movie",
    "name": "Home Alone",
    "year": 1990,
    "posterURL": "https://image.tmdb.org/t/p/w500/onTSipZ8R3bliBdKfPtsDuHTdlL.jpg"
  },
  {
    "tmdbId": "1832995",
    "kind": "movie",
    "name": "Untitled Home Alone Film"
  }
]
```

### Errors

Error bodies use Nest's default shape: a JSON object with `statusCode`, `message` and `error`. **Clients should branch on the status code only**, not on the message text.

| Status                      | When                                                                                                                                                                 | Calls TMDB? |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| **400 Bad Request**         | `q` is missing, given more than once, or shorter than 2 characters after trimming.                                                                                   | no          |
| **502 Bad Gateway**         | TMDB returned an error status other than 429, the request failed (e.g. a network error), or the response isn't JSON, isn't a JSON object, or has no `results` array. | yes         |
| **503 Service Unavailable** | TMDB rate-limited the server (429). Has a `Retry-After` header.                                                                                                      | yes         |
| **504 Gateway Timeout**     | TMDB didn't respond, or didn't finish sending the body, within 5 seconds.                                                                                            | yes         |

#### Retry-After on a 503

TMDB's rate limit is counted per IP, and every search goes out from the server's one address, so a 429 means the whole app is over TMDB's limit for a moment, not one user. The limit is short-lived (TMDB allows roughly 50 requests a second), so the wait is short.

The header is always a whole number of seconds from 1 to 30 (decided 2026-11-25), so an unexpected upstream value can't tell clients to wait minutes or not at all:

| TMDB's `Retry-After`                                                            | Sent to the client       |
| ------------------------------------------------------------------------------- | ------------------------ |
| Whole seconds from 1 to 30 (surrounding whitespace is ignored)                  | the same value           |
| Whole seconds outside that range (`0`, `45`, `86400`)                           | **clamped**: `1` or `30` |
| Missing, empty, or not whole seconds (an HTTP date, `-1`, `5.5`, `1e3`, `5abc`) | `2`                      |

HTTP dates are allowed by the HTTP spec but aren't converted: that would mean trusting TMDB's clock against the server's, and the fallback is short anyway.

#### What the client should do

- **400:** don't retry the same text. The client shouldn't have sent it (see [Request](#request)).
- **503:** wait `Retry-After` seconds, then retry once at most. In a search-as-you-type field, waiting for the next keystroke after the delay is enough; don't loop.
- **502, 504:** a temporary failure. Show an error and offer a retry.
- **200 with `[]`:** nothing matched. Suggest different wording.

## Privacy

- **Sent by the client:** the search text only. No user or device identifier, no library contents.
- **Sent to TMDB:** the trimmed search text and the server's token. Nothing else from the client.
- **Stored:** nothing. Search results aren't saved.
- **Logged on every request:** one timing line from `TimingInterceptor` with the handler name (`TmdbController.searchTitle`) and the duration. It's built from the controller and handler names, so it never contains the query, path, IP or headers.
- **Logged on failure:** TMDB's status (and status text for non-429 errors), network error codes, and the length of an unreadable body. Warnings about a result's date format include the date only. **The search text is never logged** by the application; `tmdb.service.spec.ts` checks this for every outcome.
- **Known gap (RMSTR-10):** the search text is part of the URL (`/search?q=…`), so hosting-level request logs on Railway could record it next to the client's IP, regardless of what the application logs. Whether those logs can be turned off is RMSTR-10. If they can't, consider moving the text out of the URL.
