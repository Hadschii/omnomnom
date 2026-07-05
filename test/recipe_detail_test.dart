import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/blocs/settings/settings_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/settings/settings_event.dart';
import 'package:omnomnom_recipe_app/blocs/settings/settings_state.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_event.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_state.dart';
import 'package:omnomnom_recipe_app/models/ingredient.dart';
import 'package:omnomnom_recipe_app/models/instruction.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/screens/recipe_detail_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockTagBloc extends MockBloc<TagEvent, TagState> implements TagBloc {}

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

/// RecipeDetailScreen reads TagBloc for tag pills/picker and SettingsBloc for
/// the accent-from-photo toggle; every pump needs both in the tree.
List<BlocProvider> _extraProviders() {
  final tagBloc = MockTagBloc();
  whenListen(tagBloc, const Stream<TagState>.empty(),
      initialState: const TagLoaded([]));
  final settingsBloc = MockSettingsBloc();
  whenListen(settingsBloc, const Stream<SettingsState>.empty(),
      initialState: const SettingsState());
  return [
    BlocProvider<TagBloc>.value(value: tagBloc),
    BlocProvider<SettingsBloc>.value(value: settingsBloc),
  ];
}

void main() {
  setUpAll(() => registerFallbackValue(LoadRecipes()));

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
        home: MultiBlocProvider(
          providers: [
            BlocProvider<RecipeBloc>.value(value: bloc),
            ..._extraProviders(),
          ],
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

  testWidgets('delete flow confirms and emits DeleteRecipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([recipe]));
    var backCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<RecipeBloc>.value(value: bloc),
            ..._extraProviders(),
          ],
          child: RecipeDetailScreen(
            recipeId: 'r1',
            showBackButton: false,
            onBack: () => backCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete recipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete')); // confirm
    await tester.pumpAndSettle();

    final captured = verify(() => bloc.add(captureAny())).captured;
    expect(captured.whereType<DeleteRecipe>().single.id, 'r1');
    expect(backCalled, isTrue);
  });
}
