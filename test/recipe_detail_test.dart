import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/screens/recipe_detail_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

void main() {
  final recipe = Recipe(
    id: 'r1',
    title: 'Chicken Paprika Noodles',
    ingredients: [
      Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce'),
      Ingredient(name: 'Chicken breast', amount: '200 g', group: 'Mains'),
    ],
    instructions: [
      Instruction(
        description: 'Whisk the milk into the paprika and simmer.',
        group: 'Sauce',
        timerSeconds: 300,
      ),
    ],
    labels: const ['Weeknight'],
    createdAt: DateTime(2026, 6, 26),
    servings: 2,
    prepTime: 20,
    cookTime: 15,
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([recipe]));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecipeBloc>.value(
          value: bloc,
          child: const RecipeDetailScreen(
            recipeId: 'r1',
            showBackButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows hero content and grouped ingredients by default',
      (tester) async {
    await pump(tester);
    expect(find.text('Chicken Paprika Noodles'), findsOneWidget);
    expect(find.text('Start Cooking'), findsOneWidget);
    // Ingredients tab is default: grouped headers + amounts in accent.
    expect(find.text('SAUCE'), findsOneWidget);
    expect(find.text('MAINS'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('100 ml'), findsOneWidget);
  });

  testWidgets('switching to Steps shows the step with its timer',
      (tester) async {
    await pump(tester);
    // Step content not visible while on the Ingredients tab.
    expect(find.text('5:00'), findsNothing);

    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Whisk the milk'), findsOneWidget);
    expect(find.text('5:00'), findsOneWidget); // 300s timer formatted
  });
}
