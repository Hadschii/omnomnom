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
import 'package:omnomnom_recipe_app/screens/books_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockBookBloc extends MockBloc<BookEvent, BookState> implements BookBloc {}

void main() {
  Recipe recipe(String id, String title, {List<String>? bookIds}) => Recipe(
        id: id,
        title: title,
        ingredients: const [],
        instructions: const [],
        labels: const [],
        createdAt: DateTime(2026, 6, 26),
        bookIds: bookIds,
      );

  testWidgets('shelf shows a book cover with its real recipe count + New Book',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bookBloc = MockBookBloc();
    whenListen(bookBloc, const Stream<BookState>.empty(),
        initialState: BookLoaded([
          RecipeBook(id: 'b1', name: 'Desserts', createdAt: DateTime(2026, 1, 1)),
        ]));
    final recipeBloc = MockRecipeBloc();
    whenListen(recipeBloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([
          recipe('r1', 'Cookies', bookIds: ['b1']),
          recipe('r2', 'Cake', bookIds: ['b1']),
          recipe('r3', 'Not in book'),
        ]));

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<BookBloc>.value(value: bookBloc),
          BlocProvider<RecipeBloc>.value(value: recipeBloc),
        ],
        child: const BooksScreen(),
      ),
    ));
    await tester.pump();

    expect(find.text('Desserts'), findsOneWidget);
    expect(find.text('2 recipes'), findsOneWidget); // r1 + r2, not r3
    expect(find.text('New Book'), findsOneWidget);
  });
}
