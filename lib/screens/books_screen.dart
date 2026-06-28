import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_event.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../theme/recipe_accents.dart';

const _brand = Color(0xFFF69021);

/// Recipes that belong to [book] (membership is the source of truth on Recipe).
List<Recipe> recipesInBook(List<Recipe> all, String bookId) =>
    all.where((r) => (r.bookIds ?? const []).contains(bookId)).toList();

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
              return GridView.builder(
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
                  final members = recipesInBook(recipes, book.id);
                  return _BookCover(
                    book: book,
                    members: members,
                    onTap: () => context.push('/books/${book.id}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

}

/// Prompts for a name and creates a new (empty) book.
Future<void> createBook(BuildContext context) async {
  final ctrl = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New book'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Family Recipes'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Create')),
      ],
    ),
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty || !context.mounted) return;
  context.read<BookBloc>().add(AddBook(RecipeBook(
        id: const Uuid().v4(),
        name: trimmed,
        createdAt: DateTime.now(),
      )));
}

class _BookCover extends StatelessWidget {
  final RecipeBook book;
  final List<Recipe> members;
  final VoidCallback onTap;

  const _BookCover({
    required this.book,
    required this.members,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final photos = [
      for (final r in members) if (r.imagePath != null) r.imagePath!,
    ]..shuffle(Random(book.id.hashCode));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _BookMosaic(photos: photos, bookName: book.name),
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

/// Tiled mosaic for the book cover.
///
/// • 0 photos  → vibrant coloured-block grid (no photo needed).
/// • 1 photo   → 2×2 Warhol-style pop-art: same image tinted 4 vivid colours.
/// • 2+ photos → 4×3 grid, each photo shown once, leftover slots get coloured
///               blocks so nothing ever repeats.
class _BookMosaic extends StatelessWidget {
  final List<String> photos;
  final String bookName;
  const _BookMosaic({required this.photos, required this.bookName});

  // Pop-art tint colours for the single-photo case.
  static const _warhol = [
    Color(0xFFFF2D55), // pink-red
    Color(0xFF5AC8FA), // sky blue
    Color(0xFFFFCC00), // yellow
    Color(0xFF4CD964), // green
  ];

  // Vivid palette for placeholder / fill blocks.
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
    final rng = Random(bookName.hashCode);

    // ── No photos: vivid block grid ──────────────────────────────────────────
    if (photos.isEmpty) {
      final shuffled = [..._palette]..shuffle(rng);
      return GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 12; i++)
            ColoredBox(color: shuffled[i % shuffled.length]),
        ],
      );
    }

    // ── One photo: 2×2 Warhol pop-art ───────────────────────────────────────
    if (photos.length == 1) {
      final tints = [..._warhol]..shuffle(rng);
      return GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 4; i++)
            ColorFiltered(
              colorFilter:
                  ColorFilter.mode(tints[i], BlendMode.color),
              child: Image.file(
                File(photos[0]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: tints[i]),
              ),
            ),
        ],
      );
    }

    // ── Multiple photos: each once, coloured fills for the rest ──────────────
    const cols = 4, count = cols * 3;
    final shuffledPalette = [..._palette]..shuffle(rng);
    final cells = <Widget>[];
    for (var i = 0; i < count; i++) {
      if (i < photos.length) {
        cells.add(Image.file(
          File(photos[i]),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
              color: shuffledPalette[(i - photos.length) % shuffledPalette.length]),
        ));
      } else {
        cells.add(ColoredBox(
            color: shuffledPalette[(i - photos.length) % shuffledPalette.length]));
      }
    }
    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
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
