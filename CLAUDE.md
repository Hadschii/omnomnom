# OmNomNom — Claude Reference

## What the App Does

OmNomNom is a personal recipe organizer. Users create and edit recipes with a title, cover photo, servings/prep/cook times, labels, folder assignment, and lists of ingredients and step-by-step instructions. Both ingredients and instructions support optional group headers for multi-section recipes (e.g., "Dough" / "Filling"). Recipes sync to Google Drive (Android) or iCloud (iOS/macOS). Full architecture detail is in `ARCHITECTURE.md`.

---

## Tech Stack

- **Flutter** (Material 3, targets iOS / Android / macOS)
- **Dart SDK** ^3.10.1
- **State**: `flutter_bloc` — five BLoCs (Recipe, Folder, Book, Tag, Settings), all provided at the root
- **Local DB**: `hive` — NoSQL key-value store with generated type adapters
- **Routing**: `go_router` v17
- **Fonts**: `google_fonts` — Inter throughout
- **Images**: `image_picker` + `path_provider`
- **Sync (Android)**: `googleapis` (Drive v3) + `google_sign_in`
- **Sync (iOS/macOS)**: `icloud_storage`
- **IDs**: `uuid` v4

---

## How to Run and Build

```bash
# Install dependencies
flutter pub get

# Run (picks a connected device automatically)
flutter run

# Run on a specific platform
flutter run -d macos
flutter run -d ios
flutter run -d android

# Build
flutter build apk          # Android release APK
flutter build ios          # iOS (requires Xcode)
flutter build macos        # macOS app bundle

# Run all tests
flutter test

# Analyze
flutter analyze
```

### After editing Hive models

Any change to a `@HiveType` or `@HiveField` annotation requires regenerating the adapter:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated files are `*.g.dart` — never edit them manually.

### Launcher icons

To regenerate launcher icons after replacing `assets/images/app_logo.png`:

```bash
dart run flutter_launcher_icons
```

---

## Key Conventions

### BLoC pattern
- Events are imperative: `LoadRecipes`, `AddRecipe`, `DeleteRecipe`.
- Every mutating event (Add/Update/Delete) ends by dispatching `LoadRecipes()` on itself — the BLoC always reloads from the repository after writing.
- BLoCs are provided globally in `main.dart` — never create a local BLoC inside a widget. Always use `context.read<>()` or `context.watch<>()`.
- The `SettingsBloc` is the single source of truth for sync state. It delegates to `RecipeRepository` for the actual sync operations.

### Hive
- Recipe box is named `recipes_v2` (not `recipes`). If you change the `Recipe` model schema in a breaking way, rename the box and handle migration.
- Type IDs are permanent: Ingredient=0, Folder=1, Recipe=2, Instruction=3, RecipeBook=4, Tag=5. Never reuse an ID, even for a deleted model.
- Adapters are hand-maintained: `build_runner` cannot run because the `analyzer ^8.0.0` override is incompatible with the codegen stack. After a `@HiveField` change, edit the matching `*.g.dart` by hand (mechanical format) and add a round-trip test, rather than running `dart run build_runner`.
- Hive is opened once during startup in `main()`. Boxes are accessed via `Hive.box<T>()` thereafter (synchronous, already open).
- The `settings` box is managed entirely by `SettingsBloc` — other code should not open or write to it directly.

### Routing
- Use `context.go('/path')` for imperative navigation and `context.pop()` to go back.
- `MainScreen` is the shell for both tabs and for recipe detail on mobile. The router reuses it with different parameters rather than stacking separate screens.

### Edit screen
- `RecipeEditScreen` mirrors the recipe view: cover photo → title → servings/total-time → an `Ingredients | Steps` segmented switch → the section's content. It holds its own mutable `_EditIngredient` / `_EditStep` working models (not `Ingredient`/`Instruction` directly), mapped from the recipe on load and back to model objects on save.
- Ingredient groups are named buckets created only in the Ingredients tab. A step references 0..n of those groups via `_StepEditorSheet` (the per-step editor: photo, instruction text, optional `m:ss` timer, group multi-select).
- On save, steps write `Instruction.timerSeconds`, `.groups` (with legacy `.group` = first, for back-compat) and `.photoPath`; ingredients keep their `group`.
- When a user types an ingredient like "100g Mehl", run it through `IngredientParser.parse()` → `{amount: "100 g", name: "Mehl"}`. Always use the parser — do not split ingredient strings manually.

### Recipe Books
- A `RecipeBook` (`recipe_books` box, `BookBloc`/`RecipeBookRepository`) is a shareable collection. Membership is **many-to-many and stored on the recipe**: `Recipe.bookIds` is the source of truth, so adding/removing a recipe to/from a book is a `RecipeBloc.UpdateRecipe` with a modified `bookIds` (use `Recipe.copyWith`).
- `BookDetailScreen` derives its member list and mosaic cover from recipes whose `bookIds` contains the book id. Social/sharing (members, permissions, invite, activity) is **not built** — `_SocialPlaceholder`.

