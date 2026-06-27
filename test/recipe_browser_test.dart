import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_event.dart';
import 'package:omnomnom_recipe_app/blocs/book/book_state.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_event.dart';
import 'package:omnomnom_recipe_app/blocs/recipe/recipe_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/models/recipe_book.dart';
import 'package:omnomnom_recipe_app/screens/home_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockBookBloc extends MockBloc<BookEvent, BookState> implements BookBloc {}

void main() {
  Recipe sample({List<String>? bookIds}) => Recipe(
        id: '1',
        title: 'Chicken Paprika Noodles',
        ingredients: const [],
        instructions: const [],
        labels: const ['Weeknight'],
        createdAt: DateTime(2026, 6, 26),
        servings: 2,
        prepTime: 15,
        cookTime: 20,
        bookIds: bookIds,
      );

  Future<void> pumpList(
    WidgetTester tester,
    RecipeState state, {
    List<RecipeBook> books = const [],
  }) async {
    final bloc = MockRecipeBloc();
    whenListen(bloc, const Stream<RecipeState>.empty(), initialState: state);
    final bookBloc = MockBookBloc();
    whenListen(bookBloc, const Stream<BookState>.empty(),
        initialState: BookLoaded(books));
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<RecipeBloc>.value(value: bloc),
            BlocProvider<BookBloc>.value(value: bookBloc),
          ],
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

  testWidgets('book membership lights up book chips on the card',
      (tester) async {
    await pumpList(
      tester,
      RecipeLoaded([sample(bookIds: ['b1'])]),
      books: [
        RecipeBook(id: 'b1', name: 'Family', createdAt: DateTime(2026, 6, 26)),
      ],
    );
    expect(find.text('Family'), findsOneWidget); // resolved book chip
  });

  testWidgets('empty library shows the empty state', (tester) async {
    await pumpList(tester, const RecipeLoaded([]));
    expect(find.text('No recipes yet'), findsOneWidget);
  });
}
