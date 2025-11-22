import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              height: 32,
            ),
            const SizedBox(width: 12),
            const Text('OmNomNom'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
        ],
      ),
      body: const RecipeList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/recipe/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class RecipeList extends StatelessWidget {
  final Function(Recipe)? onRecipeSelected;

  const RecipeList({super.key, this.onRecipeSelected});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecipeBloc, RecipeState>(
      builder: (context, state) {
        if (state is RecipeLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is RecipeLoaded) {
          if (state.recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No recipes yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/recipe/new'),
                    child: const Text('Create your first recipe'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.recipes.length,
            itemBuilder: (context, index) {
              final recipe = state.recipes[index];
              return _RecipeCard(
                recipe: recipe,
                onTap: () {
                  if (onRecipeSelected != null) {
                    onRecipeSelected!(recipe);
                  } else {
                    context.go('/recipe/${recipe.id}');
                  }
                },
              );
            },
          );
        } else if (state is RecipeError) {
          return Center(child: Text(state.message));
        }
        return const SizedBox();
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias, // Clip image to card
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imagePath != null)
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Image.file(
                  File(recipe.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey[800], child: const Icon(Icons.broken_image)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (recipe.labels.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: recipe.labels.map((label) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

