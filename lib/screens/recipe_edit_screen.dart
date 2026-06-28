import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/tag/tag_bloc.dart';
import '../blocs/tag/tag_event.dart';
import '../blocs/tag/tag_state.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../models/recipe.dart';
import '../models/recipe_book.dart';
import '../models/tag.dart';
import '../services/ingredient_parser.dart';
import '../theme/recipe_accents.dart';

const _brand = Color(0xFFF69021);

/// Mutable editor model for a single ingredient.
class _EditIngredient {
  String name;
  String amount;
  String? group; // group name; null = ungrouped
  _EditIngredient({required this.name, this.amount = '', this.group});
}

/// Mutable editor model for a single step.
class _EditStep {
  String description;
  String? photoPath;
  int? timerSeconds;
  List<String> groups;
  _EditStep({
    this.description = '',
    this.photoPath,
    this.timerSeconds,
    List<String>? groups,
  }) : groups = groups ?? [];
}

class RecipeEditScreen extends StatefulWidget {
  final String? recipeId;

  const RecipeEditScreen({super.key, this.recipeId});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  final _titleController = TextEditingController();

  int? _servings;
  int? _prepTime;
  int? _cookTime;
  String? _imagePath;
  int? _accentColor;
  final _labels = <String>[];
  List<String> _bookIds = [];

  String? _folderId;
  DateTime? _createdAt;

  final _groups = <String>[]; // ordered ingredient group names
  final _ingredients = <_EditIngredient>[];
  final _steps = <_EditStep>[];

  int _tab = 0; // 0 = Ingredients, 1 = Steps

