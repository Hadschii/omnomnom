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
    await _trySyncUpload(recipe);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
    await _trySyncUpload(recipe);
  }

  Future<void> deleteRecipe(String id) async {
    await _box.delete(id);
    if (_isSyncEnabled && _syncService != null) {
      try {
        await _syncService!.deleteRecipe(id);
        _syncCompletedController.add(DateTime.now());
      } catch (e) {
        print('RecipeRepository: Non-fatal sync error in deleteRecipe: $e');
      }
    }
  }

  // Sync upload that never throws — local write already succeeded.
  Future<void> _trySyncUpload(Recipe recipe) async {
    if (!_isSyncEnabled || _syncService == null) return;
    try {
      await _syncService!.uploadRecipe(recipe);
      if (recipe.imagePath != null) {
        await _syncService!.uploadImage(recipe.imagePath!);
      }
      _syncCompletedController.add(DateTime.now());
    } catch (e) {
      print('RecipeRepository: Non-fatal sync error uploading ${recipe.id}: $e');
    }
  }

  Future<void> removeFolderIdFromRecipes(String folderId) async {
    final recipes = getRecipes();
    for (final recipe in recipes) {
      if (recipe.folderId == folderId) {
        final updatedRecipe = Recipe(
          id: recipe.id,
          title: recipe.title,
          ingredients: recipe.ingredients,
          instructions: recipe.instructions,
          folderId: null,
          labels: recipe.labels,
          createdAt: recipe.createdAt,
          imagePath: recipe.imagePath,
          servings: recipe.servings,
          prepTime: recipe.prepTime,
          cookTime: recipe.cookTime,
        );
        await updateRecipe(updatedRecipe);
      }
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
    if (_syncService == null) {
      throw Exception('Sync service is not initialized');
    }

    try {
      print('RecipeRepository: Downloading recipes from cloud...');
      // 1. Download all recipes first (if this fails, the local DB is untouched)
      final cloudRecipes = await _syncService!.downloadAllRecipes();
      print('RecipeRepository: Downloaded ${cloudRecipes.length} recipes from cloud');

      // 2. Download and map images for recipes (if any download fails, local DB is still untouched)
      final Map<String, String> downloadedImages = {};
      final Map<String, Map<int, String>> downloadedInstructionImages = {};
      for (final recipe in cloudRecipes) {
        if (recipe.imagePath != null && recipe.imagePath!.isNotEmpty) {
          try {
            print('RecipeRepository: Downloading image for recipe ${recipe.title}: ${recipe.imagePath}');
            final localImagePath = await _syncService!.downloadImage(recipe.imagePath!);
            if (localImagePath != null) {
              downloadedImages[recipe.id] = localImagePath;
            }
          } catch (e) {
            print('RecipeRepository: Non-fatal error downloading image for ${recipe.title}: $e');
            // Do not fail the whole sync if a single image fails to download
          }
        }

        for (int i = 0; i < recipe.instructions.length; i++) {
          final instruction = recipe.instructions[i];
          if (instruction.photoPath != null && instruction.photoPath!.isNotEmpty) {
            try {
              print('RecipeRepository: Downloading image for instruction $i of recipe ${recipe.title}: ${instruction.photoPath}');
              final localImagePath = await _syncService!.downloadImage(instruction.photoPath!);
              if (localImagePath != null) {
                downloadedInstructionImages.putIfAbsent(recipe.id, () => {})[i] = localImagePath;
              }
            } catch (e) {
              print('RecipeRepository: Non-fatal error downloading instruction image for ${recipe.title}: $e');
            }
          }
        }
      }

      // 3. Wiping local and writing new data inside a safe local block
      // At this stage, all remote data has been successfully fetched.
      print('RecipeRepository: Committing downloaded data to local store...');
      await _box.clear();
      for (final recipe in cloudRecipes) {
        final localImagePath = downloadedImages[recipe.id];
        
        final updatedInstructions = <Instruction>[];
        final recipeInstImages = downloadedInstructionImages[recipe.id];
        for (int i = 0; i < recipe.instructions.length; i++) {
          final inst = recipe.instructions[i];
          final localInstPhotoPath = recipeInstImages?[i];
          updatedInstructions.add(Instruction(
            description: inst.description,
            group: inst.group,
            photoPath: localInstPhotoPath ?? inst.photoPath,
          ));
        }

        final updatedRecipe = Recipe(
          id: recipe.id,
          title: recipe.title,
          ingredients: recipe.ingredients,
          instructions: updatedInstructions,
          folderId: recipe.folderId,
          labels: recipe.labels,
          createdAt: recipe.createdAt,
          imagePath: localImagePath ?? recipe.imagePath,
          servings: recipe.servings,
          prepTime: recipe.prepTime,
          cookTime: recipe.cookTime,
        );
        await _box.put(updatedRecipe.id, updatedRecipe);
      }
      
      final now = DateTime.now();
      _syncCompletedController.add(now);
      print('RecipeRepository: Pull sync completed successfully');
    } catch (e) {
      print('RecipeRepository: Error during pull sync: $e');
      rethrow; // Propagate exception to calling BLoC
    }
  }

  Future<void> syncToCloud() async {
    if (_syncService == null) {
      throw Exception('Sync service is not initialized');
    }
    
    try {
      print('RecipeRepository: Uploading local recipes to cloud...');
      final localRecipes = _box.values.toList();
      for (final recipe in localRecipes) {
        await _syncService!.uploadRecipe(recipe);
        if (recipe.imagePath != null && recipe.imagePath!.isNotEmpty) {
          await _syncService!.uploadImage(recipe.imagePath!);
        }
        for (final instruction in recipe.instructions) {
          if (instruction.photoPath != null && instruction.photoPath!.isNotEmpty) {
            await _syncService!.uploadImage(instruction.photoPath!);
          }
        }
      }
      _syncCompletedController.add(DateTime.now());
      print('RecipeRepository: Push sync completed successfully');
    } catch (e) {
      print('RecipeRepository: Error during push sync: $e');
      rethrow; // Propagate exception to calling BLoC
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
