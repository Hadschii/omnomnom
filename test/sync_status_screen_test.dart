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
import 'package:omnomnom_recipe_app/blocs/settings/settings_bloc.dart';
import 'package:omnomnom_recipe_app/blocs/settings/settings_event.dart';
import 'package:omnomnom_recipe_app/blocs/settings/settings_state.dart';
import 'package:omnomnom_recipe_app/models/recipe.dart';
import 'package:omnomnom_recipe_app/repositories/recipe_repository.dart';
import 'package:omnomnom_recipe_app/screens/sync_status_screen.dart';

class MockRecipeBloc extends MockBloc<RecipeEvent, RecipeState>
    implements RecipeBloc {}

class MockBookBloc extends MockBloc<BookEvent, BookState> implements BookBloc {}

class MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

void main() {
  Future<void> pump(WidgetTester tester, SettingsState state) async {
    final recipeBloc = MockRecipeBloc();
    whenListen(recipeBloc, const Stream<RecipeState>.empty(),
        initialState: RecipeLoaded([
          Recipe(
            id: 'r1',
            title: 'Soup',
            ingredients: const [],
            instructions: const [],
            labels: const [],
            createdAt: DateTime(2026, 1, 1),
          ),
        ]));
    final bookBloc = MockBookBloc();
    whenListen(bookBloc, const Stream<BookState>.empty(),
        initialState: const BookLoaded([]));
    final settingsBloc = MockSettingsBloc();
    whenListen(settingsBloc, const Stream<SettingsState>.empty(),
        initialState: state);

    await tester.pumpWidget(MaterialApp(
      home: RepositoryProvider<RecipeRepository>(
        create: (_) => RecipeRepository(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<RecipeBloc>.value(value: recipeBloc),
            BlocProvider<BookBloc>.value(value: bookBloc),
            BlocProvider<SettingsBloc>.value(value: settingsBloc),
          ],
          child: const SyncStatusScreen(),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('sync off: no status card, devices section still honest',
      (tester) async {
    await pump(tester, const SettingsState());

    expect(find.text('All changes synced'), findsNothing);
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Sync off'), findsOneWidget);
  });

  testWidgets('sync on with a last-synced date shows real counts',
      (tester) async {
    await pump(
      tester,
      SettingsState(isSyncEnabled: true, lastSyncDate: DateTime.now()),
    );

    expect(find.text('All changes synced'), findsOneWidget);
    expect(find.textContaining('1 recipes, 0 books'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
  });
}
