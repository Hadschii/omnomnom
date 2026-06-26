import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/screens/recipe_edit_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

void main() {
  setUpAll(() => registerFallbackValue(LoadRecipes()));

  final existing = Recipe(
    id: 'r1',
    title: 'Chicken Paprika Noodles',
    ingredients: [
      Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce'),
    ],
    instructions: [
      Instruction(
        description: 'Simmer the sauce.',
        group: 'Sauce',
        groups: ['Sauce'],
        timerSeconds: 300,
      ),
    ],
    labels: const ['Weeknight'],
    createdAt: DateTime(2026, 6, 26),
    servings: 2,
    prepTime: 20,
    cookTime: 15,
  );

  testWidgets('loads a recipe and Save preserves step timer + groups',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([existing]));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('home'))),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, __) => const RecipeEditScreen(recipeId: 'r1'),
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<RecipeBloc>.value(
        value: bloc,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/edit');
    await tester.pumpAndSettle();

    // Loaded grouped ingredient renders under its group header.
    expect(find.text('SAUCE'), findsOneWidget);

    // Steps tab shows the loaded step with its formatted timer.
    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();
    expect(find.text('5:00'), findsOneWidget);

    // Save and capture the UpdateRecipe the editor emits.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured = verify(() => bloc.add(captureAny())).captured;
    final update = captured.whereType<UpdateRecipe>().first;
    final step = update.recipe.instructions.single;
    expect(step.description, 'Simmer the sauce.');
    expect(step.timerSeconds, 300);
    expect(step.groups, ['Sauce']);
    expect(update.recipe.ingredients.single.group, 'Sauce');
  });
}
