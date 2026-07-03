import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../theme/recipe_accents.dart';

const _brand = brandOrange;

/// iCloud sync. The enable/push/pull controls are the existing, functional
/// SettingsBloc-backed sync (kept unchanged). The richer status view from the
/// design (per-device status, storage breakdown) is a tagged PLACEHOLDER —
/// real sync remains future work.
class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        backgroundColor: groupedBg(context),
        title: const Text('iCloud Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
        ),
      ),
      body: BlocListener<SettingsBloc, SettingsState>(
        listenWhen: (p, c) => p.syncStatus != c.syncStatus,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.syncStatus == SyncStatus.loading) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Syncing…'),
                duration: Duration(days: 1),
              ));
          } else if (state.syncStatus == SyncStatus.success) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(
                content: Text('Sync completed'),
                backgroundColor: Colors.green,
              ));
          } else if (state.syncStatus == SyncStatus.failure) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(
                    'Sync failed: ${state.syncErrorMessage ?? "Unknown error"}'),
                backgroundColor: Colors.red,
              ));
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            final on = state.isSyncEnabled;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              children: [
                // Functional controls (existing behaviour).
                Container(
                  decoration: BoxDecoration(
                      color: cardColor(context),
                      borderRadius: BorderRadius.circular(15)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.cloud_sync, color: _brand),
                        title: const Text('Cloud sync'),
                        subtitle: Text(on
                            ? (state.lastSyncDate != null
                                ? 'Last synced ${_fmt(state.lastSyncDate!)}'
                                : 'On')
                            : 'Off · keep recipes on this device only'),
                        value: on,
                        activeTrackColor: _brand,
                        onChanged: (v) => v
                            ? _confirmEnable(context)
                            : context
                                .read<SettingsBloc>()
                                .add(const ToggleSync(false)),
                      ),
                      if (on) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('Push to cloud'),
                          subtitle: const Text('Upload local recipes'),
                          onTap: () => context
                              .read<SettingsBloc>()
                              .add(const TriggerPushSync()),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.cloud_download_outlined),
                          title: const Text('Pull from cloud'),
                          subtitle: const Text('Overwrites local recipes'),
                          onTap: () => context
                              .read<SettingsBloc>()
                              .add(const TriggerPullSync()),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // PLACEHOLDER: per-device sync state + storage breakdown.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                      color: cardColor(context),
                      borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      const Icon(Icons.devices_outlined,
                          size: 44, color: Color(0xFFC7C7CC)),
                      const SizedBox(height: 12),
                      Text('Devices & storage',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text(
                        'Per-device sync status and the iCloud storage '
                        'breakdown will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: metaGrey, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('PLACEHOLDER · sync is future work',
                            style: TextStyle(
                                fontSize: 11,
                                color: metaGrey,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmEnable(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable cloud sync?'),
        content: const Text(
            'Enabling sync overwrites local recipes with cloud data. This '
            'cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable & overwrite')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<SettingsBloc>().add(const ToggleSync(true));
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
