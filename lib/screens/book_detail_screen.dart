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
import 'books_screen.dart' show recipesInBook;

const _brand = brandOrange;

class BookDetailScreen extends StatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  int _view = 0; // 0 = recipe list, 1 = social (placeholder)

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookBloc, BookState>(
      builder: (context, bookState) {
        RecipeBook? book;
        if (bookState is BookLoaded) {
          for (final b in bookState.books) {
            if (b.id == widget.bookId) {
              book = b;
              break;
            }
          }
        }
        if (bookState is BookLoaded && book == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Book not found')),
          );
        }
        if (book == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return BlocBuilder<RecipeBloc, RecipeState>(
          builder: (context, recipeState) {
            final all =
                recipeState is RecipeLoaded ? recipeState.recipes : <Recipe>[];
            final members = recipesInBook(all, widget.bookId);
            return Scaffold(
              body: Column(
                children: [
                  _header(context, book!, members),
                  Expanded(
                    child: _view == 0
                        ? _recipeList(context, members)
                        : _socialTab(context, book),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---- Header (mosaic + nav + title) -------------------------------------

  Widget _header(BuildContext context, RecipeBook book, List<Recipe> members) {
    final photos = [
      for (final r in members)
        if (r.imagePath != null) r.imagePath!,
    ];
    return SizedBox(
      height: 196,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Mosaic(photos: photos),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x57000000), Color(0x1F000000), Color(0xA8000000)],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circle(Icons.arrow_back_ios_new, () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/books');
                        }
                      }),
                      Row(
                        children: [
                          _viewToggle(),
                          const SizedBox(width: 10),
                          _circle(Icons.more_horiz,
                              () => _showMenu(context, book, members)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${members.length} recipes · owned by you',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _viewToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _toggleSeg(Icons.menu, 0),
          _toggleSeg(Icons.people_alt_outlined, 1),
        ],
      ),
    );
  }

  Widget _toggleSeg(IconData icon, int index) {
    final selected = _view == index;
    return GestureDetector(
      onTap: () => setState(() => _view = index),
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon,
            size: 17, color: selected ? const Color(0xFF1C1C1E) : Colors.white),
      ),
    );
  }

  // ---- Recipe list --------------------------------------------------------

  Widget _recipeList(BuildContext context, List<Recipe> members) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 56, color: Color(0xFFC7C7CC)),
            const SizedBox(height: 14),
            const Text('No recipes in this book yet',
                style: TextStyle(color: metaGrey)),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () => _manageRecipes(context),
              child: const Text('Add recipes'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, i) => _recipeBand(context, members[i]),
    );
  }

  Widget _recipeBand(BuildContext context, Recipe recipe) {
    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 86,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (recipe.imagePath != null)
                Image.file(File(recipe.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ColoredBox(color: groupColor(recipe.title)))
              else
                ColoredBox(color: groupColor(recipe.title)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x9E000000), Color(0x1F000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 40, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 6)],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Icon(Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- "..." menu & actions ----------------------------------------------

  void _showMenu(BuildContext context, RecipeBook book, List<Recipe> members) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add / remove recipes'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _manageRecipes(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename book'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _renameBook(context, book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete book',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _deleteBook(context, book);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameBook(BuildContext context, RecipeBook book) async {
    final ctrl = TextEditingController(text: book.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename book'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !context.mounted) return;
    context.read<BookBloc>().add(UpdateBook(RecipeBook(
          id: book.id,
          name: trimmed,
          coverImagePath: book.coverImagePath,
          createdAt: book.createdAt,
        )));
  }

  Future<void> _deleteBook(BuildContext context, RecipeBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete book'),
        content: Text(
            'Delete "${book.name}"? The recipes themselves are kept — only the '
            'book is removed.'),
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
    if (confirm != true || !context.mounted) return;
    // Detach the book from any recipes that referenced it, then delete it.
    final recipeState = context.read<RecipeBloc>().state;
    if (recipeState is RecipeLoaded) {
      for (final r in recipesInBook(recipeState.recipes, book.id)) {
        final next = [...(r.bookIds ?? const <String>[])]..remove(book.id);
        context.read<RecipeBloc>().add(UpdateRecipe(r.copyWith(bookIds: next)));
      }
    }
    context.read<BookBloc>().add(DeleteBook(book.id));
    if (context.canPop()) context.pop();
  }

  void _manageRecipes(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (sheetCtx, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Recipes in this book',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: BlocBuilder<RecipeBloc, RecipeState>(
                builder: (context, state) {
                  final all = state is RecipeLoaded
                      ? state.recipes
                      : <Recipe>[];
                  if (all.isEmpty) {
                    return const Center(
                        child: Text('No recipes to add yet',
                            style: TextStyle(color: metaGrey)));
                  }
                  return ListView(
                    controller: controller,
                    children: [
                      for (final r in all)
                        CheckboxRow(
                          recipe: r,
                          bookId: widget.bookId,
                          inBook:
                              (r.bookIds ?? const []).contains(widget.bookId),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Social tab (sharing preview) ---------------------------------------
  //
  // There is no account/backend system yet, so this reflects real (honest)
  // state — the current device is always the sole owner, no collaborators,
  // no activity — rather than fabricated example people. The Invite sheet
  // and every action in it are visual previews; nothing here persists.

  Widget _socialTab(BuildContext context, RecipeBook book) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
      children: [
        _shareRow(context, book),
        const SizedBox(height: 18),
        const _SectionLabel('PEOPLE'),
        const SizedBox(height: 8),
        _peopleCard(),
        const SizedBox(height: 18),
        const _SectionLabel('RECENT ACTIVITY'),
        const SizedBox(height: 8),
        _activityCard(),
      ],
    );
  }

  Widget _shareRow(BuildContext context, RecipeBook book) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: _brand, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not shared yet',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Invite people to cook along with you',
                    style: TextStyle(fontSize: 12, color: metaGrey)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showInviteSheet(context, book),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text('Invite',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleCard() {
    return Builder(builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(15),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: _brand, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'You ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: '(this device)',
                        style: TextStyle(
                            fontSize: 12,
                            color: metaGrey,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: subtleFill(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Owner',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: metaGrey)),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _activityCard() {
    return Builder(builder: (context) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            const Icon(Icons.history, size: 34, color: Color(0xFFC7C7CC)),
            const SizedBox(height: 10),
            const Text('No activity yet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'What collaborators change will show up here once you share this book.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: metaGrey),
            ),
          ],
        ),
      );
    });
  }

  void _showInviteSheet(BuildContext context, RecipeBook book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteSheet(book: book),
    );
  }
}

/// A checkbox row toggling a recipe's membership in a book.
class CheckboxRow extends StatelessWidget {
  final Recipe recipe;
  final String bookId;
  final bool inBook;
  const CheckboxRow(
      {super.key,
      required this.recipe,
      required this.bookId,
      required this.inBook});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: inBook,
      title: Text(recipe.title),
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: _brand,
      onChanged: (checked) {
        final next = [...(recipe.bookIds ?? const <String>[])];
        if (checked == true) {
          if (!next.contains(bookId)) next.add(bookId);
        } else {
          next.remove(bookId);
        }
        context.read<RecipeBloc>().add(UpdateRecipe(recipe.copyWith(bookIds: next)));
      },
    );
  }
}

/// Small uppercase section label (PEOPLE, RECENT ACTIVITY, ...).
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9B9B),
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
      );
}

