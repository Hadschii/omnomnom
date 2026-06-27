import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_event.dart';
import 'package:omnomnom_recipe_app/blocs/tag/tag_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/models/tag.dart';
import 'package:omnomnom_recipe_app/screens/tags_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockTagBloc extends MockBloc<TagEvent, TagState> implements TagBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(LoadRecipes());
    registerFallbackValue(LoadTags());
  });

  Recipe recipe(String id, List<String> labels) => Recipe(
        id: id,
        title: 'R$id',
        ingredients: const [],
        instructions: const [],
        labels: labels,
        createdAt: DateTime(2026, 6, 26),
      );

  Future<void> pump(
    WidgetTester tester, {
    required MockTagBloc tagBloc,
    required MockRecipeBloc recipeBloc,
    required List<Tag> tags,
    required List<Recipe> recipes,
  }) async {
    whenListen(tagBloc, const Stream<TagState>.empty(),
        initialState: TagLoaded(tags));
    whenListen(recipeBloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded(recipes));
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<TagBloc>.value(value: tagBloc),
          BlocProvider<RecipeBloc>.value(value: recipeBloc),
        ],
        child: const TagsScreen(),
      ),
    ));
    await tester.pump();
  }

  testWidgets('merges registered tags with tags used on recipes',
      (tester) async {
    await pump(
      tester,
      tagBloc: MockTagBloc(),
      recipeBloc: MockRecipeBloc(),
      tags: [Tag(id: 't1', name: 'Weeknight', color: 0xFFF69021)],
      recipes: [recipe('1', ['Weeknight', 'Spicy'])],
    );
    expect(find.text('Weeknight'), findsOneWidget); // registered + used
    expect(find.text('Spicy'), findsOneWidget); // used only
    expect(find.text('2 tags · used to filter recipes'), findsOneWidget);
  });

  testWidgets('removing a tag strips its label from recipes', (tester) async {
    final recipeBloc = MockRecipeBloc();
    await pump(
      tester,
      tagBloc: MockTagBloc(),
      recipeBloc: recipeBloc,
      tags: const [],
      recipes: [recipe('1', ['Spicy'])],
    );
    await tester.tap(find.byIcon(Icons.remove)); // the only tag row
    await tester.pump();

    final captured = verify(() => recipeBloc.add(captureAny())).captured;
    final update = captured.whereType<UpdateRecipe>().first;
    expect(update.recipe.labels, isNot(contains('Spicy')));
  });

  testWidgets('adding a tag registers it', (tester) async {
    final tagBloc = MockTagBloc();
    await pump(
      tester,
      tagBloc: tagBloc,
      recipeBloc: MockRecipeBloc(),
      tags: const [],
      recipes: const [],
    );
    await tester.tap(find.text('New tag…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Quick');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured = verify(() => tagBloc.add(captureAny())).captured;
    expect(captured.whereType<AddTag>().first.tag.name, 'Quick');
  });
}
