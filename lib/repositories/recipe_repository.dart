import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';

class RecipeRepository {
  static const String _boxName = 'recipes';

  Future<void> init() async {
    await Hive.openBox<Recipe>(_boxName);
  }

  Box<Recipe> get _box => Hive.box<Recipe>(_boxName);

  List<Recipe> getRecipes() {
    return _box.values.toList();
  }

  Future<void> addRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await _box.put(recipe.id, recipe);
  }

  Future<void> deleteRecipe(String id) async {
    await _box.delete(id);
  }

  // Helper to clear all recipes (useful for testing/debugging)
  Future<void> clearAll() async {
    await _box.clear();
  }
}
