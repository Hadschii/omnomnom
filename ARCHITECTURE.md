# OmNomNom — Architecture Reference

## Folder Layout

```
lib/
├── main.dart                    # Entry point: Hive init, repo creation, BLoC wiring
├── router.dart                  # go_router route definitions
├── models/                      # Hive data models + generated adapters
│   ├── ingredient.dart          # typeId: 0
│   ├── ingredient.g.dart
│   ├── folder.dart              # typeId: 1
│   ├── folder.g.dart
│   ├── recipe.dart              # typeId: 2
│   ├── recipe.g.dart
│   ├── instruction.dart         # typeId: 3
│   └── instruction.g.dart
├── repositories/                # Data access layer
│   ├── recipe_repository.dart   # Hive CRUD + sync orchestration
│   └── folder_repository.dart   # Hive CRUD for folders
├── blocs/                       # State management
│   ├── recipe/
│   │   ├── recipe_bloc.dart
│   │   ├── recipe_event.dart
│   │   └── recipe_state.dart
│   ├── folder/
│   │   ├── folder_bloc.dart
│   │   ├── folder_event.dart
│   │   └── folder_state.dart
│   └── settings/
│       ├── settings_bloc.dart
│       ├── settings_event.dart
│       └── settings_state.dart
├── screens/                     # Full-page UI
│   ├── main_screen.dart         # Shell: bottom nav + responsive layout
│   ├── home_screen.dart         # Recipe list + RecipeList/RecipeCard widgets
│   ├── recipe_detail_screen.dart
│   ├── recipe_edit_screen.dart  # Create/edit form + _AnimatedAddButton
│   ├── edit_screen_helpers.dart # ListItem, HeaderItem, IngredientItem, InstructionItem
│   ├── settings_screen.dart     # Settings UI + SettingsList widget
│   ├── theme_settings_screen.dart
│   └── about_settings_screen.dart
├── widgets/                     # Reusable UI components
│   ├── theme_selector.dart      # Radio buttons for ThemeMode
│   └── about_view.dart          # Logo + version info
├── services/                    # Business logic / external integrations
│   ├── sync_service.dart        # Abstract SyncService interface
│   ├── google_drive_sync_service.dart  # Android sync via Drive appDataFolder
│   ├── icloud_sync_service.dart        # iOS/macOS sync via iCloud container
│   └── ingredient_parser.dart          # Static parser: "100g Mehl" → {amount, name}
└── theme/
    └── app_theme.dart           # Material 3 light + dark themes, Inter font

assets/
└── images/
    └── app_logo.png             # Used in AppBar, About screen, empty-state placeholder

test/
├── recipe_bloc_test.dart        # Unit tests for RecipeBloc (mocktail)
└── ingredient_parser_test.dart  # Unit tests for IngredientParser
```

---

## Models

All models are Hive-serialized. Type IDs are **permanent** — changing them corrupts existing data.

| Class        | typeId | Box name     | Key fields |
|--------------|--------|--------------|------------|
| `Ingredient` | 0      | (embedded)   | name, amount, group? |
| `Folder`     | 1      | `folders`    | id (UUID), name, color (hex string) |
| `Recipe`     | 2      | `recipes_v2` | id (UUID), title, ingredients, instructions, folderId?, labels, createdAt, imagePath?, servings?, prepTime?, cookTime? |
| `Instruction`| 3      | (embedded)   | description, group?, photoPath? |

`Ingredient` and `Instruction` are always embedded inside a `Recipe` — they are never stored in their own Hive box. `group` is used to render section headers both in the detail view and the edit form.

`imagePath` stores an absolute local path (inside `getApplicationDocumentsDirectory()`). Sync services strip it to just the filename for transport.

---

## Repositories

### `RecipeRepository`
- Opens the `recipes_v2` Hive box.
- Seeds a default recipe ("Orangen-Schokoladen-Plätzchen") on first run if the box is empty.
- Selects a `SyncService` at startup based on platform: `ICloudSyncService` on iOS/macOS, `GoogleDriveSyncService` on Android.
- Exposes `onSyncCompleted` as a `Stream<DateTime>` (broadcast). Emitted after every add/update/delete if sync is enabled, and after both `syncFromCloud()` and `syncToCloud()` complete.
- `syncFromCloud()` is destructive: clears the entire local box before writing cloud data.
- `_isSyncEnabled` is in-memory only; sync preference is persisted by `SettingsBloc` in the `settings` Hive box.

