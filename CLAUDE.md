# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get
flutter run -d macos          # or ios / android
flutter test                  # all tests
flutter test test/foo_test.dart
flutter analyze
# DO NOT run: dart run build_runner — broken by the analyzer ^8.0.0 override
```

## Architecture

**State** — four BLoCs (`RecipeBloc`, `BookBloc`, `TagBloc`, `SettingsBloc`) provided globally in `main.dart`. Every mutating event ends by dispatching the matching `Load*` event to reload from the repo.

**Storage** — Hive. Adapters are **hand-written** (`.g.dart`); edit them manually after any `@HiveField` change and add a round-trip test. Type IDs are permanent: `Ingredient=0`, `Folder=1` (retired — never reuse), `Recipe=2`, `Instruction=3`, `RecipeBook=4`, `Tag=5`. Box name is `recipes_v2`.

**Key data rules**
- Book membership lives on `Recipe.bookIds` (many-to-many, source of truth).
- Tags are a `Tag` registry layered over `Recipe.labels` strings — `TagsScreen` shows their union.
- `Recipe.folderId` is kept deprecated for schema compat; don't build on it.
- Sync is best-effort via `_trySync` in `RecipeRepository` — cloud failures are logged, never thrown.

**Theme** — `lib/theme/recipe_accents.dart` has theme-aware surface helpers (`groupedBg`, `cardColor`, `subtleFill`, `hairline`) — use these instead of hardcoded colors on new screens. Brand color: `#F69021`.

**Export/Import** — `LibraryIoService`: zip (with `photos/`) or JSON-only. Import always adds new copies with regenerated IDs and remapped `bookIds`.

**Routing** — `go_router`; `context.go` for tab-level nav, `context.push` within sub-flows. Desktop two-pane layout uses `setState` on `MainScreen` instead of the router.

**iCloud** — container ID `iCloud.com.example.omnomnom` is a placeholder; sync won't work until provisioned.

**Design reference** — the source design (Claude design-tool export, "Recipe App - iOS Explorations") lives in this cloud environment at `/home/claude/repo/project/Recipe App - iOS Explorations.dc.html`, with its images in the sibling `assets/`/`uploads/` folders. It is not committed to the repo (ask the user to attach/commit it if a future session needs it and this path is gone). Most boards match the shipped UI closely; the ones that were still `PLACEHOLDER` as of 2026-07 — book social/members/activity, the invite share sheet, and cloud sync device/storage status — have since been implemented with honest (non-fabricated) data, since there's no account/backend system yet.
