# OmNomNom — Design Migration Plan

Switching the UI to the **Recipe App – iOS Explorations** design while keeping the
existing BLoC / Hive / GoRouter logic intact wherever possible.

> Working agreement: after each **major step** we stop, run `flutter analyze` +
> `flutter test`, and manually verify on a device/emulator before moving on.
> Anything not yet buildable is tagged **`PLACEHOLDER`** via a shared helper.

## Decisions locked
- **Books are many-to-many now**: replace `Recipe.folderId` with `List<String> bookIds`.
- **Steps get a timer**, keep a single group per step. Multi-group = `PLACEHOLDER`.
- **Design delivery**: via *Send to Claude Code Web* (seeds files into the workspace).
- Social/sharing features on Books = `PLACEHOLDER` (later).

## ⚠️ Open blocker
The design files are **not in the repo yet**. `DesignSync` needs interactive
`/design-login` which isn't available here. Phases 2+ (skeleton) need the seeded
HTML/assets before pixel work can start. Phase 0 + Phase 1 do **not** depend on the
design and can proceed now.

---

## Phase 0 — Groundwork (no design needed)
1. Branch: `feature/design-migration`.
2. Add a shared **`PlaceholderBanner` / `comingSoon()`** helper (greppable, consistent
   styling) for every stubbed feature: search, book social features, folder
   rename/delete, multi-group steps.
3. Inventory current screens → target screens map (below).

**Checkpoint:** `flutter analyze` clean, app still runs unchanged.

## Phase 1 — Data model migration (no design needed, do FIRST)
The skeleton is cheap to redo; a Hive migration done twice is not. Lock the model first.

1. **Recipe**: `folderId` (`@HiveField(4)`) → keep field number retired; add
   `List<String> bookIds` as a **new** `@HiveField(11)`. Migrate old `folderId` →
   `[folderId]` on load.
2. **Instruction**: add `int? timerSeconds` (`@HiveField(3)`). Single `group` stays.
3. **Folder → Book** rename: `Folder` model, `FolderBloc`/`FolderRepository`, routes,
   and UI references. Consider a `coverImagePath` for the books grid (design likely
   shows cover art instead of just a color).
4. **Total time**: derive `prepTime + cookTime` in a getter; no new field unless the
   design shows an explicit standalone total.
5. Regenerate adapters: `dart run build_runner build --delete-conflicting-outputs`.
6. **Box migration**: bump `recipes_v2` → `recipes_v3` (breaking change per project
   rules), with a one-time copy/migrate-on-open.
7. **Fix the sync `group`-drop bug** while we're in the serialization code, since
   grouping is now core (both Drive + iCloud `_recipeToJson`).

**Checkpoint:** migration unit test (old box → new box), `flutter test`, manual
launch to confirm existing recipes load with their books/groups intact.

## Phase 2 — Design skeleton (needs seeded design)
1. Read seeded `*.dc.html` + assets; extract palette, type scale, spacing, components
   into `app_theme.dart` (keep `AppTheme.primaryOrange` unless the design overrides it).
2. Expand `MainScreen` shell from 2 → **3 tabs: Recipes · Books · Settings**
   (update `BottomNavigationBar`, desktop two-pane, and `router.dart` routes).
3. Build empty/stubbed versions of the three top-level screens matching the design
   chrome (app bars, nav, layout) — content wired in later phases.

**Checkpoint:** navigation works on mobile + desktop, all three tabs reachable,
nothing crashes; verify against design screenshots.

## Phase 3 — Recipes list + detail (needs design)
1. Restyle `HomeScreen` / `RecipeList` to the design's recipe cards/grid.
2. Restyle `RecipeDetailScreen`: hero photo, meta (servings / total time / tags),
   grouped ingredients with **portion-size highlighting preserved**, steps with
   timer + step photo.
3. Keep all data from existing `RecipeBloc`.

**Checkpoint:** analyze + test + manual review of a real recipe.

## Phase 4 — Books (needs design)
1. Books grid/list screen from the design.
2. Book detail = its recipes (many-to-many via `bookIds`).
3. Add/remove recipe ↔ book UI.
4. Social features rendered as `PLACEHOLDER`.

## Phase 5 — Settings + Edit (needs design)
1. Restyle `SettingsScreen`, theme + about.
2. Restyle `RecipeEditScreen` (largest file, 815 lines) to the new design, keeping the
   `ListItem` / `IngredientParser` edit logic. Add step-timer input.

## Phase 6 — Polish & placeholders sweep
- Grep all `PLACEHOLDER`, confirm each is intentional and visibly marked.
- Search (currently a no-op `TODO`) decision: implement or `PLACEHOLDER`.
- Full pass: `flutter analyze`, `flutter test`, manual on iOS/Android/macOS.

---

## Screen mapping (current → target)
| Current | Target |
|---|---|
| `MainScreen` (2 tabs) | 3-tab shell (Recipes/Books/Settings) |
| `HomeScreen` + `RecipeList` | Recipes list (redesigned cards) |
| — | **Books** list + detail (new) |
| `RecipeDetailScreen` | Recipe detail (redesigned) |
| `RecipeEditScreen` | Recipe edit (redesigned, logic kept) |
| `SettingsScreen` / theme / about | Settings (redesigned) |

## Risk notes
- Hive migration is the highest-risk step → isolated in Phase 1 with a test.
- `RecipeEditScreen` is large and central; restyle last, change UI not logic.
- Sync still has no merge logic (full-replace) — out of scope, unchanged.
