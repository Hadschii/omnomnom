import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final String recipeId;
  final bool showBackButton;
  final VoidCallback? onBack;

  const RecipeDetailScreen({
    super.key,
    required this.recipeId,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecipeBloc, RecipeState>(
      builder: (context, state) {
        Recipe? recipe;
        if (state is RecipeLoaded) {
          try {
            recipe = state.recipes.firstWhere((r) => r.id == recipeId);
          } catch (e) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Recipe not found')),
            );
          }
        }

        if (recipe == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: showBackButton,
            leading: onBack != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  )
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => context.go('/recipe/$recipeId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Recipe'),
                      content: const Text('Are you sure you want to delete this recipe?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            context.read<RecipeBloc>().add(DeleteRecipe(recipeId));
                            context.go('/'); // Go back home
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            children: [
              if (recipe.imagePath != null)
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Image.file(
                    File(recipe.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: Colors.grey[800], child: const Icon(Icons.broken_image)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
              const SizedBox(height: 16),
              if (recipe.servings != null || recipe.prepTime != null || recipe.cookTime != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (recipe.servings != null)
                      _buildInfoColumn(context, Icons.people, '${recipe.servings} Servings'),
                    if (recipe.prepTime != null)
                      _buildInfoColumn(context, Icons.timer, '${recipe.prepTime}m Prep'),
                    if (recipe.cookTime != null)
                      _buildInfoColumn(context, Icons.kitchen, '${recipe.cookTime}m Cook'),
                  ],
                ),
              const SizedBox(height: 16),
              if (recipe.labels.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: recipe.labels.map((label) {
                    return Chip(label: Text(label));
                  }).toList(),
                ),
              const SizedBox(height: 32),
              Text(
                'Ingredients',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ..._buildGroupedIngredients(context, recipe),
              const SizedBox(height: 32),
              Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ..._buildGroupedInstructions(context, recipe),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildInfoColumn(BuildContext context, IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  List<Widget> _buildGroupedIngredients(BuildContext context, Recipe recipe) {
    final grouped = <String?, List<dynamic>>{};
    for (var i in recipe.ingredients) {
      grouped.putIfAbsent(i.group, () => []).add(i);
    }

    return grouped.entries.expand((entry) {
      return [
        if (entry.key != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(entry.key!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ...entry.value.map((ingredient) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ingredient.name, style: Theme.of(context).textTheme.bodyLarge),
                  if (ingredient.amount.isNotEmpty)
                    Text(
                      ingredient.amount,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
            )),
      ];
    }).toList();
  }

  List<Widget> _buildGroupedInstructions(BuildContext context, Recipe recipe) {
    final grouped = <String?, List<dynamic>>{};
    for (var i in recipe.instructions) {
      grouped.putIfAbsent(i.group, () => []).add(i);
    }

    var stepCount = 1;
    return grouped.entries.expand((entry) {
      return [
        if (entry.key != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(entry.key!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        ...entry.value.map((instruction) {
          final currentStep = stepCount++;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '$currentStep',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(instruction.description, style: Theme.of(context).textTheme.bodyLarge),
                      if (instruction.photoPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Image.file(File(instruction.photoPath!), height: 150),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ];
    }).toList();
  }
}
