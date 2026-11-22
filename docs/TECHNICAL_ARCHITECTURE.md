# Technical architecture

## 1. Toolchain and repository
- Rojo 7 (`default.project.json`, `release.project.json` without test code), tools pinned in `rokit.toml` (rojo, selene, StyLua, luau-lsp, lune).
- Layout: `src/shared` (pure modules, config, protocol) → `ReplicatedStorage.Shared`; `src/server` with `main.server.lua` and `Services/` → `ServerScriptService.Server`; `src/client` → `StarterPlayerScripts.Client`; art in `assets/art/rbxm` → `ReplicatedStorage.ArtAssets`; tests in `tests/studio/Cases` → `ServerStorage.UnitTest`.
- Services are ModuleScripts with pure functions plus an optional `start()` that the server bootstrap calls.

## 2. Authority and service boundaries
The server owns money, inventory, purchases, permissions, progression and save data. The client only renders state and sends intents.

## 3. Network contract
All client-to-server calls are untrusted. Use one versioned action protocol, never client-supplied prices, cash or item payloads.
- Request: `{version=1, requestId=<GUID>, action=<enum>, payload=<validated fields>}`.
- Response: `{ok, errorCode?, revision?, data?}`.
- Every action validates exact payload fields, is rate-limited per player and action, and financial actions are idempotent through the request ID.
- Server → client: filtered state snapshots on join, revisioned deltas after mutations, a one-way notice event with localized keys.

## 4. Data model
Versioned save schema (`schemaVersion`) with step-by-step migrations and validation; unknown or invalid data fails closed.

## 5. Persistence and concurrency
DataStore `UpdateAsync` with a session lock, bounded retries with backoff, batched saves on a dirty flag, release on leave and `BindToClose`, fail closed when the lock is lost.
