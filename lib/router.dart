import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart'; // Kept for reference if needed, though MainScreen replaces it as root
import 'screens/main_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_edit_screen.dart';
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
          path: 'settings',
          builder: (context, state) => const MainScreen(initialTab: 1),
          routes: [
            GoRoute(
              path: 'theme',
              builder: (context, state) => const ThemeSettingsScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutSettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: 'recipe/new',
          builder: (context, state) => const RecipeEditScreen(),
        ),
        GoRoute(
          path: 'recipe/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MainScreen(selectedRecipeId: id);
          },
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return RecipeEditScreen(recipeId: id);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
