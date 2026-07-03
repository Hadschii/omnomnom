import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../services/sync_service.dart';
import '../services/icloud_sync_service.dart';
import '../services/google_drive_sync_service.dart';

class RecipeRepository {
  static const String _boxName = 'recipes_v2';
  static const String _metaBoxName = 'recipe_repo_meta';
  static const String _seededKey = 'seeded_default_recipes';
  SyncService? _syncService;
  // The persisted value of this flag lives in SettingsBloc's Hive box
  // (`sync_enabled` key); SettingsBloc calls enableSync()/disableSync() on
  // load to bring this in sync with the stored preference.
  bool _isSyncEnabled = false;

  final _syncCompletedController = StreamController<DateTime>.broadcast();
  Stream<DateTime> get onSyncCompleted => _syncCompletedController.stream;

  Future<void> init() async {
    await Hive.openBox<Recipe>(_boxName);
    await _seedDefaultRecipes();

    // Initialize Sync Service based on platform
    if (Platform.isIOS || Platform.isMacOS) {
      _syncService = ICloudSyncService();
    } else if (Platform.isAndroid) {
      _syncService = GoogleDriveSyncService();
    }
  }

  Box<Recipe> get _box => Hive.box<Recipe>(_boxName);

  List<Recipe> getRecipes() {
    return _box.values.toList();
  }

  /// Runs a cloud-sync side effect best-effort. The local write has already
  /// happened by the time this is called, so a sync failure (e.g. iCloud not
  /// configured — a placeholder container id, or the user not signed in) must
  /// never fail the local operation. Failures are logged, not thrown.
  Future<void> _trySync(Future<void> Function() op) async {
    if (!_isSyncEnabled || _syncService == null) return;
    try {
      await op();
      _syncCompletedController.add(DateTime.now());
    } catch (e) {
      log('cloud sync skipped (non-fatal)', name: 'RecipeRepository', error: e);
    }
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
    await _trySync(() => _uploadRecipeAndImages(recipe));
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
    await _trySync(() => _uploadRecipeAndImages(recipe));
  }

