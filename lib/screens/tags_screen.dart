import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/tag/tag_bloc.dart';
import '../blocs/tag/tag_event.dart';
import '../blocs/tag/tag_state.dart';
import '../models/recipe.dart';
import '../models/tag.dart';
import '../theme/recipe_accents.dart';

const _brand = Color(0xFFF69021);

const _tagPalette = <int>[
  0xFFC0492E,
  0xFF4E8A4F,
  0xFF6E5BD8,
  0xFFE08A2C,
  0xFFB23A6B,
  0xFF2D6E8E,
  0xFFF69021,
  0xFF34A0E0,
];
int _tagColorFor(String name) =>
    _tagPalette[name.hashCode.abs() % _tagPalette.length];

class _TagEntry {
  final String name;
  final int color;
  final int count;
  final Tag? tag; // registered tag, if any
  _TagEntry(this.name, this.color, this.count, this.tag);
}

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        title: const Text('Tags'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: BlocBuilder<TagBloc, TagState>(
        builder: (context, tagState) {
          final tags = tagState is TagLoaded ? tagState.tags : <Tag>[];
          return BlocBuilder<RecipeBloc, RecipeState>(
            builder: (context, recipeState) {
              final recipes = recipeState is RecipeLoaded
                  ? recipeState.recipes
                  : <Recipe>[];
              final entries = _merge(tags, recipes);
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 2),
                    child: Text('${entries.length} tags · used to filter recipes',
                        style: const TextStyle(fontSize: 13, color: metaGrey)),
                  ),
                  // add row
                  _AddRow(label: 'New tag…', onTap: () => _addTag(context, tags)),
                  const SizedBox(height: 20),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('No tags yet', style: TextStyle(color: metaGrey)),
                    )
                  else
                    _Card(
                      children: [
                        for (final e in entries)
                          _TagRow(
                            entry: e,
                            onRemove: () => _deleteTag(context, e, recipes),
                            onRename: () => _renameTag(context, e, recipes),
                          ),
                      ],
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_TagEntry> _merge(List<Tag> tags, List<Recipe> recipes) {
    final counts = <String, int>{};
    for (final r in recipes) {
      for (final l in r.labels) {
        counts[l] = (counts[l] ?? 0) + 1;
      }
    }
    final byName = {for (final t in tags) t.name: t};
    final names = <String>{...byName.keys, ...counts.keys}.toList()..sort();
    return [
      for (final n in names)
        _TagEntry(n, byName[n]?.color ?? _tagColorFor(n), counts[n] ?? 0,
            byName[n]),
    ];
  }

  Future<void> _addTag(BuildContext context, List<Tag> existing) async {
    final name = await _prompt(context, 'New tag', 'e.g. Weeknight');
    if (name == null || name.isEmpty || !context.mounted) return;
    if (existing.any((t) => t.name.toLowerCase() == name.toLowerCase())) return;
    context.read<TagBloc>().add(AddTag(Tag(
          id: const Uuid().v4(),
          name: name,
          color: _tagColorFor(name),
        )));
  }

  void _deleteTag(BuildContext context, _TagEntry e, List<Recipe> recipes) {
    if (e.tag != null) context.read<TagBloc>().add(DeleteTag(e.tag!.id));
    // strip the label from every recipe that carries it
    for (final r in recipes) {
      if (r.labels.contains(e.name)) {
        final next = [...r.labels]..remove(e.name);
        context.read<RecipeBloc>().add(UpdateRecipe(r.copyWith(labels: next)));
      }
    }
  }

  Future<void> _renameTag(
      BuildContext context, _TagEntry e, List<Recipe> recipes) async {
    final name = await _prompt(context, 'Rename tag', e.name, initial: e.name);
    if (name == null || name.isEmpty || name == e.name || !context.mounted) {
      return;
    }
    if (e.tag != null) {
      context
          .read<TagBloc>()
          .add(UpdateTag(Tag(id: e.tag!.id, name: name, color: e.color)));
    }
    for (final r in recipes) {
      if (r.labels.contains(e.name)) {
        final next = <String>[];
        for (final l in r.labels) {
          final mapped = l == e.name ? name : l;
          if (!next.contains(mapped)) next.add(mapped);
        }
        context.read<RecipeBloc>().add(UpdateRecipe(r.copyWith(labels: next)));
      }
    }
  }

  Future<String?> _prompt(BuildContext context, String title, String hint,
      {String? initial}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    return result?.trim();
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(
            height: 1, thickness: 1, indent: 14, color: Color(0xFFF2F2F4)));
      }
    }
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddRow({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                  color: Color(0xFF34C759), shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 16, color: Color(0xFFB0B0B5))),
            ),
            const Text('Add',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _brand)),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final _TagEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onRename;
  const _TagRow(
      {required this.entry, required this.onRemove, required this.onRename});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRename,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            Container(
              width: 11,
              height: 11,
              decoration:
                  BoxDecoration(color: Color(entry.color), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(entry.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Text('${entry.count}',
                style: const TextStyle(fontSize: 14, color: Color(0xFFA0A0A5))),
          ],
        ),
      ),
    );
  }
}
