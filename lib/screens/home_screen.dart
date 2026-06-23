import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/folder/folder_bloc.dart';
import '../blocs/folder/folder_state.dart';
import '../models/recipe.dart';
import '../models/folder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFolderId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FolderBloc, FolderState>(
      builder: (context, folderState) {
        final folders =
            folderState is FolderLoaded ? folderState.folders : <Folder>[];
        final selectedFolder = _selectedFolderId != null
            ? folders.where((f) => f.id == _selectedFolderId).firstOrNull
            : null;

        return Scaffold(
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search recipes...',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 18),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                  )
                : Row(
                    children: [
                      if (selectedFolder == null) ...[
                        Image.asset('assets/images/app_logo.png', height: 32),
                        const SizedBox(width: 12),
                        const Text('OmNomNom'),
                      ] else ...[
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              Color(int.parse(selectedFolder.color)),
                        ),
                        const SizedBox(width: 10),
                        Text(selectedFolder.name),
                      ],
                    ],
                  ),
            actions: [
              if (_isSearching)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                )
              else
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _isSearching = true),
                ),
            ],
          ),
          drawer: _buildDrawer(context, folders),
          body: RecipeList(
            searchQuery: _searchQuery,
            folderId: _selectedFolderId,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => context.go('/recipe/new'),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, List<Folder> folders) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/app_logo.png', height: 32),
                  const SizedBox(width: 12),
                  Text(
                    'OmNomNom',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('All Recipes'),
              selected: _selectedFolderId == null,
              selectedColor: Theme.of(context).colorScheme.primary,
              selectedTileColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onTap: () {
                setState(() => _selectedFolderId = null);
                Navigator.of(context).pop();
              },
            ),
            if (folders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Folders',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              ...folders.map((folder) {
                final color = Color(int.parse(folder.color));
                return ListTile(
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor: color,
                  ),
                  title: Text(folder.name),
                  selected: _selectedFolderId == folder.id,
                  selectedColor: Theme.of(context).colorScheme.primary,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    setState(() => _selectedFolderId = folder.id);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Manage Folders'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/settings/folders');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeList extends StatelessWidget {
  final Function(Recipe)? onRecipeSelected;
  final String searchQuery;
  final String? folderId;

  const RecipeList({
    super.key,
    this.onRecipeSelected,
    this.searchQuery = '',
    this.folderId,
  });

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
                  Icon(Icons.restaurant_menu,
                      size: 64, color: Colors.grey[400]),
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

          final query = searchQuery.trim().toLowerCase();
          final filteredRecipes = state.recipes.where((recipe) {
            if (folderId != null && recipe.folderId != folderId) return false;
            if (query.isEmpty) return true;
            if (recipe.title.toLowerCase().contains(query)) return true;
            if (recipe.labels
                .any((label) => label.toLowerCase().contains(query))) {
              return true;
            }
            if (recipe.ingredients
                .any((ing) => ing.name.toLowerCase().contains(query))) {
              return true;
            }
            return false;
          }).toList();

          if (filteredRecipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    folderId != null && query.isEmpty
                        ? Icons.folder_open
                        : Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    folderId != null && query.isEmpty
                        ? 'No recipes in this folder'
                        : 'No recipes match your search',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRecipes.length,
            itemBuilder: (context, index) {
              final recipe = filteredRecipes[index];
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
      clipBehavior: Clip.antiAlias,
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
                  errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.broken_image)),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
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