  /// Uploads the recipe JSON plus its cover photo and every step photo. The
  /// per-step photos were previously left out entirely, so a downloaded
  /// recipe would reference step images that never made it to the cloud.
  Future<void> _uploadRecipeAndImages(Recipe recipe) async {
    await _syncService!.uploadRecipe(recipe);
    if (recipe.imagePath != null) {
      await _syncService!.uploadImage(recipe.imagePath!);
    }
    for (final step in recipe.instructions) {
      if (step.photoPath != null) {
        await _syncService!.uploadImage(step.photoPath!);
      }
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _box.delete(id);
    await _trySync(() => _syncService!.deleteRecipe(id));
  }

  // Helper to clear all recipes (useful for testing/debugging)
  Future<void> clearAll() async {
    await _box.clear();
  }

  // Sync methods. The enabled/disabled preference itself is persisted by
  // SettingsBloc, which calls these on every app launch to restore state.
  Future<void> enableSync() async {
    _isSyncEnabled = true;
    if (_syncService != null) {
      await _syncService!.init();
      await syncFromCloud();
    }
  }

  Future<void> disableSync() async {
    _isSyncEnabled = false;
  }

  bool get isSyncEnabled => _isSyncEnabled;

  /// Pulls every recipe from the cloud and merges it into the local box.
  ///
  /// This intentionally never clears the local box first: recipes created
  /// locally since the last upload — which the cloud doesn't know about yet —
  /// would otherwise be permanently deleted by a pull. Only recipe IDs that
  /// exist in the cloud set are overwritten; anything local-only survives.
  /// This is a stopgap until entities carry `updatedAt`/tombstones and a
  /// proper last-write-wins merge can be done (see the sync plan doc).
  Future<void> syncFromCloud() async {
    if (_syncService == null) {
      throw Exception('Sync service is not initialized');
    }

    final cloudRecipes = await _syncService!.downloadAllRecipes();

    for (final recipe in cloudRecipes) {
      final resolved = await _resolveRecipeImages(recipe);
      await _box.put(resolved.id, resolved);
    }

    _syncCompletedController.add(DateTime.now());
  }

  /// Downloads the cover photo and every step photo for a recipe just pulled
  /// from the cloud, replacing each remote basename with the resulting local
  /// path. A failed image download is non-fatal — the recipe still syncs,
  /// just without that photo.
  Future<Recipe> _resolveRecipeImages(Recipe recipe) async {
    Future<String?> resolve(String? remotePath) async {
      if (remotePath == null || remotePath.isEmpty) return null;
      try {
        return await _syncService!.downloadImage(remotePath);
      } catch (_) {
        return null;
      }
    }

    final imagePath = await resolve(recipe.imagePath) ?? recipe.imagePath;
    final instructions = <Instruction>[];
    for (final step in recipe.instructions) {
      final photoPath = await resolve(step.photoPath) ?? step.photoPath;
      instructions.add(Instruction(
        description: step.description,
        group: step.group,
        groups: step.groups,
        timerSeconds: step.timerSeconds,
        photoPath: photoPath,
      ));
    }
    return recipe.copyWith(imagePath: imagePath, instructions: instructions);
  }

  Future<void> syncToCloud() async {
    if (_syncService == null) {
      throw Exception('Sync service is not initialized');
    }

    for (final recipe in _box.values) {
      await _uploadRecipeAndImages(recipe);
    }
    _syncCompletedController.add(DateTime.now());
  }

  /// Seeds the sample recipe on a genuinely fresh install only. Without the
  /// one-shot flag, a user who deletes every recipe would get the sample
  /// recipe back on next launch, since "seed if the box is empty" can't tell
  /// a fresh install apart from an intentionally emptied library.
  Future<void> _seedDefaultRecipes() async {
    final metaBox = await Hive.openBox(_metaBoxName);
    if (metaBox.get(_seededKey, defaultValue: false) == true) return;
    if (_box.isNotEmpty) {
      // Pre-existing data from before this flag was introduced.
      await metaBox.put(_seededKey, true);
      return;
    }
    await metaBox.put(_seededKey, true);

    final defaultRecipe = Recipe(
      id: 'default_orange_chocolate_cookies',
      title: 'Orangen - Schokoladen - Plätzchen',
      ingredients: [
        Ingredient(name: 'Mehl', amount: '200 g'),
        Ingredient(name: 'Speisestärke', amount: '60 g'),
        Ingredient(name: 'Backpulver', amount: '1 TL, gestr.'),
        Ingredient(name: 'Zucker', amount: '100 g'),
        Ingredient(name: 'Vanillezucker', amount: '1 Pkt.'),
        Ingredient(name: 'Aroma (Orange back) oder abgeriebene Schale einer Orange', amount: '1 Pkt.'),
        Ingredient(name: 'Ei(er)', amount: '1'),
        Ingredient(name: 'Butter', amount: '125 g'),
        Ingredient(name: 'Schokolade zartbitter', amount: '100 g'),
      ],
      instructions: [
        Instruction(description: 'Das Mehl mit Speisestärke und Backpulver mischen, in eine Rührschüssel sieben.'),
        Instruction(description: 'Zucker, Vanillezucker, Orangenschale, Ei und Butter hinzufügen.'),
        Instruction(description: 'Die Zutaten mit dem Handrührgerät mit Knethaken zunächst kurz auf niedrigster, dann auf höchster Stufe gut durcharbeiten.'),
        Instruction(description: 'Die Schokolade in kleine Stücke schneiden, kurz auf mittlerer Stufe unterkneten, anschließend alles auf der Arbeitsfläche zu einem glatten Teig verkneten.'),
        Instruction(description: 'Aus dem Teig 3 etwa 3 cm dicke Rollen formen, breit drücken, so dass die Teigstreifen etwa 5 cm breit und gut 1 cm hoch sind, kalt stellen, bis der Teig hart geworden ist.'),
        Instruction(description: 'Die Teigstreifen mit einem scharfen Messer in knapp 1/2 cm dicke Scheiben schneiden, diese auf ein Backblech legen und im vorgeheizten Ofen bei 180°C (Ober-/Unterhitze) ca. 10 Minuten backen.'),
      ],
      labels: [],
      createdAt: DateTime.now(),
      servings: 1, 
      prepTime: 30, 
      cookTime: 10,
    );

    await _box.put(defaultRecipe.id, defaultRecipe);
  }
}