### Settings & Tags
- `SettingsScreen` is a self-contained grouped iOS list (no more `SettingsList`); `MainScreen` shows it full-width on desktop (only Recipes uses the two-pane). Rows route to `/settings/{theme,about,tags,books,sync}`.
- Tags are a registry (`Tag` typeId 5, `tags` box, `TagBloc`/`TagRepository`) layered over the free-form `Recipe.labels` strings; a `Tag` adds a stable id + colour. `TagsScreen` shows the **union** of registered tags and labels-in-use. Rename/delete fan out to recipes via `RecipeBloc.UpdateRecipe` (relabel / strip the label), and the editor still writes plain label strings.
- Sync stays future work: `SyncStatusScreen` keeps the existing functional `SettingsBloc` toggle/push/pull unchanged and marks the device/storage view as PLACEHOLDER.

### Images
- Images must be copied into `getApplicationDocumentsDirectory()` under a UUID filename before the path is stored on the recipe. Never store a gallery temp path or a path outside appDocDir.
- `recipe.imagePath` is an absolute path. Display with `Image.file(File(imagePath))`.
- On sync, services strip the path to filename-only for the JSON payload; `syncFromCloud` resolves it back to an absolute path after download.

### Sync
- Sync is platform-gated at `RecipeRepository.init()`: `ICloudSyncService` on iOS/macOS, `GoogleDriveSyncService` on Android. There is no sync service on other platforms.
- `syncFromCloud()` is a **full replace** — it clears all local recipes before writing. There is no merge/diff logic.
- After any sync-related operation, `RecipeRepository` emits on `onSyncCompleted`. `RecipeBloc` and `SettingsBloc` both subscribe and react automatically.

### Theme
- Brand color: `#F69021` (defined as `AppTheme.primaryOrange`).
- Theme is Material 3 (`useMaterial3: true`). Avoid hardcoded colors; use `Theme.of(context).colorScheme.*`.
- The theme is live-bound: `SettingsBloc` emits → `BlocBuilder` in `main.dart` rebuilds `MaterialApp.router` → immediate effect without navigation.

---

## Gotchas and Important Notes

**Hive box name is `recipes_v2`**
The box was renamed at some point (likely a schema change). If you add a non-nullable field to `Recipe`, rename the box again and handle old data.

**iCloud container ID is a placeholder**
`ICloudSyncService._containerId = 'iCloud.com.example.omnomnom'` must be replaced with the actual provisioned iCloud container ID before iOS/macOS sync will work at all.

**`ingredient.group` and `instruction.group` are not synced**
Both `_recipeToJson` methods (Google Drive and iCloud) serialize `ingredients` as `{name, amount}` and `instructions` as `{description}` — the `group` field is dropped. Grouped recipes lose their section structure after a cloud round-trip.

**`_isSyncEnabled` is in-memory only**
`RecipeRepository._isSyncEnabled` is a plain `bool` field, not persisted. On app restart, it starts as `false`. The actual persisted value lives in the Hive `settings` box, managed by `SettingsBloc.LoadSettings`, which calls `RecipeRepository.enableSync()` or `disableSync()` on startup to reconcile.

**Sync toggle failure resets to false**
If `SyncService.init()` throws (e.g., Google auth cancelled), `SettingsBloc._onToggleSync` emits `isSyncEnabled: false`. The Hive `settings` box will have `sync_enabled = true` written before the error — that mismatch is resolved on the next `LoadSettings` (next app launch) since the bloc catches the init error and emits false there too.

**`RecipeBloc` double-fires `LoadRecipes` after sync**
On add/update/delete with sync enabled, `RecipeRepository` emits `onSyncCompleted` which triggers `RecipeBloc.add(LoadRecipes())`, but the BLoC also calls `add(LoadRecipes())` directly from the mutation handler. This results in two sequential loads — harmless but worth knowing.

**`HomeScreen` and `RecipeList` live in the same file**
`lib/screens/home_screen.dart` exports both `HomeScreen` and `RecipeList`. `RecipeList` is reused in `MainScreen`'s desktop layout. `SettingsList` is similarly defined in `settings_screen.dart` and reused in `MainScreen`.

**Search is not implemented**
The search `IconButton` in `HomeScreen`'s AppBar shows a "coming soon" PLACEHOLDER snackbar — there is no live filtering yet.

**Folder management is incomplete**
Folders can be created from the `RecipeEditScreen` form, but there is no UI to rename or delete folders.

**Desktop layout does not navigate via router**
In the desktop two-pane layout, clicking a recipe calls `setState(() { _selectedRecipeId = recipe.id; })` on `MainScreen` — it does not push a route. The router is only used for mobile navigation and full-page screens (edit, theme settings, about).

**`analyzer: ^8.0.0` override**
`pubspec.yaml` has a `dependency_overrides` entry for the `analyzer` package. This is required for `build_runner` to function with the current Dart SDK version. Do not remove it without verifying that code gen still works.