### `FolderRepository`
- Opens the `folders` Hive box.
- Plain CRUD: `getFolders`, `addFolder`, `updateFolder`, `deleteFolder`, `clearAll`.

---

## State Management (BLoC)

All three BLoCs are instantiated in `main.dart` and provided globally via `MultiBlocProvider`. They can be accessed from anywhere in the widget tree.

### `RecipeBloc`

```
Events:   LoadRecipes | AddRecipe(recipe) | UpdateRecipe(recipe) | DeleteRecipe(id)
States:   RecipeInitial → RecipeLoading → RecipeLoaded(recipes) | RecipeError(message)
```

- Every mutating event (Add/Update/Delete) calls `add(LoadRecipes())` on itself after completing, so the UI always reflects persisted state.
- Subscribes to `RecipeRepository.onSyncCompleted` → fires `LoadRecipes()` automatically when a sync finishes.

### `FolderBloc`

```
Events:   LoadFolders | AddFolder(folder) | UpdateFolder(folder) | DeleteFolder(id)
States:   FolderInitial → FolderLoading → FolderLoaded(folders) | FolderError(message)
```

Same self-reload pattern as `RecipeBloc`.

### `SettingsBloc`

```
Events:   LoadSettings | UpdateThemeMode(mode) | ToggleSync(bool)
          UpdateLastSyncDate(date) | TriggerPushSync | TriggerPullSync
States:   SettingsState { themeMode, isSyncEnabled, lastSyncDate, syncStatus, syncErrorMessage }
SyncStatus enum: idle | loading | success | failure
```

- Persists `theme_mode` (int), `sync_enabled` (bool), `last_sync_date` (int ms) in the Hive `settings` box.
- On `ToggleSync(true)`: calls `RecipeRepository.enableSync()` → which calls `SyncService.init()` then `syncFromCloud()`.
- On toggle failure: forces `isSyncEnabled = false` regardless of what the user set.
- Subscribes to `RecipeRepository.onSyncCompleted` → updates `lastSyncDate` in state and persists it.
- `syncErrorMessage` is passed as `null` (not `??`-chained) in `copyWith` to allow clearing the error.

---

## Routing

Defined in `lib/router.dart` using go_router. `MainScreen` is reused as the shell for multiple routes.

```
/                       → MainScreen(initialTab: 0)           # Recipe list
/settings               → MainScreen(initialTab: 1)           # Settings list
/settings/theme         → ThemeSettingsScreen
/settings/about         → AboutSettingsScreen
/recipe/new             → RecipeEditScreen()                  # Create
/recipe/:id             → MainScreen(selectedRecipeId: id)    # Detail (via shell)
/recipe/:id/edit        → RecipeEditScreen(recipeId: id)      # Edit
```

`HomeScreen` is imported in `router.dart` but not used as a route — it's rendered inside `MainScreen`.

---

## Screens

### `MainScreen`
The root shell for all navigation. Manages `_selectedIndex` (tab) and `_selectedRecipeId`.

**Mobile layout** (`width < 600`):
- If `_selectedRecipeId != null`, shows `RecipeDetailScreen` full-screen.
- Otherwise `IndexedStack` with `HomeScreen` or `SettingsScreen` at the current tab index.

**Desktop layout** (`width >= 600`):
- 300px fixed left pane: `RecipeList` (recipes tab) or `SettingsList` (settings tab).
- Expanded right pane: `RecipeDetailScreen`, theme/about content, or a logo placeholder.

### `HomeScreen`
AppBar with logo + search icon (search not yet implemented), `RecipeList` in body, FAB navigates to `/recipe/new`.

### `RecipeDetailScreen`
- Looks up the recipe by `recipeId` from `RecipeBloc` state.
- `showBackButton` parameter controls whether the default back arrow appears (false on desktop).
- `onBack` callback allows `MainScreen` to clear `_selectedRecipeId` instead of popping the route.
- Renders grouped ingredients and numbered grouped instructions.

### `RecipeEditScreen`
- Stateful form. On open, loads recipe into `_uiIngredients` / `_uiInstructions` via the `ListItem` intermediary model.
- `_editingItemId` tracks which item has the inline text editor open.
- `_buildInlineEditor` for `IngredientItem`: the text field accepts a free-form string like "100g Mehl" and runs it through `IngredientParser.parse()` on confirm.
- Swipe left → delete, swipe right → edit. Drag handle → reorder.
- Long-press on the add button → adds a group `HeaderItem`.
- Image picker copies file to `appDocDir` under a UUID filename.
- Folder creation dialog dispatches `AddFolder` to `FolderBloc`.

