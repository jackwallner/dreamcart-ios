---
paths:
  - "DreamCartTests/**"
  - "Shared/Services/SupabaseClient.swift"
---

# DreamCart unit tests

- `DreamCartTests` runs in the app host (`gh-sim test`, scheme `DreamCart`) and compiles `Shared/` into the test bundle, so tests use their own copy of every shared type and need no `@testable import`.
- Network code is tested through `SupabaseStub`, a `URLProtocol` registered on `URLSession.shared` that answers only the Supabase host. Install a handler per test and `uninstall()` in `tearDown`. Route like PostgREST (an unknown path is a 404), so a wrong URL fails the test instead of passing.
- `SupabaseClient.shared` is a process-wide actor. Get a session with the DEBUG-only `signInWithPassword` against the stub (`SupabaseStub.tokenJSON(expiresIn:)`; under 120 puts the token inside the refresh window) and call `signOutLocal()` in `setUp` and `tearDown`, so no fake session is left in the simulator keychain.
- `ShopStore` pages the rest of the catalog from a task of its own. Wait for the `offset=` request before uninstalling the stub.
- A test class that touches `ShopStore` or `AuthController` is `@MainActor`.
