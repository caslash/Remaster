# Remaster backend

NestJS v12 API for Remaster, hosted on Railway (RMSTR-55). Requires Node 24.9 or later (see `engines` in `package.json` and `.nvmrc`): Nest 12 ships as ESM, and Jest relies on Node's native `require(esm)` support to load it.

What it's for (see section 3 of [`AGENTS.md`](../AGENTS.md)):

- UPC and title lookup, so the iOS app stops calling UPCMDB directly and its key leaves the app binary.
- Normalizing raw source responses (UPCMDB, TMDB, and later others) into the app's own edition schema.
- Later: the edition database, the enrichment worker, and the new-editions feed.

## Ground rules

- Requests are anonymous. They carry no user or device identifier, and the server doesn't log client IPs (section 2 of `AGENTS.md`).
- Third-party keys live in Railway service variables. Locally they go in `backend/.env`, which is gitignored. Never commit them.
- On Railway, set the service's root directory to `backend/`.
