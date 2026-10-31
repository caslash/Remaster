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

## Local HTTPS

`src/main.ts` serves HTTPS when `backend/secrets/localhost.pem` and `backend/secrets/localhost-key.pem` exist, and falls back to plain HTTP when they don't. The `secrets/` directory is gitignored. The iOS app always uses `https`, so you need the certs to point a device or Simulator at a local backend.

1. Install [mkcert](https://github.com/FiloSottile/mkcert) (`brew install mkcert`) and run `mkcert -install` once to create and trust a local root CA on your Mac.
2. From `backend/`, run `mkcert -key-file secrets/localhost-key.pem -cert-file secrets/localhost.pem localhost 127.0.0.1 ::1 <your-mac-hostname>.local` (create `secrets/` first). Add your Mac's LAN IP if the device reaches it by IP.
3. On a physical iPhone, trust the root CA: AirDrop or email the file printed by `mkcert -CAROOT` (`rootCA.pem`), install the profile under Settings › General › VPN & Device Management, then enable it under Settings › General › About › Certificate Trust Settings. The Simulator trusts the Mac's keychain, so it needs no extra step. An untrusted cert shows up in the app as "Couldn't reach Remaster".
4. In `ios/Config/Secrets.xcconfig`, set `REMASTER_BACKEND_BASE_URL` to the hostname you put on the cert and `REMASTER_LOCAL_PORT` to the backend port (3000 by default).
