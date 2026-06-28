import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';
import '../theme/recipe_accents.dart';

const _dotGrey = Color(0xFFC7C7CC);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/app_logo.png', height: 30),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
            tooltip: 'New recipe',
            onPressed: () => context.go('/recipe/new'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: const RecipeList(showLargeTitle: true),
    );
  }
}

class RecipeList extends StatefulWidget {
  final Function(Recipe)? onRecipeSelected;

  /// When true, prepends the large "Recipes" title (used on the mobile home
  /// tab). The desktop master pane has its own header, so it passes false.
  final bool showLargeTitle;

  const RecipeList({
    super.key,
    this.onRecipeSelected,
    this.showLargeTitle = false,
  });

  @override
  State<RecipeList> createState() => _RecipeListState();
}

class _RecipeListState extends State<RecipeList> {
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Recipe> _filter(List<Recipe> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.labels.any((l) => l.toLowerCase().contains(q)) ||
            r.ingredients.any((i) => i.name.toLowerCase().contains(q)))
        .toList();
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Container(
        decoration: BoxDecoration(
          color: subtleFill(context),
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: metaGrey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Search recipes…',
                  hintStyle: TextStyle(color: metaGrey, fontSize: 15),
                ),
                style: const TextStyle(fontSize: 15),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Icon(Icons.close, size: 18, color: metaGrey),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookState = context.watch<BookBloc>().state;
    final bookNamesById = <String, String>{
      if (bookState is BookLoaded)
        for (final b in bookState.books) b.id: b.name,
    };
    return BlocBuilder<RecipeBloc, RecipeState>(
      builder: (context, state) {
        if (state is RecipeLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is RecipeError) {
          return Center(child: Text(state.message));
        }
        if (state is RecipeLoaded) {
          if (state.recipes.isEmpty) {
            return _EmptyState(showLargeTitle: widget.showLargeTitle);
          }
          final allRecipes = state.recipes;
          final filtered = _filter(allRecipes);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchBar(),
              Expanded(
                child: filtered.isEmpty
                    ? _NoMatchState(
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                            22, widget.showLargeTitle ? 4 : 16, 22, 28),
                        itemCount:
                            filtered.length + (widget.showLargeTitle ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          if (widget.showLargeTitle && index == 0) {
                            return const Text(
                              'Recipes',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            );
                          }
                          final recipe = filtered[
                              index - (widget.showLargeTitle ? 1 : 0)];
                          return _RecipeCard(
                            recipe: recipe,
                            bookNamesById: bookNamesById,
                            onTap: () {
                              if (widget.onRecipeSelected != null) {
                                widget.onRecipeSelected!(recipe);
                              } else {
                                context.go('/recipe/${recipe.id}');
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }
}

/// The names of the books a recipe belongs to, resolved from its bookIds.
List<String> _bookNamesFor(Recipe recipe, Map<String, String> namesById) => [
      for (final id in recipe.bookIds ?? const <String>[])
        if (namesById[id] != null) namesById[id]!,
    ];

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Map<String, String> bookNamesById;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.bookNamesById,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bookNames = _bookNamesFor(recipe, bookNamesById);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                _RecipePhoto(imagePath: recipe.imagePath),
                if (bookNames.isNotEmpty)
                  Positioned(
                    top: 11,
                    left: 11,
                    right: 11,
                    child: _BookChips(names: bookNames),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Text(
            recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          _MetaRow(recipe: recipe),
        ],
      ),
    );
  }
}

class _RecipePhoto extends StatelessWidget {
  final String? imagePath;
  const _RecipePhoto({this.imagePath});

  static const double _height = 172;

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return Image.file(
        File(imagePath!),
        height: _height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      height: _height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade300, Colors.grey.shade500],
        ),
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Recipe recipe;
  const _MetaRow({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (recipe.servings != null) {
      parts.add('${recipe.servings} servings');
    }
    final total = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0);
    if (total > 0) {
      parts.add('$total min');
    }
    if (recipe.labels.isNotEmpty) {
      parts.add(recipe.labels.first);
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 3,
          height: 3,
          decoration: const BoxDecoration(
            color: _dotGrey,
            shape: BoxShape.circle,
          ),
        ));
      }
      children.add(Flexible(
        child: Text(
          parts[i],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, color: metaGrey),
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Overlay chips showing the books a recipe belongs to: up to three names,
/// then a "···" overflow chip. Drawn only when a recipe has books.
class _BookChips extends StatelessWidget {
  final List<String> names;
  const _BookChips({required this.names});

  @override
  Widget build(BuildContext context) {
    final shown = names.take(3).toList();
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final name in shown) _chip(label: name),
        if (names.length > 3) _chip(label: '···', isOverflow: true),
      ],
    );
  }

  Widget _chip({required String label, bool isOverflow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isOverflow) ...[
            const Icon(Icons.menu_book, size: 11, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool showLargeTitle;
  const _EmptyState({required this.showLargeTitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No recipes yet',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
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
}

class _NoMatchState extends StatelessWidget {
  final VoidCallback onClear;
  const _NoMatchState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No matching recipes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: const Text('Clear search')),
        ],
      ),
    );
  }
}
