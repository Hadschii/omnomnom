import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/services/recipe_codec.dart';

void main() {
  test('recipeFromJson(recipeToJson(r)) preserves every field', () {
    final recipe = Recipe(
      id: 'r1',
      title: 'Chicken Paprika Noodles',
      ingredients: [
        Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce'),
      ],
      instructions: [
        Instruction(
          description: 'Simmer to thicken.',
          group: 'Sauce',
          groups: ['Sauce', 'Mains'],
          timerSeconds: 300,
          photoPath: '/tmp/step.jpg',
        ),
      ],
      labels: ['Weeknight'],
      createdAt: DateTime(2026, 6, 26),
      imagePath: '/tmp/cover.jpg',
      servings: 2,
      prepTime: 10,
      cookTime: 20,
      bookIds: ['book-a', 'book-b'],
      accentColor: 0xFFC0492E,
    );

    final roundTripped = recipeFromJson(recipeToJson(recipe));

    expect(roundTripped.id, recipe.id);
    expect(roundTripped.title, recipe.title);
    expect(roundTripped.labels, recipe.labels);
    expect(roundTripped.createdAt, recipe.createdAt);
    expect(roundTripped.servings, recipe.servings);
    expect(roundTripped.prepTime, recipe.prepTime);
    expect(roundTripped.cookTime, recipe.cookTime);
    expect(roundTripped.bookIds, recipe.bookIds);
    expect(roundTripped.accentColor, recipe.accentColor);

    final step = roundTripped.instructions.single;
    expect(step.description, 'Simmer to thicken.');
    expect(step.groups, ['Sauce', 'Mains']);
    expect(step.timerSeconds, 300);

    final ing = roundTripped.ingredients.single;
    expect(ing.name, 'Milk');
    expect(ing.amount, '100 ml');
    expect(ing.group, 'Sauce');
  });

  test('missing optional fields decode to null, not throw', () {
    final recipe = Recipe(
      id: 'r2',
      title: 'Minimal',
      ingredients: const [],
      instructions: const [],
      labels: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final roundTripped = recipeFromJson(recipeToJson(recipe));

    expect(roundTripped.bookIds, isNull);
    expect(roundTripped.accentColor, isNull);
    expect(roundTripped.imagePath, isNull);
  });
}
