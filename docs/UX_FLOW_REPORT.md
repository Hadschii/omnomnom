# OmNomNom — UX Flow Audit & Handover Report

**Audience:** a later Claude (Sonnet/Opus) implementation session.
**Date:** 2026-07-04 · audited at commit `a1ef2c5`.
**Method:** full read of `lib/router.dart`, all 13 screens, the widgets, and the
services they call. Every claim below carries a `file:line` anchor (line numbers
as of `a1ef2c5`).

**Design reference:** no design file exists in the repo. The "attached design"
is the mock-up set the redesign was originally built from (iOS-style recipe app).
Its intent survives in code as tagged `PLACEHOLDER` blocks: an account/profile
row, book sharing with members & activity feed, per-device sync status, units,
timer sounds, and step text size. Where this report says "design intent", it is
reconstructed from those markers.

---

## 1. Flow inventory (what exists today)

### Navigation skeleton
- 3 tabs (Recipes / Books / Settings) via `MainScreen` + `BottomNavigationBar`
  (`main_screen.dart:56`). Tabs map to routes `/`, `/books`, `/settings`.
- <600 px = mobile single pane; ≥600 px = desktop, where **only the Recipes tab**
  gets a master/detail split (`main_screen.dart:110-133`); Books and Settings
  render full-width.
- Full-screen routes: `/recipe/new`, `/recipe/:id`, `/recipe/:id/edit`,
  `/recipe/:id/cook`, `/books/:id`, `/settings/{theme,about,tags,books,sync}`.

### Flow A — Browse & find a recipe
Home tab → large-title list with search bar (`home_screen.dart:75`). Search
matches title, labels, ingredient names (`home_screen.dart:64-73`). Card shows
photo, book-chips overlay (max 3 + `···`), title, servings·total-time·first-label
meta row. Tap → detail (mobile `context.go('/recipe/:id')`, desktop selects into
right pane). Empty state and no-match state exist with recovery actions.

### Flow B — Read a recipe
`RecipeDetailScreen`: hero photo (accent-colored fallback), favorite heart
(writes `bookIds` ↔ seeded `favorites` book, `recipe_detail_screen.dart:645`),
`…` sheet (Edit / Delete with confirm), tag pills (stored order, max 3 + `+n`) +
`+ Tag` picker sheet, stats row, **Start Cooking** CTA, Ingredients/Steps
segmented control. Steps show timer pill, group chips, 54 px step photo.

### Flow C — Cook mode
`CookScreen`: wakelock on, progress bar segments, one step at a time with
prev/next, optional per-step countdown timer (tap to start/pause/resume),
optional step photo, bottom panel groups all ingredients with the active step's
group(s) surfaced as "NEEDED NOW" and tick-off checkboxes. Close → back to
detail; finishing the last step also closes.

### Flow D — Create / edit a recipe
`RecipeEditScreen` (1,672 lines): cover photo picker (extracts accent color in
background, `recipe_edit_screen.dart:195`), title, servings stepper, time dialog
(active + cook minutes), tag chips + picker (can create registered tags),
Ingredients tab (ungrouped + named groups; free-text entry parsed by
`IngredientParser` — supports EN/DE units and unicode fractions), Steps tab
(drag-to-reorder, per-step sheet with photo / description / m:ss timer / group
chips / delete). Save validates only "title non-empty". Cancel = silent discard.

### Flow E — Books
Books tab grid (2 columns, auto-density mosaic covers, "n recipes · 🔒 Private")
→ `BookDetailScreen`: mosaic header, "owned by you", list/social toggle (social
= placeholder), recipe bands → detail, `…` menu (Add/remove recipes via
checkbox sheet, Rename, Delete-with-confirm which detaches memberships).
Book creation from grid tile, appbar `+`, or Settings→Recipe Books.

