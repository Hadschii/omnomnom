import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/repositories/recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('omnomnom_repo');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(IngredientAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(InstructionAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RecipeAdapter());
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
    dir.deleteSync(recursive: true);
  });

  Recipe make(String id, String title) => Recipe(
        id: id,
        title: title,
        ingredients: const [],
        instructions: const [],
        labels: const [],
        createdAt: DateTime(2026, 6, 26),
      );

  test('init seeds a default recipe, then add/update/delete persist',
      () async {
    final repo = RecipeRepository();
    await repo.init();

    // init() seeds one default recipe into a fresh box.
    expect(repo.getRecipes().length, 1);

    // add
    await repo.addRecipe(make('x', 'Test'));
    expect(repo.getRecipes().any((r) => r.id == 'x'), isTrue);

    // update
    await repo.updateRecipe(make('x', 'Renamed'));
    expect(repo.getRecipes().firstWhere((r) => r.id == 'x').title, 'Renamed');

    // delete
    await repo.deleteRecipe('x');
    expect(repo.getRecipes().any((r) => r.id == 'x'), isFalse);
    expect(repo.getRecipes().length, 1); // seed still there
  });
}
