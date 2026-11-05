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

## Database (PostgreSQL)

The edition database is PostgreSQL, accessed through TypeORM (`@nestjs/typeorm`). Normalized edition fields are columns; the raw source JSON is stored alongside them. The connection is configured in `src/app.module.ts`; `src/database/data-source.ts` is a separate `DataSource` used only by the TypeORM CLI.

### Local setup

1. Install and start PostgreSQL. With Homebrew: `brew install postgresql@17`, then `brew services start postgresql@17`. Any recent PostgreSQL works.
2. Create an empty database: `createdb remaster`.
3. Copy `.env.example` to `.env` if you haven't already, and set `DATABASE_URL` to the connection string, for example `postgres://<your-mac-username>@localhost:5432/remaster`. Add a password to the URL if your local server requires one. `DATABASE_URL` is required: the app refuses to start without it.
4. Run `pnpm install`, then `pnpm start:dev`. The app connects and applies any pending migrations as it starts. Look for the TypeORM and Nest startup logs, and no connection error.

If the database is unreachable at startup (server stopped, wrong URL, wrong credentials), the app doesn't start without it. It makes 4 connection attempts 2 seconds apart, logging "Unable to connect to the database. Retrying (n)..." for each, then exits with code 1 after about 6 seconds, which makes a Railway deploy fail. The retries give a database that is still starting up a few seconds to become ready. They are set by `retryAttempts` and `retryDelay` in `src/app.module.ts`; raise `retryAttempts` first if deploys fail because Postgres isn't ready in time.

### Migrations

**Decision (RMSTR-65): migrations run when the app starts.** `migrationsRun` is on, so every boot applies pending migrations before the app begins serving requests. Locally and on Railway there is no separate migration step: deploying or restarting the service is what migrates it. `synchronize` is off, so the schema only ever changes through migrations.

Why this strategy: there is one backend instance and no other consumer of the database, so there's no second process to race with, and it keeps the Railway setup to "deploy and go". Trade-offs to revisit if the backend scales to several instances or a migration becomes slow or risky: concurrent instances could try to migrate at once (TypeORM takes a lock to guard against this, but a long migration blocks startup), and a failed migration stops the deploy from becoming healthy. The alternative is a separate pre-deploy command running `pnpm migration:run`.

Rules for writing migrations:

- Migrations live in `src/database/migrations/` and compile to `dist/database/migrations/`. The app loads the compiled `.js` files, so a migration only runs after `pnpm build` (which `nest start` and the Railway build do for you).
- After changing an entity, generate a migration with `pnpm migration:generate src/database/migrations/<Name>` (this compares the entities to your local database, so run the existing migrations first), then review the generated SQL before committing it.
- `pnpm migration:run` and `pnpm migration:revert` apply or undo migrations from the CLI against the database in `DATABASE_URL`. Use `revert` only on your local database.
- Never edit a migration that has been merged; add a new one.

### Connection pool and logging

The pool allows up to 20 connections, closes idle ones after 30 seconds, and gives up on opening a connection after 5 seconds. Query logging is off (`logging: false`) in every environment so the logs never contain queries or the UPCs in them (section 2 of [`AGENTS.md`](../AGENTS.md)). If you turn it on temporarily while debugging locally, don't commit that change.

### Railway

1. In the Railway project, add a PostgreSQL database service.
2. In the backend service's Variables, add `DATABASE_URL` as a reference to the database service's connection variable (Railway's variable reference syntax, `${{<database service name>.DATABASE_URL}}`), so the two stay linked if the credentials change. Use the private-network URL where Railway offers one.
3. Deploy. On boot the service applies pending migrations and connects. A bad `DATABASE_URL` shows up in the deploy logs as the connection error followed by the process exiting.