  bool get _isEditing => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final state = context.read<RecipeBloc>().state;
      if (state is RecipeLoaded) {
        for (final r in state.recipes) {
          if (r.id == widget.recipeId) {
            _loadFrom(r);
            break;
          }
        }
      }
    }
  }

  void _loadFrom(Recipe recipe) {
    _titleController.text = recipe.title;
    _servings = recipe.servings;
    _prepTime = recipe.prepTime;
    _cookTime = recipe.cookTime;
    _imagePath = recipe.imagePath;
    _accentColor = recipe.accentColor;
    _labels.addAll(recipe.labels);
    _folderId = recipe.folderId;
    _bookIds = List.of(recipe.bookIds ?? []);
    _createdAt = recipe.createdAt;

    for (final i in recipe.ingredients) {
      if (i.group != null && !_groups.contains(i.group)) {
        _groups.add(i.group!);
      }
      _ingredients.add(
        _EditIngredient(name: i.name, amount: i.amount, group: i.group),
      );
    }
    for (final s in recipe.instructions) {
      _steps.add(_EditStep(
        description: s.description,
        photoPath: s.photoPath,
        timerSeconds: s.timerSeconds,
        groups: List.of(s.effectiveGroups),
      ));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---- Save ---------------------------------------------------------------

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    // Ingredients ordered: ungrouped first, then by group order.
    final ordered = <_EditIngredient>[
      ..._ingredients.where((i) => i.group == null),
      for (final g in _groups) ..._ingredients.where((i) => i.group == g),
    ];
    final ingredients = [
      for (final i in ordered)
        if (i.name.trim().isNotEmpty)
          Ingredient(name: i.name.trim(), amount: i.amount.trim(), group: i.group),
    ];

    final instructions = [
      for (final s in _steps)
        if (s.description.trim().isNotEmpty)
          Instruction(
            description: s.description.trim(),
            photoPath: s.photoPath,
            timerSeconds: s.timerSeconds,
            groups: s.groups.isEmpty ? null : List.of(s.groups),
            group: s.groups.isEmpty ? null : s.groups.first,
          ),
    ];

    final recipe = Recipe(
      id: widget.recipeId ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      ingredients: ingredients,
      instructions: instructions,
      folderId: _folderId,
      labels: _labels,
      createdAt: _createdAt ?? DateTime.now(),
      imagePath: _imagePath,
      servings: _servings,
      prepTime: _prepTime,
      cookTime: _cookTime,
      bookIds: _bookIds.isEmpty ? null : _bookIds,
      accentColor: _accentColor,
    );

    final bloc = context.read<RecipeBloc>();
    if (_isEditing) {
      bloc.add(UpdateRecipe(recipe));
    } else {
      bloc.add(AddRecipe(recipe));
    }
    context.pop();
  }

  Future<String?> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.path.substring(picked.path.lastIndexOf('.'));
      final saved =
          await File(picked.path).copy('${dir.path}/${const Uuid().v4()}$ext');
      // Extract accent colour in the background; update state when ready.
      extractAccentColorFromPath(saved.path).then((color) {
        if (mounted && color != null) setState(() => _accentColor = color);
      });
      return saved.path;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancel',
              style: TextStyle(color: metaGrey, fontSize: 16)),
        ),
        leadingWidth: 80,
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: _brand, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _coverPhoto(),
          _titleField(),
          _metaRow(),
          _tagsSection(),
          _booksSection(),
          _switch(),
          const SizedBox(height: 6),
          if (_tab == 0) _ingredientsTab() else _stepsTab(),
        ],
      ),
    );
  }

  Widget _coverPhoto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: GestureDetector(
        onTap: () async {
          final path = await _pickImage();
          if (path != null) setState(() => _imagePath = path);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_imagePath != null)
                  Image.file(File(_imagePath!), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder())
                else
                  _coverPlaceholder(),
                Positioned(
                  right: 11,
                  bottom: 11,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined,
                            color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Change photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: subtleFill(context),
      alignment: Alignment.center,
      child: const Icon(Icons.add_a_photo_outlined, size: 36, color: metaGrey),
    );
  }

  Widget _titleField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Recipe title',
            ),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          Container(height: 1, color: hairline(context)),
        ],
      ),
    );
  }

  Widget _metaRow() {
    final total = (_prepTime ?? 0) + (_cookTime ?? 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: _metaBox(
              label: 'Servings',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_servings?.toString() ?? '—',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      _stepperButton(Icons.remove, () {
                        setState(() {
                          final v = (_servings ?? 1) - 1;
                          _servings = v < 1 ? 1 : v;
                        });
                      }, filled: false),
                      const SizedBox(width: 6),
                      _stepperButton(Icons.add, () {
                        setState(() => _servings = (_servings ?? 0) + 1);
                      }, filled: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _editTimes,
              child: _metaBox(
                label: 'Total time',
                child: Text(
                  total > 0 ? '$total min' : 'Set',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: total > 0 ? null : metaGrey,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaBox({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: subtleFill(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11, color: metaGrey, letterSpacing: 0.4)),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap,
      {required bool filled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: filled ? _brand : cardColor(context),
          shape: BoxShape.circle,
          border: filled ? null : Border.all(color: hairline(context)),
        ),
        child: Icon(icon,
            size: 15, color: filled ? Colors.white : metaGrey),
      ),
    );
  }

  Future<void> _editTimes() async {
    final prepCtrl =
        TextEditingController(text: _prepTime?.toString() ?? '');
    final cookCtrl =
        TextEditingController(text: _cookTime?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time (minutes)'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: prepCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Active'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: cookCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cook'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _prepTime = int.tryParse(prepCtrl.text);
                _cookTime = int.tryParse(cookCtrl.text);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ---- Books ---------------------------------------------------------------

  Widget _booksSection() {
    return BlocBuilder<BookBloc, BookState>(
      builder: (context, state) {
        final books = state is BookLoaded ? state.books : <RecipeBook>[];
        if (books.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BOOKS',
                style: TextStyle(
                    fontSize: 11, color: metaGrey, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final book in books) _bookChip(book),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bookChip(RecipeBook book) {
    final inBook = _bookIds.contains(book.id);
    return GestureDetector(
      onTap: () => setState(() {
        if (inBook) {
          _bookIds.remove(book.id);
        } else {
          _bookIds.add(book.id);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: inBook ? _brand.withValues(alpha: 0.12) : subtleFill(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inBook ? _brand : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inBook ? Icons.bookmark : Icons.bookmark_border,
              size: 14,
              color: inBook ? _brand : metaGrey,
            ),
            const SizedBox(width: 5),
            Text(
              book.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: inBook ? FontWeight.w700 : FontWeight.w500,
                color: inBook ? _brand : metaGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 2),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: subtleFill(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _switchSeg('Ingredients', 0),
            _switchSeg('Steps', 1),
          ],
        ),
      ),
    );
  }

  Widget _switchSeg(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _brand : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : metaGrey,
              )),
        ),
      ),
    );
  }

  // ---- Tags ---------------------------------------------------------------

  Widget _tagsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final label in _labels) _tagChip(label),
          GestureDetector(
            onTap: _showTagPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: subtleFill(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 14, color: metaGrey),
                  SizedBox(width: 5),
                  Text('Add tag',
                      style: TextStyle(fontSize: 13, color: metaGrey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label) {
    final tagState = context.read<TagBloc>().state;
    final tags = tagState is TagLoaded ? tagState.tags : <Tag>[];
    final color = tags
            .where((t) => t.name == label)
            .map((t) => Color(t.color))
            .firstOrNull ??
        tagColorFor(label);
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
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _labels.remove(label)),
            child: Icon(Icons.close, size: 12, color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _showTagPicker() async {
    final tagState = context.read<TagBloc>().state;
    final allTags = tagState is TagLoaded ? tagState.tags : <Tag>[];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TagPickerSheet(
        allTags: allTags,
        selected: List.of(_labels),
        onDone: (labels) => setState(() {
          _labels
            ..clear()
            ..addAll(labels);
        }),
      ),
    );
  }

  // ---- Ingredients tab ----------------------------------------------------

  Widget _ingredientsTab() {
    final ungrouped = _ingredients.where((i) => i.group == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ungrouped.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final ing in ungrouped) _ingredientRow(ing),
        ],
        _addRow('Add ingredient', () => _editIngredient(null, group: null)),
        for (final group in _groups) _groupSection(group),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: GestureDetector(
            onTap: _newGroup,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: subtleFill(context),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: metaGrey),
                  SizedBox(width: 8),
                  Text('New ingredient group',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: metaGrey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupSection(String group) {
    final items = _ingredients.where((i) => i.group == group).toList();
    final color = groupColor(group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            children: [
              Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(group.toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.4)),
              const SizedBox(width: 8),
              Text('${items.length}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFBCBCC2))),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeGroup(group),
                child: const Icon(Icons.close, size: 16, color: metaGrey),
              ),
            ],
          ),
        ),
        for (final ing in items) _ingredientRow(ing),
        _addRow('Add to $group', () => _editIngredient(null, group: group)),
      ],
    );
  }

  Widget _ingredientRow(_EditIngredient ing) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: hairline(context))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _ingredients.remove(ing)),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30), shape: BoxShape.circle),
                child: const Icon(Icons.remove, size: 15, color: Colors.white),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: GestureDetector(
                onTap: () => _editIngredient(ing, group: ing.group),
                child: Text(
                  ing.name.isEmpty ? 'Tap to edit' : ing.name,
                  style: TextStyle(
                      fontSize: 15,
                      color: ing.name.isEmpty ? metaGrey : null),
                ),
              ),
            ),
            if (ing.amount.isNotEmpty)
              Text(ing.amount,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _addRow(String label, VoidCallback onTap) {
    const color = _brand;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 17, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _editIngredient(_EditIngredient? existing,
      {String? group}) async {
    final ctrl = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amount.isEmpty
              ? existing.name
              : '${existing.amount} ${existing.name}'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add ingredient' : 'Edit ingredient'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Ingredient',
            hintText: 'e.g. 100 ml Milk',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Done')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    final parsed = IngredientParser.parse(result.trim());
    setState(() {
      if (existing == null) {
        _ingredients
            .add(_EditIngredient(name: parsed['name']!, amount: parsed['amount']!, group: group));
      } else {
        existing.name = parsed['name']!;
        existing.amount = parsed['amount']!;
      }
    });
  }

  Future<void> _newGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New ingredient group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Sauce'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || _groups.contains(trimmed)) return;
    setState(() => _groups.add(trimmed));
  }

  void _removeGroup(String group) {
    setState(() {
      // Move the group's ingredients back to ungrouped, drop the group, and
      // detach it from any steps that referenced it.
      for (final ing in _ingredients.where((i) => i.group == group)) {
        ing.group = null;
      }
      _groups.remove(group);
      for (final s in _steps) {
        s.groups.remove(group);
      }
    });
  }

  // ---- Steps tab ----------------------------------------------------------

  Widget _stepsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Text(
            '${_steps.length} steps · drag to reorder',
            style: const TextStyle(fontSize: 13, color: metaGrey),
          ),
        ),
        if (_steps.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Text('No steps yet', style: TextStyle(color: metaGrey)),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(top: 8),
            itemCount: _steps.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final s = _steps.removeAt(oldIndex);
                _steps.insert(newIndex, s);
              });
            },
            itemBuilder: (context, index) =>
                _stepCard(index, _steps[index], key: ValueKey(_steps[index])),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: GestureDetector(
            onTap: _addStep,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(
                    color: _brand.withValues(alpha: 0.35), width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: _brand),
                  SizedBox(width: 8),
                  Text('Add step',
                      style: TextStyle(
                          color: _brand,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepCard(int index, _EditStep step, {required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
      child: GestureDetector(
        onTap: () => _editStep(step),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor(context),
            border: Border.all(color: hairline(context)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface,
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${index + 1}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      step.description.isEmpty
                          ? 'Tap to add details'
                          : step.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: step.description.isEmpty
                            ? metaGrey
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (step.photoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(step.photoPath!),
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 46, height: 46)),
                    )
                  else
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: hairline(context),
                            width: 1.5,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 18, color: metaGrey),
                    ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.drag_handle, color: Color(0xFFC7C7CC)),
                    ),
                  ),
                ],
              ),
              if (step.timerSeconds != null || step.groups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      if (step.timerSeconds != null)
                        _miniPill(
                          icon: Icons.timer_outlined,
                          label: formatTimer(step.timerSeconds!),
                          color: const Color(0xFFB5701D),
                          bg: const Color(0xFFFFF4EC),
                        ),
                      for (final g in step.groups)
                        _miniPill(
                          dotColor: groupColor(g),
                          label: g,
                          color: groupColor(g),
                          bg: groupColor(g).withValues(alpha: 0.12),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniPill({
    IconData? icon,
    Color? dotColor,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          if (dotColor != null) ...[
            Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  void _addStep() {
    final step = _EditStep();
    setState(() => _steps.add(step));
    _editStep(step);
  }

  Future<void> _editStep(_EditStep step) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StepEditorSheet(
        step: step,
        groups: _groups,
        stepNumber: _steps.indexOf(step) + 1,
        pickImage: _pickImage,
      ),
    );
    if (result == 'delete') {
      setState(() => _steps.remove(step));
    } else {
      setState(() {}); // reflect edits made in place
    }
  }
}

/// Bottom-sheet editor for a single step: photo, instruction text, an optional
/// timer, and the 0..n ingredient groups it uses (chosen from existing groups).
class _StepEditorSheet extends StatefulWidget {
  final _EditStep step;
  final List<String> groups;
  final int stepNumber;
  final Future<String?> Function() pickImage;

  const _StepEditorSheet({
    required this.step,
    required this.groups,
    required this.stepNumber,
    required this.pickImage,
  });

  @override
  State<_StepEditorSheet> createState() => _StepEditorSheetState();
}

class _StepEditorSheetState extends State<_StepEditorSheet> {
  late final TextEditingController _descCtrl;
  late String? _photoPath;
  late int? _timerSeconds;
  late List<String> _selectedGroups;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.step.description);
    _photoPath = widget.step.photoPath;
    _timerSeconds = widget.step.timerSeconds;
    _selectedGroups = List.of(widget.step.groups);
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    widget.step.description = _descCtrl.text;
    widget.step.photoPath = _photoPath;
    widget.step.timerSeconds = _timerSeconds;
    widget.step.groups = _selectedGroups;
    Navigator.pop(context, 'done');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) => Column(
          children: [
            // header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: metaGrey)),
                  ),
                  Text('Step ${widget.stepNumber}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: _apply,
                    child: const Text('Done',
                        style: TextStyle(
                            color: _brand, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                children: [
                  _photoSlot(),
                  const SizedBox(height: 18),
                  _sectionLabel('INSTRUCTION'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: subtleFill(context),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    child: TextField(
                      controller: _descCtrl,
                      autofocus: widget.step.description.isEmpty,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Describe this step…',
                      ),
                      style: const TextStyle(fontSize: 15, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('TIMER'),
                  const SizedBox(height: 8),
                  _timerControl(),
                  const SizedBox(height: 20),
                  _sectionLabel('USES INGREDIENT GROUPS'),
                  const SizedBox(height: 8),
                  _groupSelector(),
                  const SizedBox(height: 14),
                  const Text(
                    'Ingredients from selected groups appear during this step '
                    'in cook-along. A group can be attached to several steps. '
                    'New groups are created in the Ingredients tab.',
                    style: TextStyle(
                        fontSize: 12.5, height: 1.5, color: Color(0xFFA0A0A5)),
                  ),
                  if (widget.step.description.isNotEmpty ||
                      _photoPath != null ||
                      _timerSeconds != null ||
                      _selectedGroups.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context, 'delete'),
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        label: const Text('Delete step',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 11, color: metaGrey, letterSpacing: 0.6),
      );

  Widget _photoSlot() {
    return GestureDetector(
      onTap: () async {
        final path = await widget.pickImage();
        if (path != null) setState(() => _photoPath = path);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: _photoPath != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(_photoPath!), fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _emptyPhoto()),
                    Positioned(
                      right: 11,
                      top: 11,
                      child: GestureDetector(
                        onTap: () => setState(() => _photoPath = null),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              : _emptyPhoto(),
        ),
      ),
    );
  }

  Widget _emptyPhoto() {
    return Container(
      color: subtleFill(context),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 30, color: metaGrey),
          SizedBox(height: 8),
          Text('Add step photo', style: TextStyle(color: metaGrey)),
        ],
      ),
    );
  }

  Widget _timerControl() {
    if (_timerSeconds == null) {
      return GestureDetector(
        onTap: () => setState(() => _timerSeconds = 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: hairline(context)),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            children: [
              Icon(Icons.timer_outlined, color: Color(0xFFB5701D)),
              SizedBox(width: 12),
              Text('Add a timer', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      );
    }
    final m = _timerSeconds! ~/ 60;
    final s = _timerSeconds! % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: hairline(context)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFB5701D)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Countdown', style: TextStyle(fontSize: 15)),
          ),
          _timeAdjust('min', m, (v) {
            setState(() => _timerSeconds = (v.clamp(0, 599)) * 60 + s);
          }),
          const SizedBox(width: 6),
          const Text(':',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          _timeAdjust('sec', s, (v) {
            setState(() => _timerSeconds = m * 60 + (v.clamp(0, 59)));
          }),
          IconButton(
            onPressed: () => setState(() => _timerSeconds = null),
            icon: const Icon(Icons.close, size: 18, color: metaGrey),
          ),
        ],
      ),
    );
  }

  Widget _timeAdjust(String label, int value, ValueChanged<int> onChange) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => onChange(value + (label == 'sec' ? 15 : 1)),
          child: const Icon(Icons.keyboard_arrow_up, size: 20),
        ),
        Text(value.toString().padLeft(2, '0'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        GestureDetector(
          onTap: () => onChange(value - (label == 'sec' ? 15 : 1)),
          child: const Icon(Icons.keyboard_arrow_down, size: 20),
        ),
      ],
    );
  }

  Widget _groupSelector() {
    if (widget.groups.isEmpty) {
      return const Text(
        'No ingredient groups yet — create them in the Ingredients tab.',
        style: TextStyle(color: metaGrey, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in widget.groups)
          GestureDetector(
            onTap: () => setState(() {
              if (_selectedGroups.contains(g)) {
                _selectedGroups.remove(g);
              } else {
                _selectedGroups.add(g);
              }
            }),
            child: _GroupChoiceChip(
              name: g,
              selected: _selectedGroups.contains(g),
            ),
          ),
      ],
    );
  }
}

