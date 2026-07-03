import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_event.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_event.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/tag/tag_bloc.dart';
import '../blocs/tag/tag_event.dart';
import '../blocs/tag/tag_state.dart';
import '../repositories/recipe_book_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/tag_repository.dart';
import '../services/library_io_service.dart';
import '../theme/recipe_accents.dart';

const _brand = brandOrange;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookCount = switch (context.watch<BookBloc>().state) {
      BookLoaded(:final books) => books.length,
      _ => 0,
    };
    final tagCount = switch (context.watch<TagBloc>().state) {
      TagLoaded(:final tags) => tags.length,
      _ => 0,
    };

    return Scaffold(
      backgroundColor: groupedBg(context),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 8, 22, 12),
            child: Text('Settings',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
          ),
          // Profile — PLACEHOLDER: there are no accounts yet, this is a local
          // library; an account/profile lands with sharing.
          _Card(rows: [
            _NavRow(
              leadingColor: _brand,
              leading: const Text('🍳', style: TextStyle(fontSize: 22)),
              title: 'Your Library',
              subtitle: 'On this device · accounts coming with sharing',
              onTap: null,
            ),
          ]),
          // Sync summary -> dedicated screen (functional toggle lives there).
          _SyncSummaryCard(),

          _SectionHeader('LIBRARY'),
          _Card(rows: [
            _NavRow(
              leadingColor: _brand,
              leading: const Icon(Icons.menu_book, color: Colors.white, size: 17),
              title: 'Recipe Books',
              trailing: Text('$bookCount',
                  style: const TextStyle(fontSize: 15, color: metaGrey)),
              onTap: () => context.go('/settings/books'),
            ),
            _NavRow(
              leadingColor: const Color(0xFF6E5BD8),
              leading: const Icon(Icons.sell_outlined,
                  color: Colors.white, size: 17),
              title: 'Tags',
              trailing: Text('$tagCount',
                  style: const TextStyle(fontSize: 15, color: metaGrey)),
              onTap: () => context.go('/settings/tags'),
            ),
          ]),

          _SectionHeader('APPEARANCE'),
          _Card(rows: [
            _NavRow(
              leadingColor: const Color(0xFF1C1C1E),
              leading: const Icon(Icons.brightness_6,
                  color: Colors.white, size: 17),
              title: 'Theme',
              trailing: BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, s) => Text(_themeName(s.themeMode),
                    style: const TextStyle(fontSize: 15, color: metaGrey)),
              ),
              onTap: () => context.go('/settings/theme'),
            ),
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, s) => _SwitchRow(
                leadingColor: const Color(0xFFD2542B),
                leading: const Icon(Icons.palette_outlined,
                    color: Colors.white, size: 17),
                title: 'Accent colour from photo',
                value: s.accentFromPhoto,
                onChanged: (v) => context
                    .read<SettingsBloc>()
                    .add(ToggleAccentFromPhoto(v)),
              ),
            ),
            // PLACEHOLDER: unit conversion not implemented.
            _NavRow(
              leadingColor: const Color(0xFF4E8A4F),
              leading: const Icon(Icons.straighten, color: Colors.white, size: 17),
              title: 'Units',
              trailing: const Text('Metric',
                  style: TextStyle(fontSize: 15, color: metaGrey)),
              onTap: () => _soon(context, 'Units'),
            ),
          ]),

          _SectionHeader('COOKING'),
          _Card(rows: [
            // PLACEHOLDER: timer sound preference not implemented.
            _SwitchRow(
              leadingColor: _brand,
              leading: const Icon(Icons.notifications_active_outlined,
                  color: Colors.white, size: 17),
              title: 'Timer sounds',
              value: true,
              onChanged: (_) => _soon(context, 'Timer sounds'),
            ),
            // PLACEHOLDER: step text size preference not implemented.
            _NavRow(
              leadingColor: const Color(0xFF6E5BD8),
              leading:
                  const Icon(Icons.format_size, color: Colors.white, size: 17),
              title: 'Step text size',
              trailing: const Text('Large',
                  style: TextStyle(fontSize: 15, color: metaGrey)),
              onTap: () => _soon(context, 'Step text size'),
            ),
          ]),

          _SectionHeader('DATA'),
          _Card(rows: [
            _NavRow(
              leadingColor: const Color(0xFF4E8A4F),
              leading: const Icon(Icons.ios_share, color: Colors.white, size: 17),
              title: 'Export as ZIP (with photos)',
              onTap: () => _exportZip(context),
            ),
            _NavRow(
              leadingColor: const Color(0xFF34A0E0),
              leading: const Icon(Icons.description_outlined,
                  color: Colors.white, size: 17),
              title: 'Export as JSON (data only)',
              onTap: () => _exportJson(context),
            ),
            _NavRow(
              leadingColor: _brand,
              leading: const Icon(Icons.file_download_outlined,
                  color: Colors.white, size: 17),
              title: 'Import library…',
              onTap: () => _import(context),
            ),
            _NavRow(
              leadingColor: const Color(0xFFFF3B30),
              leading:
                  const Icon(Icons.delete_outline, color: Colors.white, size: 17),
              title: 'Delete all data',
              onTap: () => _deleteAll(context),
            ),
          ]),

          _SectionHeader('ABOUT'),
          _Card(rows: [
            _NavRow(
              leadingColor: const Color(0xFF8E8E93),
              leading:
                  const Icon(Icons.info_outline, color: Colors.white, size: 17),
              title: 'About',
              onTap: () => context.go('/settings/about'),
            ),
          ]),
        ],
      ),
    );
  }

  static LibraryIoService _io(BuildContext c) => LibraryIoService(
        recipeRepo: c.read<RecipeRepository>(),
        bookRepo: c.read<RecipeBookRepository>(),
        tagRepo: c.read<TagRepository>(),
      );

  static void _snack(ScaffoldMessengerState m, String text) => m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  static Future<void> _exportZip(BuildContext context) async {
    final service = _io(context);
    final messenger = ScaffoldMessenger.of(context);
    _snack(messenger, 'Preparing export…');
    try {
      final file = await service.exportZipFile();
      await Share.shareXFiles([XFile(file.path)], subject: 'OmNomNom library');
    } catch (e) {
      _snack(messenger, 'Export failed: $e');
    }
  }

  static Future<void> _exportJson(BuildContext context) async {
    final service = _io(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await service.exportJsonFile();
      await Share.shareXFiles([XFile(file.path)],
          subject: 'OmNomNom library (data only)');
    } catch (e) {
      _snack(messenger, 'Export failed: $e');
    }
  }

  static Future<void> _import(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return;
    final service = _io(context);
    final messenger = ScaffoldMessenger.of(context);
    final recipeBloc = context.read<RecipeBloc>();
    final bookBloc = context.read<BookBloc>();
    final tagBloc = context.read<TagBloc>();
    try {
      final s = await service.importFromFile(path);
      recipeBloc.add(LoadRecipes());
      bookBloc.add(LoadBooks());
      tagBloc.add(LoadTags());
      _snack(messenger,
          'Imported ${s.recipes} recipes, ${s.books} books, ${s.tags} tags');
    } catch (e) {
      _snack(messenger, 'Import failed: $e');
    }
  }

  static Future<void> _deleteAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'This permanently removes every recipe, book and tag stored on '
            'this device. Export first if you want a backup. This cannot be '
            'undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete everything',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final recipeRepo = context.read<RecipeRepository>();
    final bookRepo = context.read<RecipeBookRepository>();
    final tagRepo = context.read<TagRepository>();
    final recipeBloc = context.read<RecipeBloc>();
    final bookBloc = context.read<BookBloc>();
    final tagBloc = context.read<TagBloc>();
    final messenger = ScaffoldMessenger.of(context);
    await recipeRepo.clearAll();
    await bookRepo.clearAll();
    await tagRepo.clearAll();
    recipeBloc.add(LoadRecipes());
    bookBloc.add(LoadBooks());
    tagBloc.add(LoadTags());
    _snack(messenger, 'All data deleted');
  }

  static String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('$what — coming soon (PLACEHOLDER)')));
  }
}

