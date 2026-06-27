import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_state.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/tag/tag_bloc.dart';
import '../blocs/tag/tag_state.dart';
import '../theme/recipe_accents.dart';

const _brand = Color(0xFFF69021);

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
      backgroundColor: const Color(0xFFF5F5F7),
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
            // PLACEHOLDER: per-recipe accent extraction isn't implemented;
            // the toggle is inert for now.
            _SwitchRow(
              leadingColor: const Color(0xFFD2542B),
              leading:
                  const Icon(Icons.palette_outlined, color: Colors.white, size: 17),
              title: 'Accent colour from photo',
              value: false,
              onChanged: (_) => _soon(context, 'Accent from photo'),
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
        children.add(const Divider(
            height: 1, thickness: 1, indent: 15, color: Color(0xFFF2F2F4)));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
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
