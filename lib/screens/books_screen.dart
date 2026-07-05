import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_event.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../repositories/recipe_repository.dart';
import '../theme/recipe_accents.dart';
import '../widgets/prompt_text.dart';

const _brand = brandOrange;

/// Recipes that belong to [book] (membership is the source of truth on Recipe).
List<Recipe> recipesInBook(List<Recipe> all, String bookId) =>
    all.where((r) => (r.bookIds ?? const []).contains(bookId)).toList();

/// One-time index of recipes by book id. Building this once per recipe list
/// and looking up per book (O(1) after the initial O(recipes) pass) avoids
/// re-scanning every recipe for every book when rendering a books grid —
/// [recipesInBook] itself is an O(recipes) scan, so calling it once per book
/// in a list is O(books × recipes).
Map<String, List<Recipe>> indexRecipesByBook(List<Recipe> all) {
  final index = <String, List<Recipe>>{};
  for (final r in all) {
    for (final id in r.bookIds ?? const <String>[]) {
      index.putIfAbsent(id, () => []).add(r);
    }
  }
  return index;
}

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _brand),
            tooltip: 'New book',
            onPressed: () => createBook(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<BookBloc, BookState>(
        builder: (context, bookState) {
          if (bookState is BookLoading || bookState is BookInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (bookState is BookError) {
            return Center(child: Text(bookState.message));
          }
          final books = (bookState as BookLoaded).books;
          return BlocBuilder<RecipeBloc, RecipeState>(
            builder: (context, recipeState) {
              final recipes =
                  recipeState is RecipeLoaded ? recipeState.recipes : <Recipe>[];
              final byBook = indexRecipesByBook(recipes);
              return Column(
                children: [
                  const _SyncBanner(),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        mainAxisExtent: 222,
                      ),
                      itemCount: books.length + 1,
                      itemBuilder: (context, index) {
                        if (index == books.length) {
                          return _NewBookTile(onTap: () => createBook(context));
                        }
                        final book = books[index];
                        final members = byBook[book.id] ?? const <Recipe>[];
                        return _BookCover(
                          key: ValueKey(book.id),
                          book: book,
                          members: members,
                          onTap: () => context.push('/books/${book.id}'),
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

}

/// Green "all changes synced" banner shown above the books grid, matching the
/// design's cloud-sync status pill. Only rendered when sync is actually
/// enabled — reflects real SettingsBloc/RecipeRepository state, not a mock.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context) {
    final providerName = context.read<RecipeRepository>().syncProviderName;
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, s) {
        if (!s.isSyncEnabled) return const SizedBox.shrink();
        final syncing = s.syncStatus == SyncStatus.loading;
        final failed = s.syncStatus == SyncStatus.failure;
        final statusText = syncing
            ? 'Syncing…'
            : failed
                ? 'Sync failed'
                : s.lastSyncDate != null
                    ? '$providerName · all changes synced'
                    : '$providerName · waiting for first sync';
        final color = failed ? const Color(0xFFC0492E) : const Color(0xFF2E8B57);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: failed
                  ? color.withValues(alpha: 0.1)
                  : const Color(0xFFEEF7EE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(
                  failed ? Icons.error_outline : Icons.check_circle_outline,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(statusText,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
                if (!syncing && s.lastSyncDate != null)
                  Text(_relativeTime(s.lastSyncDate!),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8AAB94))),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

/// Prompts for a name and creates a new (empty) book.
Future<void> createBook(BuildContext context) async {
  final name = await promptText(
    context,
    title: 'New book',
    hint: 'e.g. Family Recipes',
    confirmLabel: 'Create',
  );
  if (name == null || !context.mounted) return;
  context.read<BookBloc>().add(AddBook(RecipeBook(
        id: const Uuid().v4(),
        name: name,
        createdAt: DateTime.now(),
      )));
}

class _BookCover extends StatefulWidget {
  final RecipeBook book;
  final List<Recipe> members;
  final VoidCallback onTap;

  const _BookCover({
    super.key,
    required this.book,
    required this.members,
    required this.onTap,
  });

  @override
  State<_BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<_BookCover> {
  // Shuffled once and cached so an unrelated app-wide rebuild (e.g. another
  // recipe being edited) doesn't reshuffle and re-decode every visible cover.
  late List<String> _photos;

  @override
  void initState() {
    super.initState();
    _photos = _shuffled(widget.members);
  }

  @override
  void didUpdateWidget(_BookCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(_imagePaths(oldWidget.members), _imagePaths(widget.members))) {
      _photos = _shuffled(widget.members);
    }
  }

  List<String> _imagePaths(List<Recipe> members) =>
      [for (final r in members) if (r.imagePath != null) r.imagePath!];

  List<String> _shuffled(List<Recipe> members) =>
      _imagePaths(members)..shuffle(Random(widget.book.id.hashCode));

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final members = widget.members;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookMosaic(photos: _photos, bookName: book.name),
                  // Diagonal fade: bright top-left → dark bottom-right.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x00000000),
                          Color(0x26000000),
                          Color(0x73000000),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  // Bottom darkening so the title stays readable.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  // Spine accent.
                  Positioned(
                    left: 8,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      book.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text('${members.length} recipes',
                    style: const TextStyle(fontSize: 12, color: metaGrey)),
                const SizedBox(width: 6),
                Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                        color: Color(0xFFC7C7CC), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                // PLACEHOLDER: sharing isn't built yet, so every book is private.
                const Icon(Icons.lock_outline,
                    size: 11, color: Color(0xFFA0A0A5)),
                const SizedBox(width: 3),
                const Text('Private',
                    style: TextStyle(fontSize: 12, color: Color(0xFFA0A0A5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Auto-density mosaic for the book cover.
///
/// Uses LayoutBuilder to fix the visual cell size at ~40px regardless of card
/// width — so mobile and desktop both look dense, never boxy.
/// Unique photos are scattered at random positions; all other cells are vivid
/// coloured blocks. Nothing ever repeats.
class _BookMosaic extends StatelessWidget {
  final List<String> photos;
  final String bookName;
  const _BookMosaic({required this.photos, required this.bookName});

  static const double _cellSize = 40.0;

  static const _palette = [
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFFFFE66D),
    Color(0xFF95E1D3),
    Color(0xFFF38181),
    Color(0xFFC3A6FF),
    Color(0xFFFF9F43),
    Color(0xFF54A0FF),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = max(4, (constraints.maxWidth / _cellSize).floor());
      final rows = max(3, (constraints.maxHeight / _cellSize).floor());
      final count = cols * rows;

      final rng = Random(bookName.hashCode);
      final palette = [..._palette]..shuffle(rng);

      // Randomly scatter unique photos across the grid.
      final positions = List.generate(count, (i) => i)..shuffle(rng);
      final photoAt = <int, String>{};
      for (var i = 0; i < min(photos.length, count); i++) {
        photoAt[positions[i]] = photos[i];
      }

      var fillIdx = 0;
      final cells = List.generate(count, (i) {
        final path = photoAt[i];
        if (path != null) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                ColoredBox(color: palette[fillIdx++ % palette.length]),
          );
        }
        return ColoredBox(color: palette[fillIdx++ % palette.length]);
      });

      return GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      );
    });
  }
}

class _NewBookTile extends StatelessWidget {
  final VoidCallback onTap;
  const _NewBookTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: DottedBorderBox(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFDEEDE), shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: _brand),
                  ),
                  const SizedBox(height: 8),
                  const Text('New Book',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _brand)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

/// A rounded rectangle with a dashed border (used for the New Book tile).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(),
      child: SizedBox.expand(child: child),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2D3BD)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
          metric.extractPath(dist, dist + dash),
          paint,
        );
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
