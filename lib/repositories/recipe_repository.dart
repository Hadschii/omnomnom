import 'dart:io';
import 'dart:async'; // Added for StreamController
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../services/sync_service.dart';
import '../services/icloud_sync_service.dart';
import '../services/google_drive_sync_service.dart';

class RecipeRepository {
  static const String _boxName = 'recipes_v2';
  SyncService? _syncService;
  bool _isSyncEnabled = false; // TODO: Persist this preference

  // Added for sync completion events
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
    
    // TODO: Load sync enabled state from preferences
    if (_isSyncEnabled && _syncService != null) {
      await _syncService!.init();
    }
  }

  Box<Recipe> get _box => Hive.box<Recipe>(_boxName);

  List<Recipe> getRecipes() {
    return _box.values.toList();
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
    if (_isSyncEnabled && _syncService != null) {
      await _syncService!.uploadRecipe(recipe);
      if (recipe.imagePath != null) {
        await _syncService!.uploadImage(recipe.imagePath!);
      }
      _syncCompletedController.add(DateTime.now()); // Emit event
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
    if (_isSyncEnabled && _syncService != null) {
      await _syncService!.uploadRecipe(recipe);
      if (recipe.imagePath != null) {
        await _syncService!.uploadImage(recipe.imagePath!);
      }
      _syncCompletedController.add(DateTime.now()); // Emit event
    }
  }

  Future<void> deleteRecipe(String id) async {
    await _box.delete(id);
    if (_isSyncEnabled && _syncService != null) {
      await _syncService!.deleteRecipe(id);
      _syncCompletedController.add(DateTime.now()); // Emit event
    }
  }

  // Helper to clear all recipes (useful for testing/debugging)
  Future<void> clearAll() async {
    await _box.clear();
  }

  // Sync methods
  Future<void> enableSync() async {
    _isSyncEnabled = true;
    // TODO: Save preference
    if (_syncService != null) {
      await _syncService!.init();
      await syncFromCloud();
    }
  }

  Future<void> disableSync() async {
    _isSyncEnabled = false;
    // TODO: Save preference
  }

  bool get isSyncEnabled => _isSyncEnabled;

  Future<void> syncFromCloud() async {
    if (_syncService == null) return;

    final cloudRecipes = await _syncService!.downloadAllRecipes();
    
    // Overwrite local data as per AC
    await _box.clear();
    for (final recipe in cloudRecipes) {
      await _box.put(recipe.id, recipe);
      if (recipe.imagePath != null) {
        // Download image if needed
        final localImagePath = await _syncService!.downloadImage(recipe.imagePath!);
        if (localImagePath != null) {
           // Update recipe with local path if needed (though we store filename in cloud, local path might vary)
           // Actually, the downloadImage returns the local path. 
           // We might need to update the recipe object if we stored just the filename in the cloud but need full path locally.
           // But for now, let's assume the model holds the filename or relative path, or we update it here.
           // The _recipeFromJson in SyncService sets imagePath to filename. 
           // We should probably update it to the full local path here if the app expects full path.
           // Let's check how the app uses imagePath.
           // Assuming it expects a file path.
           final updatedRecipe = Recipe(
             id: recipe.id,
             title: recipe.title,
             ingredients: recipe.ingredients,
             instructions: recipe.instructions,
             folderId: recipe.folderId,
             labels: recipe.labels,
             createdAt: recipe.createdAt,
             imagePath: localImagePath,
             servings: recipe.servings,
             prepTime: recipe.prepTime,
             cookTime: recipe.cookTime,
           );
           await _box.put(recipe.id, updatedRecipe);
        }
      }
    }
    _syncCompletedController.add(DateTime.now());
  }

  Future<void> syncToCloud() async {
    if (_syncService == null) return;
    
    final localRecipes = _box.values.toList();
    for (final recipe in localRecipes) {
      await _syncService!.uploadRecipe(recipe);
      if (recipe.imagePath != null) {
        await _syncService!.uploadImage(recipe.imagePath!);
      }
    }
  }

  Future<void> _seedDefaultRecipes() async {
    if (_box.isNotEmpty) return;

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
