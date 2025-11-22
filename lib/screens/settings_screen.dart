import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SettingsList(
        onTap: (setting) {
          if (setting == 'theme') {
            context.go('/settings/theme');
          } else if (setting == 'about') {
            context.go('/settings/about');
          }
        },
      ),
    );
  }
}

class SettingsList extends StatelessWidget {
  final Function(String) onTap;

  const SettingsList({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildSectionHeader(context, 'General'),
        BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            return ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme'),
              subtitle: Text(_getThemeModeName(state.themeMode)),
              onTap: () => onTap('theme'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        ),
        const Divider(),
        _buildSectionHeader(context, 'App Info'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          onTap: () => onTap('about'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }
}
