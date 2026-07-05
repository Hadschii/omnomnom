import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_event.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_state.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/models/recipe_book.dart';
import 'package:omnomnom_recipe_app/screens/book_detail_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockBookBloc extends MockBloc<BookEvent, BookState> implements BookBloc {}

void main() {
  setUpAll(() => registerFallbackValue(LoadRecipes()));

  Recipe recipe(String id, String title, {List<String>? bookIds}) => Recipe(
        id: id,
        title: title,
        ingredients: const [],
        instructions: const [],
        labels: const [],
        createdAt: DateTime(2026, 6, 26),
        bookIds: bookIds,
      );

  final book =
      RecipeBook(id: 'b1', name: 'Family Recipes', createdAt: DateTime(2026, 1, 1));

  Future<void> pump(
    WidgetTester tester, {
    required List<Recipe> recipes,
    required MockRecipeBloc recipeBloc,
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bookBloc = MockBookBloc();
    whenListen(bookBloc, const Stream<BookState>.empty(),
        initialState: BookLoaded([book]));
    whenListen(recipeBloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded(recipes));
    // Providers sit above MaterialApp (as in main.dart) so modal bottom sheets,
    // which build from the root Navigator, can still resolve the blocs.
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider<BookBloc>.value(value: bookBloc),
        BlocProvider<RecipeBloc>.value(value: recipeBloc),
      ],
      child: const MaterialApp(home: BookDetailScreen(bookId: 'b1')),
    ));
    await tester.pump();
  }

  testWidgets('lists the book members and flips to the social tab',
      (tester) async {
    final recipeBloc = MockRecipeBloc();
    await pump(
      tester,
      recipeBloc: recipeBloc,
      recipes: [
        recipe('r1', 'Chicken Paprika Noodles', bookIds: ['b1']),
        recipe('r2', 'Not in this book'),
      ],
    );

    expect(find.text('Family Recipes'), findsOneWidget);
    expect(find.text('Chicken Paprika Noodles'), findsOneWidget);
    expect(find.text('Not in this book'), findsNothing); // not a member

    // Flip to the social view (people icon) -> real (honest, single-owner)
    // sharing UI, not a generic placeholder card.
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await tester.pump();
    expect(find.text('Not shared yet'), findsOneWidget);
    expect(find.text('Invite'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('adding a recipe via manage updates its bookIds',
      (tester) async {
    final recipeBloc = MockRecipeBloc();
    await pump(
      tester,
      recipeBloc: recipeBloc,
      recipes: [recipe('r1', 'Soup')], // empty book
    );

    expect(find.text('No recipes in this book yet'), findsOneWidget);

    await tester.tap(find.text('Add recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soup')); // tick the checkbox row
    await tester.pump();

    final captured = verify(() => recipeBloc.add(captureAny())).captured;
    final update = captured.whereType<UpdateRecipe>().first;
    expect(update.recipe.id, 'r1');
    expect(update.recipe.bookIds, contains('b1'));
  });
}
