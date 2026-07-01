# OmNomNom — Improvement & Sync Plan

Plan for a later implementation session (Claude Sonnet/Opus). Two parts:

1. **Code improvements** — unnecessary code, inefficiencies, simplifications found in an audit (2026-07-01).
2. **Cross-device / cross-user sync** in three levels.

Read `CLAUDE.md` first — especially the Hive rules (hand-written adapters, permanent
type IDs, `dart run build_runner` is broken) and the BLoC reload convention.

---

## Part 1 — Code improvements

Ordered by value. Items in **1.1 are actual bugs** discovered during the audit and
should be fixed before or together with any sync work, since sync makes them worse.

### 1.1 Correctness bugs in the existing sync path

The current `SyncService` implementations were written before several model fields
existed and silently drop data:

- **`_recipeToJson` in both `google_drive_sync_service.dart` and
  `icloud_sync_service.dart` omits `bookIds` and `accentColor`.** After a
  `syncFromCloud()`, every recipe loses its book membership (including Favorites)
  and its extracted accent colour.
- **The `Instruction` serialization in both services omits `groups` and
  `timerSeconds`** (only `description`, `group`, `photoPath` survive). Step timers
  and multi-group assignments are destroyed by a round-trip.
  `LibraryIoService.buildJson()` handles all of these correctly — use it as the
  reference.
- **`RecipeRepository.syncFromCloud()` (line ~135) does `_box.clear()` then
  re-inserts the cloud state.** Any recipe created locally since the last upload is
  permanently deleted. It also reconstructs `Recipe` field-by-field and forgets
  `accentColor`. Replace the clear-and-replace with a merge (see Part 2 sync
  engine), or at minimum only overwrite recipes whose IDs exist in the cloud set.
- **`_isSyncEnabled` is never persisted** (`TODO` at `recipe_repository.dart:14`).
  The toggle resets to off on every launch. Persist it in the settings Hive box
  alongside the other `SettingsBloc` keys.
- **Step photos (`Instruction.photoPath`) are never uploaded** — only the main
  `imagePath` is (see `addRecipe`/`updateRecipe` in `RecipeRepository`).

### 1.2 Duplication to consolidate

- **Recipe JSON codec exists three times**: `GoogleDriveSyncService._recipeToJson/FromJson`,
  `ICloudSyncService._recipeToJson/FromJson` (byte-identical to each other), and
  `LibraryIoService.buildJson/importFromJsonString`. Extract one
  `lib/services/recipe_codec.dart` with `Map<String, dynamic> recipeToJson(Recipe)`
  and `Recipe recipeFromJson(Map)` covering **all** current fields, and have all
  three call it. This is also the prerequisite for every sync level below.
- **"Sort by stored order" logic is written out four times** (tags screen `_merge`,
  detail `_tags`, detail tag picker, edit tag picker + `_tagsSection`). Extract a
  helper, e.g. in `recipe_accents.dart` or a new `lib/utils/order.dart`:
  ```dart
  List<T> sortByStoredOrder<T>(List<T> items, List<String> order, String Function(T) key)
  ```
- **`const _brand = Color(0xFFF69021)` is redeclared in 7 screen files**, and
  `recipe_accents.dart` has its own private `_brandOrange`. Export a single
  `const brandOrange` from `recipe_accents.dart` and delete the local copies.
- **`_Card` (grouped iOS-style card)** lives in `settings_screen.dart` and inline
  container equivalents in `tags_screen.dart` / `books_management_screen.dart`;
  **`_AddRow`** ("New tag…"/"New book…" green-plus row) is duplicated in both
  management screens. Move both to `lib/widgets/grouped_list.dart`.
- **Single-text-field prompt dialog** (`_prompt` in tags screen, `createBook` in
  books screen, `_rename` in books management) is the same AlertDialog written
  three times. One `Future<String?> promptText(BuildContext, {title, hint, initial})`
  in a shared file.

### 1.3 Performance

- **`extractAccentColorFromPath` runs a 1600-pixel HSL loop on the UI isolate**
  (`recipe_accents.dart`). Cheap-ish, but it also does a redundant copy:
  `readAsBytes()` already returns `Uint8List`, so `Uint8List.fromList(bytes)` can
  be dropped (and with it the `dart:typed_data` import). If images ever get big,
  wrap the scoring loop in `compute()`.
