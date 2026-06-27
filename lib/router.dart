import 'package:go_router/go_router.dart';
import 'screens/book_detail_screen.dart';
import 'screens/books_management_screen.dart';
import 'screens/main_screen.dart';
import 'screens/cook_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_edit_screen.dart';
import 'screens/sync_status_screen.dart';
import 'screens/tags_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'screens/about_settings_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(initialTab: 0),
      routes: [
        GoRoute(
          path: 'books',
          builder: (context, state) => const MainScreen(initialTab: 1),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  BookDetailScreen(bookId: state.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const MainScreen(initialTab: 2),
          routes: [
            GoRoute(
              path: 'theme',
              builder: (context, state) => const ThemeSettingsScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutSettingsScreen(),
            ),
            GoRoute(
              path: 'tags',
              builder: (context, state) => const TagsScreen(),
            ),
            GoRoute(
              path: 'books',
              builder: (context, state) => const BooksManagementScreen(),
            ),
            GoRoute(
              path: 'sync',
              builder: (context, state) => const SyncStatusScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'recipe/new',
          builder: (context, state) => const RecipeEditScreen(),
        ),
        GoRoute(
          // A focused, full-screen recipe detail on every platform. (The
          // desktop home two-pane uses MainScreen's internal selection, not
          // this route, so it is unaffected.)
          path: 'recipe/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return RecipeDetailScreen(recipeId: id);
          },
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return RecipeEditScreen(recipeId: id);
              },
            ),
            GoRoute(
              path: 'cook',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return CookScreen(recipeId: id);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
