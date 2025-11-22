import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';

class RecipeRepository {
  static const String _boxName = 'recipes_v2';

  Future<void> init() async {
    await Hive.openBox<Recipe>(_boxName);
    await _seedDefaultRecipes();
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