- **`recipesInBook` is O(recipes) per call and is invoked once per book** in the
  books grid and per row in books management → O(books × recipes). Build the index
  once per build: `Map<String, List<Recipe>> byBook` in one pass over recipes,
  then look up. Matters if the "948 books" scenario is real.
- **`_BookCover` re-shuffles its photo list on every build** (`..shuffle(Random(...))`
  in `build`). Deterministic seed makes it stable, but it still costs work per
  frame during scrolling — memoize in the widget or compute in the parent.
- **`main.dart` seeds the default recipe whenever the box is empty**, so a user who
  deletes everything gets the German cookie recipe back on next launch. Guard with
  a one-shot `seeded` flag in the settings box.

### 1.4 Cleanups / dead weight

- **~55 `print()` calls** in `google_drive_sync_service.dart`,
  `icloud_sync_service.dart`, `recipe_repository.dart` (flagged by `flutter
  analyze`). Replace with `dart:developer` `log(...)` or delete; keep messages on
  the failure paths only.
- **Unused imports** flagged by the analyzer: `settings_state.dart` in
  `cook_screen.dart` and `recipe_detail_screen.dart`; unused `_placeholder` method
  in `recipe_detail_screen.dart`.
- **`theme_selector.dart` uses the deprecated `Radio.groupValue/onChanged` API** —
  migrate to `RadioGroup`.
- **`recipe_edit_screen.dart` is 1,665 lines.** Split out `_TagPickerSheet`,
  the ingredient editor, and the step editor into `lib/widgets/` files. Pure
  mechanical move; do it before any further edit-screen features.
- **`SyncService.isConnected()` on iCloud does a full `gather()`** (lists every
  file) just to answer a boolean. Fine for now; revisit when file counts grow.

**Definition of done for Part 1:** `flutter analyze` reports 0 warnings in `lib/`
(the `avoid_print` infos gone), all existing tests pass, plus a new round-trip test:
`recipeFromJson(recipeToJson(r))` preserves every field including `bookIds`,
`accentColor`, `Instruction.groups`, `timerSeconds`.

---

## Part 2 — Sync in three levels

### Where we are

There is already a `SyncService` abstraction with an iCloud implementation
(`icloud_storage`, placeholder container ID — **not provisioned**) and a Google
Drive implementation (Drive `appDataFolder`, working client ID). Sync is
recipe-only, upload-on-write, manual pull, last-writer-clobbers-everything.
Export/import (`LibraryIoService`) is solid and already the de-facto "sharing"
mechanism.

### Shared foundation (build once, needed by every level)

These are prerequisites regardless of which level is targeted; they are also the
bulk of the engineering. **Do this as its own PR before any level.**

1. **Versioned change tracking on the models.** Add to `Recipe`, `RecipeBook`,
   `Tag` (new `@HiveField`s, hand-edit the `.g.dart` adapters, add round-trip
   tests — see CLAUDE.md):
   - `updatedAt: DateTime` — set on every write in the repositories.
   - `deleted: bool` (tombstone) — repositories stop hard-deleting when sync is
     enabled; UI filters tombstones out. Without tombstones, a delete on device A
     resurrects on device B at the next pull.
2. **Sync the whole library, not just recipes.** The sync payload must cover
   books, tags, and the `sort_orders` box. Reuse `LibraryIoService.buildJson`'s
   shape (it already covers everything) rather than the per-recipe JSON files.
   Suggested cloud layout: one `library.json` manifest per entity type is
   *simpler* but conflicts more; **per-entity files** (`recipes/<id>.json`,
   `books/<id>.json`, `tags/<id>.json`, `meta/sort_orders.json`) conflict less and
   match the current design — keep per-entity files.
3. **Merge instead of clobber.** Replace `syncFromCloud`'s clear-and-replace:
   - Pull remote entity list with `updatedAt`.
   - For each ID: newer `updatedAt` wins (last-write-wins). Tombstones win over
     older live versions.
   - Push local entities that are newer than remote or missing remotely.
   - LWW at entity granularity is acceptable for a recipe app; no need for CRDTs.
