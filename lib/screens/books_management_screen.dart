import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_event.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../theme/recipe_accents.dart';
import '../widgets/prompt_text.dart';
import 'books_screen.dart' show createBook, indexRecipesByBook, recipesInBook;

const _brand = brandOrange;

class BooksManagementScreen extends StatelessWidget {
  const BooksManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        backgroundColor: groupedBg(context),
        title: const Text('Recipe Books'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: BlocBuilder<BookBloc, BookState>(
        builder: (context, bookState) {
          final books = bookState is BookLoaded ? bookState.books : <RecipeBook>[];
          return BlocBuilder<RecipeBloc, RecipeState>(
            builder: (context, recipeState) {
              final recipes = recipeState is RecipeLoaded
                  ? recipeState.recipes
                  : <Recipe>[];
              final byBook = indexRecipesByBook(recipes);
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 2),
                    child: Text('${books.length} books · collections to share',
                        style: const TextStyle(fontSize: 13, color: metaGrey)),
                  ),
                  InkWell(
                    onTap: () => createBook(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                          color: cardColor(context),
                          borderRadius: BorderRadius.circular(14)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                                color: Color(0xFF34C759), shape: BoxShape.circle),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('New book…',
                                style: TextStyle(
                                    fontSize: 16, color: Color(0xFFB0B0B5))),
                          ),
                          const Text('Add',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _brand)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (books.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child:
                          Text('No books yet', style: TextStyle(color: metaGrey)),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor(context),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: books.length,
                        onReorder: (oldIndex, newIndex) {
                          if (newIndex > oldIndex) newIndex--;
                          final reordered = [...books];
                          final moved = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, moved);
                          context.read<BookBloc>().add(
                              ReorderBooks(reordered.map((b) => b.id).toList()));
                        },
                        itemBuilder: (context, i) {
                          final b = books[i];
                          return _BookRow(
                            key: ValueKey(b.id),
                            book: b,
                            index: i,
                            isLast: i == books.length - 1,
                            count: (byBook[b.id] ?? const <Recipe>[]).length,
                            coverPath: _cover(byBook, b),
                            onRemove: () => _delete(context, b, recipes),
                            onRename: () => _rename(context, b),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String? _cover(Map<String, List<Recipe>> byBook, RecipeBook book) {
    if (book.coverImagePath != null) return book.coverImagePath;
    for (final r in byBook[book.id] ?? const <Recipe>[]) {
      if (r.imagePath != null) return r.imagePath;
    }
    return null;
  }

  Future<void> _delete(
      BuildContext context, RecipeBook book, List<Recipe> recipes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book'),
        content: Text('Delete "${book.name}"? Recipes are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    for (final r in recipesInBook(recipes, book.id)) {
      final next = [...(r.bookIds ?? const <String>[])]..remove(book.id);
      context.read<RecipeBloc>().add(UpdateRecipe(r.copyWith(bookIds: next)));
    }
    context.read<BookBloc>().add(DeleteBook(book.id));
  }

  Future<void> _rename(BuildContext context, RecipeBook book) async {
    final name = await promptText(context, title: 'Rename book', initial: book.name);
    if (name == null || !context.mounted) return;
    context.read<BookBloc>().add(UpdateBook(RecipeBook(
          id: book.id,
          name: name,
          coverImagePath: book.coverImagePath,
          createdAt: book.createdAt,
        )));
  }
}

class _BookRow extends StatelessWidget {
  final RecipeBook book;
  final int index;
  final bool isLast;
  final int count;
  final String? coverPath;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  const _BookRow({
    super.key,
    required this.book,
    required this.index,
    required this.isLast,
    required this.count,
    required this.coverPath,
    required this.onRemove,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onRename,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30), shape: BoxShape.circle),
                    child: const Icon(Icons.remove, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: coverPath != null
                        ? Image.file(File(coverPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                ColoredBox(color: groupColor(book.name)))
                        : ColoredBox(color: groupColor(book.name)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('$count recipes',
                          style: const TextStyle(fontSize: 12, color: metaGrey)),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle,
                      size: 20, color: Color(0xFFC7C7CC)),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, thickness: 1, indent: 14, color: hairline(context)),
      ],
    );
  }
}
