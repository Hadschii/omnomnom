import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/screens/home_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

void main() {
  Recipe sample() => Recipe(
        id: '1',
        title: 'Chicken Paprika Noodles',
        ingredients: const [],
        instructions: const [],
        labels: const ['Weeknight'],
        createdAt: DateTime(2026, 6, 26),
        servings: 2,
        prepTime: 15,
        cookTime: 20,
      );

  Future<void> pumpList(WidgetTester tester, RecipeState state) async {
    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(), initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RecipeBloc>.value(
          value: bloc,
          child: const Scaffold(body: RecipeList(showLargeTitle: true)),
        ),
      ),
    );
  }

  testWidgets('card shows title, derived total time, servings and first tag',
      (tester) async {
    await pumpList(tester, RecipeLoaded([sample()]));

    expect(find.text('Recipes'), findsOneWidget); // large title header
    expect(find.text('Chicken Paprika Noodles'), findsOneWidget);
    expect(find.text('2 servings'), findsOneWidget);
    expect(find.text('35 min'), findsOneWidget); // prep 15 + cook 20
    expect(find.text('Weeknight'), findsOneWidget); // first label
  });

  testWidgets('empty library shows the empty state', (tester) async {
    await pumpList(tester, const RecipeLoaded([]));
    expect(find.text('No recipes yet'), findsOneWidget);
  });
}
