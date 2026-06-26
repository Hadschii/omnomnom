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
import 'package:omnomnom_recipe_app/screens/cook_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

void main() {
  final recipe = Recipe(
    id: 'r1',
    title: 'Chicken Paprika Noodles',
    ingredients: [
      Ingredient(name: 'Milk', amount: '100 ml', group: 'Sauce'),
      Ingredient(name: 'Chicken', amount: '200 g', group: 'Mains'),
    ],
    instructions: [
      Instruction(description: 'Sear the chicken.', group: 'Mains'),
      Instruction(
          description: 'Simmer the sauce.', group: 'Sauce', timerSeconds: 300),
    ],
    labels: const [],
    createdAt: DateTime(2026, 6, 26),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([recipe]));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecipeBloc>.value(
          value: bloc,
          child: const CookScreen(recipeId: 'r1'),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('first step marks its group needed now, others from later step',
      (tester) async {
    await pump(tester);
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expect(find.text('MAINS · NEEDED NOW'), findsOneWidget);
    expect(find.text('SAUCE · FROM STEP 2'), findsOneWidget);
  });

  testWidgets('tapping an ingredient checks it off', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.check), findsNothing); // no checks yet on step 1
    await tester.tap(find.text('Chicken'));
    await tester.pump();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('advancing reaches the timed sauce step', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('STEP 2 OF 2'), findsOneWidget);
    expect(find.text('SAUCE · NEEDED NOW'), findsOneWidget);
    expect(find.text('Tap to start 5:00'), findsOneWidget);
  });
}
