import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/recipe_edit_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'recipe/new',
          builder: (context, state) => const RecipeEditScreen(),
        ),
        GoRoute(
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
          ],
        ),
      ],
    ),
  ],
);