/// Shows a snackbar for an action that isn't backed by real functionality yet
/// (sharing needs accounts, which don't exist in this local-only app).
void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text('$what — coming soon (PLACEHOLDER)')));
}

/// Invite sheet for sharing a book. There is no account/backend system yet,
/// so every action here (copy link, permission choice, share channels) is a
/// visual preview only — nothing is sent or persisted.
class InviteSheet extends StatefulWidget {
  final RecipeBook book;
  const InviteSheet({super.key, required this.book});

  @override
  State<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<InviteSheet> {
  bool _canEdit = true;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(
          color: cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: hairline(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: book.coverImagePath != null
                      ? Image.file(File(book.coverImagePath!),
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 46,
                              height: 46,
                              color: groupColor(book.name)))
                      : Container(
                          width: 46, height: 46, color: groupColor(book.name)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share "${book.name}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      const Text('Anyone you invite can cook along',
                          style: TextStyle(fontSize: 13, color: metaGrey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: subtleFill(context),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: _brand, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invite link',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Requires an account — coming soon',
                            style: TextStyle(fontSize: 12, color: metaGrey)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _soon(context, 'Invite links'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: cardColor(context),
                        border: Border.all(color: hairline(context)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Copy',
                          style: TextStyle(
                              color: _brand,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const _SectionLabel('NEW PEOPLE CAN'),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: _permissionBox('Edit', 'add & change', true)),
                const SizedBox(width: 8),
                Expanded(child: _permissionBox('View only', 'cook & read', false)),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _channel(context, Icons.sms_outlined, 'Messages', const Color(0xFF34C759)),
                _channel(context, Icons.mail_outline, 'Mail', const Color(0xFF0A84FF)),
                _channel(context, Icons.more_horiz, 'More', subtleFill(context),
                    iconColor: const Color(0xFF3A3A3C)),
              ],
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionBox(String title, String subtitle, bool isEdit) {
    final selected = _canEdit == isEdit;
    return GestureDetector(
      onTap: () => setState(() => _canEdit = isEdit),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDEEDE) : subtleFill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? _brand : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? const Color(0xFFB5701D) : metaGrey)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? const Color(0xFFC79B6A)
                        : const Color(0xFFA0A0A5))),
          ],
        ),
      ),
    );
  }

  Widget _channel(BuildContext context, IconData icon, String label, Color bg,
      {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: () => _soon(context, label),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6A6A6E))),
        ],
      ),
    );
  }
}

/// A tiled montage of the book's recipe photos, filling gaps with brand-tinted
/// gradient tiles so the cover always reads as a full mosaic.
class _Mosaic extends StatelessWidget {
  final List<String> photos;
  const _Mosaic({required this.photos});

  static const _fill = <Color>[
    Color(0xFFE08A2C),
    Color(0xFF6E5BD8),
    Color(0xFF4E8A4F),
    Color(0xFFC0492E),
  ];

  @override
  Widget build(BuildContext context) {
    const cols = 6;
    const rows = 3;
    const count = cols * rows;
    return GridView.count(
      crossAxisCount: cols,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < count; i++)
          if (photos.isNotEmpty)
            Image.file(File(photos[i % photos.length]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: _fill[i % _fill.length]))
          else
            ColoredBox(color: _fill[i % _fill.length]),
      ],
    );
  }
}
