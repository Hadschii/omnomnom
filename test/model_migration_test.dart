import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/models/recipe_book.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Instruction.effectiveGroups', () {
    test('falls back to the legacy single group when groups is null', () {
      final i = Instruction(description: 'x', group: 'Sauce');
      expect(i.effectiveGroups, ['Sauce']);
    });

    test('prefers the new multi-group list when present', () {
      final i = Instruction(
        description: 'x',
        group: 'Sauce',
        groups: ['Sauce', 'Mains'],
      );
      expect(i.effectiveGroups, ['Sauce', 'Mains']);
    });

    test('is empty when neither group nor groups is set', () {
      expect(Instruction(description: 'x').effectiveGroups, isEmpty);
    });
  });

  group('Hive adapter round-trips (hand-written .g.dart)', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('omnomnom_test');
      Hive.init(tempDir.path);
      Hive.registerAdapter(IngredientAdapter());
      Hive.registerAdapter(InstructionAdapter());
      Hive.registerAdapter(RecipeAdapter());
      Hive.registerAdapter(RecipeBookAdapter());
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk();
      tempDir.deleteSync(recursive: true);
    });

    test('Recipe persists bookIds and Instruction timer + groups', () async {
      final box = await Hive.openBox<Recipe>('roundtrip_recipes');
      final recipe = Recipe(
        id: 'r1',
        title: 'Chicken Paprika Noodles',
        ingredients: [Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce')],
        instructions: [
          Instruction(
            description: 'Simmer to thicken.',
            group: 'Sauce',
            groups: ['Sauce', 'Mains'],
            timerSeconds: 300,
            photoPath: '/tmp/x.jpg',
          ),
        ],
        labels: ['Weeknight'],
        createdAt: DateTime(2026, 6, 26),
        servings: 2,
        bookIds: ['book-a', 'book-b'],
      );
      await box.put(recipe.id, recipe);
      await box.close();

      final reopened = await Hive.openBox<Recipe>('roundtrip_recipes');
      final loaded = reopened.get('r1')!;
      expect(loaded.bookIds, ['book-a', 'book-b']);
      final step = loaded.instructions.single;
      expect(step.timerSeconds, 300);
      expect(step.groups, ['Sauce', 'Mains']);
      expect(step.effectiveGroups, ['Sauce', 'Mains']);
    });

    test('RecipeBook persists its fields', () async {
      final box = await Hive.openBox<RecipeBook>('roundtrip_books');
      final book = RecipeBook(
        id: 'book-a',
        name: 'Family Recipes',
        coverImagePath: '/tmp/cover.jpg',
        createdAt: DateTime(2026, 6, 26),
      );
      await box.put(book.id, book);
      await box.close();

      final reopened = await Hive.openBox<RecipeBook>('roundtrip_books');
      final loaded = reopened.get('book-a')!;
      expect(loaded.name, 'Family Recipes');
      expect(loaded.coverImagePath, '/tmp/cover.jpg');
    });

    test('legacy Recipe without new fields still reads back (null defaults)',
        () async {
      final box = await Hive.openBox<Recipe>('roundtrip_legacy');
      final legacy = Recipe(
        id: 'old',
        title: 'Old Recipe',
        ingredients: const [],
        instructions: [Instruction(description: 'step')],
        labels: const [],
        createdAt: DateTime(2026, 1, 1),
      );
      await box.put(legacy.id, legacy);
      await box.close();

      final reopened = await Hive.openBox<Recipe>('roundtrip_legacy');
      final loaded = reopened.get('old')!;
      expect(loaded.bookIds, isNull);
      expect(loaded.instructions.single.timerSeconds, isNull);
      expect(loaded.instructions.single.groups, isNull);
      expect(loaded.instructions.single.effectiveGroups, isEmpty);
    });
  });
}