4. **Image content-addressing.** Name uploaded images by content hash
   (`<sha1>.jpg`) instead of the random UUID filename, so the same photo synced
   from two devices dedupes and renames never break references. Store the hash
   name in the JSON; resolve to a local path on download (the resolver pattern
   from `LibraryIoService.importFromJsonString` already does exactly this).
5. **A `SyncEngine` class** (new, `lib/services/sync_engine.dart`) that owns the
   merge loop and drives any `SyncService` backend. The existing `SyncService`
   interface grows to: `listEntities(kind) → [(id, updatedAt)]`,
   `download(kind, id)`, `upload(kind, id, json)`, `delete(kind, id)`,
   `uploadBlob/downloadBlob`. Both existing services adapt easily.
6. **Sync status surfacing** — reuse the existing `sync_status_screen.dart` and
   `onSyncCompleted` stream; add per-sync counts (pushed/pulled/conflicts).

### Level 1 — one user, same ecosystem (Timm: iPhone + iPad + Mac / or Android-only)

**Backend: the platform's free cloud, no server, no accounts.** This is the
existing architecture, completed.

- **Apple:** `icloud_storage` (iCloud Documents) as today.
  - Provision a real container: paid Apple Developer account, create
    `iCloud.<real-bundle-id>` in the developer portal, add the iCloud capability
    in Xcode for iOS **and** macOS targets, replace the placeholder in
    `icloud_sync_service.dart`.
  - iCloud Documents gives no push notifications in this plugin — sync on app
    start, on foreground (use `AppLifecycleListener`), and after every local write
    (already wired via `_trySync`).
- **Android:** Google Drive `appDataFolder` as today (client ID already works).
  - Same triggers. Drive `changes.list` with a stored page token makes the pull
    incremental instead of listing all files — worth doing, the API is simple.
- **Work items:**
  1. Shared foundation (above).
  2. Provision iCloud container; test on two simulators/devices.
  3. Persist the sync toggle; auto-sync on launch/foreground; debounce
     upload-on-write (e.g. 2 s) so slider-drags don't spam uploads.
  4. Settings UI: "Sync with iCloud/Google Drive" toggle + last-synced timestamp
     (screen exists), plus a "Sync now" button.
- **Effort:** ~1 session once the foundation lands. **Risk:** low. **Cost:** none.
- **Limitation to accept:** MacOS + iOS + iPadOS all covered by one container;
  an Android user gets the mirror-image feature; there is **no** path from this
  level to sharing — that's Level 2/3.

### Level 2 — multiple users, same ecosystem (Timm + Lara share, both on iOS / both on Android)

**The honest recommendation: skip the platform-native version of this level**
(see "Sequencing" below), but here is the easy version if it's wanted:

**Share unit = a Recipe Book.** Timm shares "Family Recipes"; every recipe whose
`bookIds` contains that book syncs to the shared location. This matches the
existing data model (book membership on `Recipe.bookIds`) and the UI ("Private"
badge on book covers becomes "Shared").

