import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/settings/settings_event.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) => previous.syncStatus != current.syncStatus,
        listener: (context, state) {
          if (state.syncStatus == SyncStatus.loading) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Syncing...'),
                    ],
                  ),
                  duration: Duration(days: 1), // Indefinite until dismissed
                ),
              );
          } else if (state.syncStatus == SyncStatus.success) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Sync completed successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
          } else if (state.syncStatus == SyncStatus.failure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Sync failed: ${state.syncErrorMessage ?? "Unknown error"}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
          }
        },
        child: SettingsList(
          onTap: (setting) {
            if (setting == 'theme') {
              context.go('/settings/theme');
            } else if (setting == 'about') {
              context.go('/settings/about');
            }
          },
        ),
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
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeModeName(state.themeMode)),
                  onTap: () => onTap('theme'),
                  trailing: const Icon(Icons.chevron_right),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync),
                  title: const Text('Cloud Sync'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sync recipes across devices'),
                      if (state.isSyncEnabled && state.lastSyncDate != null)
                        Text(
                          'Last synced: ${_formatDate(state.lastSyncDate!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  value: state.isSyncEnabled,
                  onChanged: (value) {
                    if (value) {
                      _showSyncConfirmationDialog(context);
                    } else {
                      context.read<SettingsBloc>().add(const ToggleSync(false));
                    }
                  },
                ),
                if (state.isSyncEnabled) ...[
                  ListTile(
                    leading: const Icon(Icons.cloud_upload),
                    title: const Text('Push to Cloud'),
                    subtitle: const Text('Upload local recipes to cloud'),
                    onTap: () {
                      context.read<SettingsBloc>().add(const TriggerPushSync());
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_download),
                    title: const Text('Pull from Cloud'),
                    subtitle: const Text('Download recipes from cloud (Overwrites local)'),
                    onTap: () {
                      context.read<SettingsBloc>().add(const TriggerPullSync());
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ],
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

  Future<void> _showSyncConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Cloud Sync?'),
          content: const Text(
            'Enabling sync will overwrite all local recipes with data from the cloud. '
            'This action cannot be undone.\n\n'
            'Are you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable & Overwrite'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      context.read<SettingsBloc>().add(const ToggleSync(true));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