### Flow F — Settings & data
Settings tab: profile placeholder, sync summary → `/settings/sync` (functional
enable/push/pull + placeholder device list), Library (Books & Tags management,
both with drag-to-reorder that propagates app-wide), Appearance (theme,
accent-from-photo toggle — both functional; Units placeholder), Cooking
(2 placeholders), Data (ZIP/JSON export via share sheet, import with count
snackbar, delete-all with confirm), About.

---

## 2. Broken or questionable flow logic (bugs first)

### B1. Cook-mode timer is destroyed by step navigation — worst UX defect found
`_goTo()` calls `_resetTimer()` unconditionally (`cook_screen.dart:47-51`).
Real cooking flow: start the 10-min simmer timer on step 3, flip to step 4 to
prep — the running timer is silently cancelled. Timers must survive step
changes (and arguably run per-step in parallel with a small "timer running on
step 3" indicator). This inverts the entire point of a cook-along timer.

### B2. Cook-mode timer finishes silently
When the countdown hits 0 the pill just changes text ("Timer done") — no sound,
no vibration, no local notification (`cook_screen.dart:70-80`). Phone in pocket
= burnt food = the one failure a cooking app must not have. The Settings
"Timer sounds" toggle is a placeholder that does nothing (`settings_screen.dart:126`).

### B3. Detail-screen tag picker creates *unregistered* labels — inconsistent with edit screen
Detail `_TagPickerSheet._addCustom()` just adds the string to the recipe's
labels (`recipe_detail_screen.dart:759-766`); the edit screen's picker `_create()`
properly registers a `Tag` via `AddTag` (`recipe_edit_screen.dart:1467-1487`).
Result: a tag created from detail gets no registry entry → different color
source, not listed in Settings→Tags reorder until it's derived from labels,
and the Settings tag count (registered only, `settings_screen.dart:34`)
diverges from the Tags screen count (union). Fix: register the tag in both.

### B4. Deleting a tag has no confirmation and silently rewrites every recipe
`TagsScreen._deleteTag` fires immediately from the red `–` circle
(`tags_screen.dart:138-146`), stripping that label from every recipe. Recipes
and books both confirm deletion; tags don't. One mis-tap on a tag used by 40
recipes = unrecoverable bulk edit. Add a confirm dialog stating the affected
recipe count.

### B5. Favorites book is deletable, causing a broken favorite state
The seeded `favorites` book appears in Settings→Recipe Books and Book detail
like any book and can be deleted. The heart button keeps writing
`bookIds: ['favorites']` (`recipe_detail_screen.dart:645-654`), and
`_seedDefaults()` resurrects the book on next launch (`recipe_book_repository.dart:22`).
Between deletion and restart, hearts point at a nonexistent book. Either make
Favorites undeletable (hide from management list) or make the heart re-create it.

### B6. Enable-sync dialog copy contradicts (fixed) behavior — and is still destructive-sounding
`sync_status_screen.dart:158-179`: "Enabling sync overwrites local recipes with
cloud data. This cannot be undone." Since commit `5945338` the pull is a merge,
not an overwrite. Same for the Pull row subtitle "Overwrites local recipes"
(`sync_status_screen.dart:103`). Update the copy; today it scares users away
from a now-safe action.

### B7. "iCloud Sync" label is wrong on Android
`_SyncSummaryCard` title (`settings_screen.dart:312`) and the sync screen
AppBar (`sync_status_screen.dart:24`) hardcode "iCloud", but
`RecipeRepository.init()` gives Android `GoogleDriveSyncService`
(`recipe_repository.dart:29-33`). Label should be platform-derived
("iCloud Sync" / "Google Drive Sync" / "Cloud Sync").

### B8. Desktop two-pane leaks into mobile-style full-screen on edit
Right-pane detail (`showBackButton: false`) → `…` → Edit runs
`context.go('/recipe/:id/edit')` (`recipe_detail_screen.dart:679`). After save,
`context.pop()` lands on the **full-screen** `/recipe/:id` route, not back in
the two-pane. The user "loses" the master list until they click a tab. Same
after Delete from the right pane: `_back()` finds `onBack == null`, possibly
`go('/')` (`recipe_detail_screen.dart:656-664`). The desktop flow needs a
deliberate return path (e.g. edit in a dialog/pane, or after pop restore the
two-pane selection).

### B9. `MainScreen.selectedRecipeId` mobile branch is dead-but-armed code
`_buildMobileBody` renders a detail if `_selectedRecipeId != null`
(`main_screen.dart:85-99`), but on mobile nothing ever sets it (`RecipeList.
onRecipeSelected` is only wired on desktop; mobile taps `context.go`). If a
desktop window is resized below 600 px with a selection active, mobile mode
suddenly shows a detail with no bottom-nav escape except the hidden back
handling. Low priority, but decide: support it or remove it.

### B10. Book-detail mosaic contradicts the books-grid mosaic
`BookDetailScreen._Mosaic` is a fixed 6×3 grid that **repeats** photos
(`photos[i % photos.length]`, `book_detail_screen.dart:543`) — precisely the
behavior the user rejected for the grid covers, which were rebuilt as
auto-density/unique-photos/no-repeat (`books_screen.dart` `_BookMosaic`).
Port `_BookMosaic` (or extract it to `lib/widgets/`) so the cover a user taps
and the header they land on look like the same book.

---

## 3. Cross-screen inconsistencies

| # | Inconsistency | Where |
|---|---|---|
| I1 | **go vs push for recipe detail**: Home uses `context.go('/recipe/:id')` (`home_screen.dart:176`), Book detail uses `context.push(...)` (`book_detail_screen.dart:240`). Back behaves subtly differently (push returns into the book; go rebuilds from route tree). Pick push for both drill-ins. | home / book detail |
| I2 | **Rename-book UI ×3, one un-deduped**: `books_management_screen.dart` uses the shared `promptText()`, but `book_detail_screen.dart:336-360` still has its own inline AlertDialog copy (missed in the Part-1 dedup). Also `_newGroup`/`_editIngredient`/`_editTimes` in the edit screen are near-clones of `promptText` variants. | book detail, edit |
| I3 | **Row-tap semantics differ between the two management lists**: Tags row tap = rename dialog; Books management row tap = rename dialog — but the visually identical Books *grid* card tap = open. Users who learn "tap opens" from the grid will mis-tap in Settings. Consider explicit chevron/edit affordance. | tags/books mgmt |
| I4 | **Two segmented-control implementations** (detail `_segmented` accent-colored, edit `_switch` brand-colored) and **two mosaics**, **two circle-button widgets** (`recipe_detail_screen.dart:165`, `book_detail_screen.dart:163`). Visual drift risk; extract to `lib/widgets/`. | detail/edit/books |
| I5 | **Tag count mismatch**: Settings shows registered-tag count (`settings_screen.dart:34-37`); Tags screen header counts the union of registered + in-use labels (`tags_screen.dart:56`). After B3 both can disagree with what a user sees on recipes. | settings/tags |
| I6 | **Confirmation policy**: delete recipe ✓ confirm, delete book ✓ confirm, delete-all ✓ confirm, delete tag ✗, remove ingredient ✗ (fine), discard edits ✗ (see M1). Make destruction-with-fanout always confirm. | app-wide |
| I7 | **"Total time" definition**: card meta and stats compute `prep + cook`, but the edit screen labels the inputs "Active" and "Cook" while its box shows the sum as "Total time" (`recipe_edit_screen.dart:364-380`). Detail stats show "active" and "total" but never cook alone. Harmless but muddled; unify naming (Active / Cook / Total everywhere). | edit/detail/home |
| I8 | **Search bar only exists on Home.** A book with 100 recipes (`BookDetailScreen`) has no search/filter; the books grid has no search either. | books flows |

---

## 4. Gaps — designed-for but not reachable, or plainly missing

### G1. Tags cannot filter anything (the headline gap)
The Tags screen literally says "used to filter recipes" (`tags_screen.dart:57`)
and users can reorder them app-wide — but **no screen offers tag filtering**.
Home search only substring-matches label text. The natural design: tag chip row
(in stored order — the ordering feature finally pays off) above the Home list,
tappable to filter, and/or tapping a tag pill on a recipe detail lists all
recipes with that tag. Right now tags are write-only decoration.

### G2. Servings scaling
Detail shows a static servings number; Cook mode doesn't show servings at all.
Every mainstream recipe app lets you bump servings and see scaled amounts.
`IngredientParser` already separates quantity+unit from the name, so scaled
display is feasible (parse `amount`, multiply, re-format; fall back to raw
string when unparseable).

### G3. Sort orders and accent colors are excluded from export/import & sync
`LibraryIoService.buildJson` exports recipes/books/tags but not the
`sort_orders` box (tag order, book order — `tag_repository.dart:17`,
`recipe_book_repository.dart:31`). A restored library loses the user's curated
ordering. Cloud sync (recipes only) also never syncs books/tags/orders — a
"synced" second device has different books, no tags, default order.
(Already flagged strategically in `IMPROVEMENT_AND_SYNC_PLAN.md`; repeated here
because it's a *user-visible flow* break, not just architecture.)

### G4. Imported/synced recipes never get an accent color
`extractAccentColorFromPath` runs only in the edit screen's `_pickImage`
(`recipe_edit_screen.dart:195`). Recipes arriving via import or cloud pull with
photos keep `accentColor == null` → brand orange forever, even with
"Accent colour from photo" on. Backfill: compute on import/pull when
`imagePath != null && accentColor == null`.

### G5. No "share one recipe / one book"
Export is all-or-nothing ZIP/JSON from Settings. The sharing vision (book
"Private" badge, social tab) implies per-book sharing; the pragmatic v1 is a
book-scoped or recipe-scoped export via the existing share sheet, plus opening
`.zip`/`.json` from the OS (file-type association → import flow).

### G6. Repeated import always duplicates
By design import regenerates IDs, so importing the same file twice doubles the
library (`library_io_service.dart:29-31`). There is no dedupe/merge choice and
no undo. At minimum warn: "This adds N recipes as new copies (existing library
untouched)."

### G7. Cook mode lacks the finishing touches its flow implies
- No swipe-left/right between steps (buttons only, `cook_screen.dart:215+`).
- No "keep ticked ingredients" persistence — leaving and re-entering cook mode
  resets `_checked` and `_step` (all state is ephemeral).
- The unused lightbulb icon (`Icons.light_mode_outlined`, `cook_screen.dart:185`)
  looks tappable but is decoration.
- No landscape / external-display consideration.

### G8. Recipe list has no sort control
Hive insertion order = effectively creation order, unlabeled. Expected:
sort by recently added / A–Z / total time, or at least newest-first with a header.

### G9. No onboarding / first-run
Fresh install shows one seeded German cookie recipe with no explanation, an
English UI, and no hint that Books/Tags exist. A 3-card first-run or an empty-
state that points at import/create would close the loop. (Also decide on
localization: seeded content is German, UI is English.)

### G10. Book cover management
`RecipeBook.coverImagePath` exists in the model and is preserved by rename
(`book_detail_screen.dart:357`), but **no UI ever sets it** — covers are always
the mosaic. Either build "choose cover photo" in the book `…` menu or drop the
field from flows (keep for schema).

### G11. Desktop polish gaps
- Books grid is locked to 2 columns at any width (`books_screen.dart:73`);
  with the auto-density mosaic the covers now scale, but 2 giant cards on a
  27-inch display is not the design's intent. Column count should derive from
  width (like the mosaic's cell math).
- No keyboard support anywhere (Esc to close cook mode, arrows for steps,
  Cmd+N new recipe, focus search).
- Settings/tags/books/sync routed screens have no two-pane treatment (full
  screen with back arrow on desktop is serviceable but jarring next to the
  Recipes split view).

### G12. Accessibility
Interactive elements are mostly bare `GestureDetector`s: no `Semantics` labels,
no tooltips, small (22 px) hit targets on delete circles, color-only group
distinction. Flag for a dedicated pass (VoiceOver order in cook mode matters
most — it's the hands-busy screen).

---

## 5. Copy & micro-content issues

| # | Text | Problem |
|---|---|---|
| C1 | "n books · collections to share" (`books_management_screen.dart:47`) | Sharing doesn't exist; over-promises. |
| C2 | "owned by you" (`book_detail_screen.dart:147`) | Meaningless without accounts; drop until sharing lands. |
| C3 | "Off · keep recipes on this device only" vs the enable dialog threatening overwrite | Mixed message; align with the merge behavior (see B6). |
| C4 | Snackbar "Syncing…" with `duration: Duration(days: 1)` (`sync_status_screen.dart:38-41`) | If the state stream misses a transition the snackbar sticks for a day. Use a dismissible/progress affordance tied to state, not a timed snackbar. |
| C5 | Units row shows hardcoded "Metric" (`settings_screen.dart:117`) | Reads as functional; either mark visually as coming-soon or hide. |
| C6 | Timer-sounds switch renders `value: true` always (`settings_screen.dart:131`) | A switch that snaps back with a "coming soon" toast is worse than a disabled row. |

---

## 6. Prioritized worklist for the implementation session

**P0 — fix before anything else (real user harm / broken promises)**
1. B1 + B2: cook-mode timer must survive navigation and must ring (local
   notification + optional sound; wire the Settings toggle or remove it).
2. B4: confirm tag deletion (with affected-recipe count).
3. B3: register custom tags created from the detail picker.
4. B6/B7/C3/C4: sync copy + platform label pass.

**P1 — flow completions with high visible value**
5. G1: tag filter chips on Home (uses the stored order) + tappable tag pills.
6. G2: servings scaling in detail & cook mode.
7. B5: protect the Favorites book.
8. B10 + I4: extract shared mosaic/segment/circle-button widgets; reuse the
   auto-density mosaic in book detail.
9. G3: include `sort_orders` in export/import (and later in sync).

**P2 — polish and consistency**
10. I1 (push everywhere), I2 (finish prompt dedup incl. book_detail),
    I6 (confirm policy), G4 (accent backfill), G6 (import warning),
    G8 (sort control), C1/C2/C5/C6 (copy).
11. B8/B9: desktop return-path + decide mobile `selectedRecipeId`.
12. G11 (desktop columns/keyboard), G7 (cook-mode gestures/persistence).

**P3 — bigger investments (separate plans exist)**
13. Sharing/social + accounts → `IMPROVEMENT_AND_SYNC_PLAN.md` Part 2 Level 3.
14. G9 onboarding + localization decision.
15. G12 accessibility pass.

---

## 7. Facts a follow-up session will need

- **Favorites** = seeded book with fixed id `favorites`
  (`RecipeBookRepository.favoritesBookId`); heart on detail toggles membership.
- **Tag order / book order** live in Hive box `sort_orders`, keys `'tags'`
  (names) and `'books'` (ids); helper `sortByStoredOrder` in `lib/utils/order.dart`
  is the canonical way to apply them.
- **Tags** are dual-sourced: `Tag` registry + free `Recipe.labels` strings;
  the Tags screen merges both. Any tag feature must handle unregistered labels.
- **Book membership** is on `Recipe.bookIds` (recipe is source of truth) —
  adding/removing from a book always goes through `UpdateRecipe`.
- Shared UI primitives so far: `promptText()` (`lib/widgets/prompt_text.dart`),
  `brandOrange` + surface helpers (`lib/theme/recipe_accents.dart`).
  `_Card`/`_NavRow`/`_SwitchRow` are still private to `settings_screen.dart`.
- Pre-existing failures in `test/cook_screen_test.dart` (4 tests, icon-finder
  mismatch) predate all recent work — don't chase them as regressions, but
  fixing them belongs with the B1/B2 cook-mode work.
- `flutter analyze` is clean of errors/warnings; only `info`-level lints remain
  (`unnecessary_underscores`, new `onReorder` deprecation in 3 files).