- **Android — genuinely easy:** move shared books out of `appDataFolder` into a
  visible Drive folder `OmNomNom Shared/<book-id>/`, then use the normal Drive
  sharing dialog (or `permissions.create` with Lara's email) on that folder. Both
  accounts run the same `SyncEngine` against that folder. Drive handles auth,
  ACLs, quota, revocation. Work: a "folder-scoped" variant of
  `GoogleDriveSyncService` + a share sheet in book detail. ~1 session on top of
  Level 1.
- **Apple — not easy, be aware:** iCloud *Documents* (what `icloud_storage`
  wraps) cannot share folders between Apple IDs. Real sharing needs **CloudKit**
  `CKShare` (shared record zones), which no maintained Flutter plugin exposes —
  it means hand-written Swift platform channels for share creation, the
  `UICloudSharingController` invite UI, accepting shares, and zone-change
  subscriptions, on iOS and macOS separately. Budget 2–3 sessions of
  platform-channel work and simulator pain, and it still only helps iOS↔iOS.
- **The actually-easy iOS fallback** (if Level 3 is not built next): polish the
  existing ZIP export into a "Share book" flow — export one book as
  `.omnomnom` file via the share sheet, register the file type so tapping it in
  Messages imports it. Not live sync, but zero infrastructure and it ships in
  half a session. (`LibraryIoService` needs a book-filtered export — small
  change.)

### Level 3 — everyone, everywhere (Timm has Android *and* iOS; shares with friends) — *the design's vision*

Platform clouds cannot bridge ecosystems. This level requires a **neutral
backend**; once it exists it also *replaces* Levels 1 and 2 (a single-user,
single-platform user is just a trivial case of it).

- **Backend choice — recommendation: Supabase.**
  | | Supabase (recommended) | Firebase | Self-hosted (PocketBase) |
  |---|---|---|---|
  | Data | Postgres + row-level security | Firestore | SQLite |
  | Auth | Apple + Google sign-in built in | Same | DIY |
  | Storage (photos) | S3-compatible buckets | Cloud Storage | Local disk |
  | Sharing model | RLS policies = natural fit for "library members" | Security rules (awkward for many-to-many shares) | Manual |
  | Cost at hobby scale | Free tier generous | Free tier generous | Server rent |
  | Lock-in | Low (plain Postgres) | High | None |
- **Schema** (server-side; local Hive stays the offline cache):
  ```
  users(id, display_name)
  libraries(id, owner_id, name)                    -- every user gets one on signup
  library_members(library_id, user_id, role)        -- owner | editor | viewer
  recipes(id, library_id, json jsonb, updated_at, deleted)
  books(id, library_id, json jsonb, updated_at, deleted)
  tags(id, library_id, json jsonb, updated_at, deleted)
  photos: storage bucket, path = <library_id>/<content-hash>.jpg
  ```
  Storing the entity payload as `jsonb` (same shape as the shared codec from Part
  1.2) keeps the server schema-agnostic — model changes don't need migrations,
  matching the app's Hive-first design. RLS: a row is visible iff the requesting
  user is in `library_members` for its `library_id`.
- **Sharing UX:** "Share book" → creates a second library containing that book (or
  simpler v1: share your whole library) → invite by email or QR/link with a short
  code → acceptor's `library_members` row is inserted. Shared books appear in the
  books grid with the collaborators' avatars (the design's vision).
- **Sync engine:** identical merge loop from the shared foundation; the
  `SyncService` backend is a `SupabaseSyncService`. `updated_at` LWW; the server
  timestamps writes to avoid client clock skew. Supabase Realtime subscription on
  the `library_id` gives push-based updates — recipes appear on Lara's phone
  seconds after Timm saves. Offline: queue local writes in a Hive `outbox` box,
  drain on reconnect.
- **Auth:** Sign in with Apple + Google Sign-In (both have Flutter packages; SIWA
  is an App Store requirement anyway once Google login is offered). Anonymous →
  linked account upgrade so sync is opt-in, exactly like the current toggle.
- **Migration:** on first login, push the entire local library (the codec from
  Part 1.2 serializes it) into the user's fresh server library. Keep
  `LibraryIoService` ZIP export forever as the escape hatch.
- **Effort:** 3–4 sessions (backend setup + auth ~1, sync engine wiring ~1,
  sharing UX ~1, hardening/tests ~1). **Cost:** free tier until real traction.

### Sequencing recommendation

```
PR 1  Part 1 fixes (codec unification is the keystone)      ← do this first, always
PR 2  Shared foundation (updatedAt, tombstones, SyncEngine, merge)
PR 3  Level 1 (iCloud container + Drive polish)              ← cheap win, ships value
PR 4  Level 3 backend (Supabase: auth + schema + SupabaseSyncService)
PR 5  Level 3 sharing UX (invites, shared-book UI)
```

**Skip Level 2's CloudKit path entirely.** Level 2 on Apple costs 2–3 sessions of
Swift platform-channel work that Level 3 makes obsolete; Level 2 on Android is
cheap but also throwaway. If interim sharing is needed while Level 3 is built,
ship the half-session ZIP "Share book" flow instead. Level 1, by contrast, is
worth shipping: it's nearly done, has zero running costs, works without accounts,
and the foundation work (PR 2) is 100 % reused by Level 3 — only the thin
`SyncService` backend differs.

### Open decisions for the user before PR 4

1. Supabase vs Firebase (plan assumes Supabase).
2. Share granularity v1: whole library (simpler) or per-book (matches design)?
3. Is a paid Apple Developer account available for the iCloud container (Level 1
   on Apple) — and is Level 1 wanted at all if Level 3 follows soon after?