class _SyncSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, s) {
        final on = s.isSyncEnabled;
        return _Card(rows: [
          _NavRow(
            leadingColor: const Color(0xFF34A0E0),
            leading: const Icon(Icons.cloud_outlined,
                color: Colors.white, size: 18),
            title: 'iCloud Sync',
            subtitleWidget: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: on ? const Color(0xFF34C759) : metaGrey,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(on ? 'On' : 'Off',
                    style: TextStyle(
                        fontSize: 12,
                        color: on ? const Color(0xFF2E7D4F) : metaGrey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            onTap: () => context.go('/settings/sync'),
          ),
        ]);
      },
    );
  }
}

// ---- Reusable iOS-style list primitives ----------------------------------

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9B9B),
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> rows;
  const _Card({required this.rows});
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
            height: 1, thickness: 1, indent: 15, color: hairline(context)));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      decoration: BoxDecoration(
          color: cardColor(context), borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _IconBox extends StatelessWidget {
  final Color color;
  final Widget child;
  const _IconBox({required this.color, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: child,
      );
}

class _NavRow extends StatelessWidget {
  final Color leadingColor;
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _NavRow({
    required this.leadingColor,
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            _IconBox(color: leadingColor, child: leading),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 2),
                    subtitleWidget!,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: metaGrey)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFC7C7CC)),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final Color leadingColor;
  final Widget leading;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.leadingColor,
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          _IconBox(color: leadingColor, child: leading),
          const SizedBox(width: 13),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: _brand),
        ],
      ),
    );
  }
}
