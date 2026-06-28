import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../models/recipe.dart';
import '../theme/recipe_accents.dart';

class RecipeDetailScreen extends StatefulWidget {
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
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _tab = 0; // 0 = Ingredients, 1 = Steps

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecipeBloc, RecipeState>(
      builder: (context, state) {
        Recipe? recipe;
        if (state is RecipeLoaded) {
          for (final r in state.recipes) {
            if (r.id == widget.recipeId) {
              recipe = r;
              break;
            }
          }
          if (recipe == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Recipe not found')),
            );
          }
        }
        if (recipe == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final accent = accentForRecipe(recipe);
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              _hero(context, recipe, accent),
              SliverToBoxAdapter(child: _sheet(context, recipe, accent)),
            ],
          ),
        );
      },
    );
  }

  // ---- Hero ---------------------------------------------------------------

  Widget _hero(BuildContext context, Recipe recipe, Color accent) {
    final surface = Theme.of(context).colorScheme.surface;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      backgroundColor: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 60,
      leading: widget.showBackButton
          ? Align(
              child: _circleButton(
                Icons.arrow_back_ios_new,
                () => _back(context),
              ),
            )
          : null,
      actions: [
        _circleButton(
          Icons.favorite_border,
          () => _placeholder(context, 'Favourites'),
        ),
        _circleButton(Icons.more_horiz, () => _showMore(context, recipe)),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: _heroPhoto(recipe, accent),
      ),
    );
  }

  Widget _heroPhoto(Recipe recipe, Color accent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (recipe.imagePath != null)
          Image.file(
            File(recipe.imagePath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: accent),
          )
        else
          Container(
            color: accent,
            child: Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        // Top gradient so nav buttons stay legible over the photo.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Color(0x55000000), Color(0x00000000)],
            ),
          ),
        ),
        // Bottom gradient so photo blends smoothly into the card below.
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ---- Sheet --------------------------------------------------------------

  Widget _sheet(BuildContext context, Recipe recipe, Color accent) {
    final surface = Theme.of(context).colorScheme.surface;
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tags(context, recipe, accent),
            const SizedBox(height: 10),
            Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.06,
              ),
            ),
            const SizedBox(height: 11),
            _stats(recipe, accent),
            const SizedBox(height: 15),
            _startCooking(context, accent),
            const SizedBox(height: 16),
            _segmented(accent),
            const SizedBox(height: 14),
            if (_tab == 0)
              _ingredients(context, recipe, accent)
            else
              _steps(context, recipe, accent),
          ],
        ),
      ),
    );
  }

  Widget _tags(BuildContext context, Recipe recipe, Color accent) {
    final labels = recipe.labels;
    final shown = labels.take(3).toList();
    final overflow = labels.length - shown.length;
    Widget pill(String text, {bool muted = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: muted ? 0.10 : 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: accent.withValues(alpha: muted ? 0.20 : 0.35), width: 1),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: accent.withValues(alpha: muted ? 0.65 : 1.0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final label in shown) pill(label),
        if (overflow > 0) pill('+$overflow', muted: true),
        GestureDetector(
          onTap: () => _placeholder(context, 'Add tag'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                  color: accent.withValues(alpha: 0.40), width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '+ Tag',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stats(Recipe recipe, Color accent) {
    final items = <List<String>>[];
    if (recipe.servings != null) {
      items.add(['${recipe.servings}', 'servings']);
    }
    if (recipe.prepTime != null) {
      items.add(['${recipe.prepTime} min', 'active']);
    }
    final total = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0);
    if (total > 0) {
      items.add(['$total min', 'total']);
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it[0],
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                Text(
                  it[1],
                  style: const TextStyle(fontSize: 12, color: metaGrey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _startCooking(BuildContext context, Color accent) {
    return GestureDetector(
      onTap: () => context.push('/recipe/${widget.recipeId}/cook'),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow, color: Colors.white, size: 22),
            SizedBox(width: 9),
            Text(
              'Start Cooking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented(Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _segment('Ingredients', 0, accent),
          _segment('Steps', 1, accent),
        ],
      ),
    );
  }

  Widget _segment(String label, int index, Color accent) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF6A6A6E),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Ingredients tab ----------------------------------------------------

  Widget _ingredients(BuildContext context, Recipe recipe, Color accent) {
    if (recipe.ingredients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No ingredients yet', style: TextStyle(color: metaGrey)),
      );
    }
    final grouped = <String?, List<Ingredient>>{};
    for (final i in recipe.ingredients) {
      grouped.putIfAbsent(i.group, () => []).add(i);
    }

    final children = <Widget>[];
    grouped.forEach((group, items) {
      if (group != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 9),
          child: Text(
            group.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: 0.4,
            ),
          ),
        ));
      }
      for (final ing in items) {
        children.add(Container(
          padding: const EdgeInsets.only(bottom: 9),
          margin: const EdgeInsets.only(bottom: 9),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF0F0F2))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(ing.name, style: const TextStyle(fontSize: 15)),
              ),
              if (ing.amount.isNotEmpty)
                Text(
                  ing.amount,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
            ],
          ),
        ));
      }
      children.add(const SizedBox(height: 7));
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  // ---- Steps tab ----------------------------------------------------------

  Widget _steps(BuildContext context, Recipe recipe, Color accent) {
    if (recipe.instructions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No steps yet', style: TextStyle(color: metaGrey)),
      );
    }
    final total = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0);
    final summary = StringBuffer('${recipe.instructions.length} steps');
    if (total > 0) summary.write(' · $total min total');

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(summary.toString(),
            style: const TextStyle(fontSize: 13, color: metaGrey)),
      ),
    ];
    for (var i = 0; i < recipe.instructions.length; i++) {
      children.add(_stepRow(
        i + 1,
        recipe.instructions[i],
        accent,
        isLast: i == recipe.instructions.length - 1,
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _stepRow(int number, Instruction step, Color accent,
      {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF2F2F4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.description,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
                if (step.timerSeconds != null || step.effectiveGroups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (step.timerSeconds != null)
                          _timerPill(step.timerSeconds!),
                        for (final g in step.effectiveGroups) _groupChip(g),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (step.photoPath != null) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.file(
                File(step.photoPath!),
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 54, height: 54),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timerPill(int seconds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        border: Border.all(color: const Color(0xFFF3DCC5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFB5701D)),
          const SizedBox(width: 5),
          Text(
            formatTimer(seconds),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB5701D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupChip(String name) {
    final color = groupColor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ------------------------------------------------------------

  void _back(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _placeholder(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$what — coming soon (PLACEHOLDER)')),
      );
  }

  void _showMore(BuildContext context, Recipe recipe) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit recipe'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.go('/recipe/${recipe.id}/edit');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete recipe',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, recipe);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Recipe recipe) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<RecipeBloc>().add(DeleteRecipe(recipe.id));
              Navigator.pop(dialogContext);
              _back(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