### `SettingsScreen`
- `BlocListener` shows SnackBars for `SyncStatus.loading/success/failure`.
- The loading SnackBar has `duration: Duration(days: 1)` (effectively infinite) and is dismissed when the next status arrives.

### `ThemeSettingsScreen` / `AboutSettingsScreen`
Thin wrappers that add a Scaffold + AppBar around `ThemeSelector` and `AboutView` respectively.

---

## Widgets

| Widget | File | Notes |
|--------|------|-------|
| `RecipeList` | `home_screen.dart` | `BlocBuilder<RecipeBloc>`, optional `onRecipeSelected` callback for desktop |
| `_RecipeCard` | `home_screen.dart` | Private; card with optional cover image + label chips |
| `SettingsList` | `settings_screen.dart` | Reused in `MainScreen` desktop right pane; `onTap(String)` callback |
| `ThemeSelector` | `widgets/theme_selector.dart` | RadioListTile × 3; dispatches `UpdateThemeMode` |
| `AboutView` | `widgets/about_view.dart` | Static: logo, name, version string |
| `_AnimatedAddButton` | `recipe_edit_screen.dart` | Private; scale animation on press, calls `onTap` or `onLongPress` |

---

## Services

### `SyncService` (abstract interface)
```dart
Future<void> init();
Future<void> uploadRecipe(Recipe recipe);
Future<void> deleteRecipe(String id);
Future<List<Recipe>> downloadAllRecipes();
Future<bool> isConnected();
Future<void> uploadImage(String imagePath);
Future<String?> downloadImage(String imageName);
```

### `GoogleDriveSyncService` (Android)
- Uses `googleapis` Drive v3 API with the `driveAppdataScope` — data is stored in the app's private `appDataFolder`, invisible to users in Drive UI.
- Auth flow: `GoogleSignIn.instance` → `attemptLightweightAuthentication()` → falls back to `authenticate()` (interactive).
- Each recipe is stored as `<uuid>.json`; images stored by their filename.
- `_getFileId` queries Drive by exact name to determine create-vs-update.
- JSON serialization is manual (no `json_serializable`): `_recipeToJson` / `_recipeFromJson`. `ingredient.group` and `instruction.group` are **not** included in the serialized JSON — they will be lost on sync.

### `ICloudSyncService` (iOS / macOS)
- Uses `icloud_storage` package.
- Container ID is currently `iCloud.com.example.omnomnom` — this is a **placeholder** and must be replaced before iCloud sync works.
- `init()` is a no-op.
- Same JSON schema as Google Drive service, same group-field omission.

### `IngredientParser`
Static utility. `parse(String input)` → `Map<String, String>` with keys `amount` and `name`.

Priority order:
1. Regex: `<quantity> <unit> <name>` — handles ml, g, kg, l, cl, dl, tsp, tbsp, cups, TL, EL, Pkt., Stk., pinch, piece, oz, lb, fl oz, etc. Case-insensitive, supports decimals (`.` or `,`), fractions (`1/2`, `1 1/2`), unicode fractions (`½`, `¾`).
2. Regex: `<quantity> <name>` (no unit, e.g., "2 Eggs").
3. Fallback: entire string is the name, amount is empty.

---

## Data Flow

### App Startup
```
main()
  → Hive.initFlutter(appDocDir)
  → registerAdapter × 4
  → RecipeRepository.init()       # opens box, seeds default recipe, picks SyncService
  → FolderRepository.init()       # opens box
  → runApp(OmnomnomApp)
    → MultiRepositoryProvider
      → MultiBlocProvider
        → RecipeBloc ..add(LoadRecipes())
        → FolderBloc ..add(LoadFolders())
        → SettingsBloc ..add(LoadSettings())   # reads theme + sync pref from Hive,
                                               # calls enableSync/disableSync on repo
          → BlocBuilder<SettingsBloc> → MaterialApp.router (themeMode live-bound)
```

### Recipe CRUD
```
User taps save in RecipeEditScreen
  → RecipeBloc.add(AddRecipe / UpdateRecipe)
    → RecipeRepository.addRecipe(recipe)
      → Hive box.put(recipe.id, recipe)
      → if syncEnabled: SyncService.uploadRecipe() + uploadImage()
      → onSyncCompleted.add(DateTime.now())
    → RecipeBloc.add(LoadRecipes())      # self-reload
    → RecipeBloc: RecipeLoaded(updatedList)
    → RecipeBloc also hears onSyncCompleted → add(LoadRecipes()) [duplicate, harmless]
```