class _GroupChoiceChip extends StatelessWidget {
  final String name;
  final bool selected;
  const _GroupChoiceChip({required this.name, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = groupColor(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : subtleFill(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: selected ? color : Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 1 : 0.5),
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(name,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? color : metaGrey)),
          if (selected) ...[
            const SizedBox(width: 6),
            Icon(Icons.check, size: 12, color: color),
          ],
        ],
      ),
    );
  }
}

// ---- Tag picker sheet -------------------------------------------------------

class _TagPickerSheet extends StatefulWidget {
  final List<Tag> allTags;
  final List<String> selected;
  final void Function(List<String>) onDone;

  const _TagPickerSheet({
    required this.allTags,
    required this.selected,
    required this.onDone,
  });

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  late final List<String> _selected;
  late final List<Tag> _localTags;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.selected);
    _localTags = List.of(widget.allTags);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _create() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    if (_localTags.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
      // tag already exists — just select it
      if (!_selected.contains(name)) setState(() => _selected.add(name));
      _ctrl.clear();
      return;
    }
    final tag = Tag(
      id: const Uuid().v4(),
      name: name,
      color: tagColorFor(name).toARGB32(),
    );
    context.read<TagBloc>().add(AddTag(tag));
    setState(() {
      _localTags.add(tag);
      _selected.add(name);
    });
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, controller) => Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: metaGrey)),
                  ),
                  const Text('Tags',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  TextButton(
                    onPressed: () {
                      widget.onDone(_selected);
                      Navigator.pop(context);
                    },
                    child: const Text('Done',
                        style: TextStyle(
                            color: _brand, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // new tag input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: subtleFill(context),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'New tag name…',
                        ),
                        style: const TextStyle(fontSize: 14),
                        onSubmitted: (_) => _create(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _create,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _brand,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Text('Create',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            // tag chips
            Expanded(
              child: _localTags.isEmpty
                  ? const Center(
                      child: Text('No tags yet — create one above.',
                          style: TextStyle(color: metaGrey)))
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in _localTags)
                              _TagChoiceChip(
                                tag: tag,
                                selected: _selected.contains(tag.name),
                                onTap: () => setState(() {
                                  if (_selected.contains(tag.name)) {
                                    _selected.remove(tag.name);
                                  } else {
                                    _selected.add(tag.name);
                                  }
                                }),
                              ),
                          ],
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

class _TagChoiceChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final VoidCallback onTap;
  const _TagChoiceChip(
      {required this.tag, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : subtleFill(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 1 : 0.5),
                  shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(tag.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? color : metaGrey)),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 12, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