### Sync Toggle On
```
User enables Cloud Sync toggle
  → _showSyncConfirmationDialog → confirmed
  → SettingsBloc.add(ToggleSync(true))
    → emit(syncStatus: loading)
    → Hive settings box: sync_enabled = true
    → RecipeRepository.enableSync()
      → SyncService.init()               # Google: OAuth flow; iCloud: no-op
      → RecipeRepository.syncFromCloud()
        → SyncService.downloadAllRecipes()
        → SyncService.downloadImage() for each recipe
        → Hive box.clear()
        → Hive box.put() for each cloud recipe
        → onSyncCompleted.add(now)
    → emit(isSyncEnabled: true, syncStatus: success)
    → SettingsBloc hears onSyncCompleted → UpdateLastSyncDate
    → RecipeBloc hears onSyncCompleted → LoadRecipes
```

### Theme Change
```
User selects theme option in ThemeSelector
  → SettingsBloc.add(UpdateThemeMode(mode))
    → Hive settings box: theme_mode = mode.index
    → emit(themeMode: mode)
      → BlocBuilder<SettingsBloc> in main.dart rebuilds MaterialApp.router
        → themeMode updated instantly, no navigation needed
```

---

## Edit Screen: ListItem Pattern

`RecipeEditScreen` never mutates `Ingredient` / `Instruction` directly. It uses an intermediate flat list of `ListItem` subclasses (defined in `edit_screen_helpers.dart`):

```
ListItem (abstract, has UUID id + ValueKey)
  ├── HeaderItem(name)                  → renders as group section header
  ├── IngredientItem(name, amount)      → renders as ingredient row
  └── InstructionItem(description, photoPath?)  → renders as instruction row
```

The flat list interleaves `HeaderItem`s with content items. On save, `_saveRecipe()` iterates the list, tracking the last-seen `HeaderItem` as the current `group` for subsequent content items.

On load, the reverse: `recipe.ingredients` are iterated, injecting a `HeaderItem` whenever `ingredient.group` changes.

---

## Image Handling

1. User picks image via `ImagePicker.pickImage(source: ImageSource.gallery)`.
2. File is copied to `getApplicationDocumentsDirectory()` with a UUID filename (preserving extension).
3. `recipe.imagePath` stores the **absolute path** to this copy.
4. On cloud upload, the filename only (`.split('/').last`) is sent as `imagePath` in JSON.
5. On cloud download, `imagePath` in JSON is just the filename. `RecipeRepository.syncFromCloud()` calls `SyncService.downloadImage(filename)` which downloads to `appDocDir/<filename>` and stores the full local path back into the recipe.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_bloc` | ^8.1.3 | BLoC state management |
| `equatable` | ^2.0.7 | Value equality for BLoC events/states |
| `go_router` | ^17.0.0 | Declarative routing |
| `hive` | ^2.2.3 | Local NoSQL database |
| `hive_flutter` | ^1.1.0 | Flutter integration for Hive |
| `uuid` | ^4.5.2 | UUID v4 generation for IDs |
| `intl` | ^0.20.2 | Internationalization (available but not yet used) |
| `path_provider` | ^2.1.5 | `getApplicationDocumentsDirectory()` |
| `google_fonts` | ^6.3.2 | Inter font |
| `image_picker` | ^1.2.1 | Camera/gallery image selection |
| `icloud_storage` | ^2.2.0 | iCloud sync (iOS/macOS) |
| `googleapis` | ^15.0.0 | Google Drive API v3 |
| `google_sign_in` | ^7.2.0 | Google OAuth |
| `extension_google_sign_in_as_googleapis_auth` | ^3.0.0 | Bridge: GoogleSignIn → googleapis HTTP client |
| `googleapis_auth` | ^2.0.0 | OAuth2 credentials (transitive) |
| **Dev** | | |
| `hive_generator` | ^2.0.1 | Generates `.g.dart` Hive adapters |
| `build_runner` | ^2.4.13 | Code generation runner |
| `bloc_test` | ^9.1.5 | BLoC unit test helpers |
| `mocktail` | ^1.0.4 | Mock generation |
| `flutter_launcher_icons` | ^0.14.1 | Generates launcher icons from `assets/images/app_logo.png` |
| `flutter_lints` | ^6.0.0 | Lint rules |

`dependency_overrides`: `analyzer: ^8.0.0` — required for `build_runner` compatibility with current Dart SDK.
