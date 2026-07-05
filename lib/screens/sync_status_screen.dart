import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../blocs/book/book_bloc.dart';
import '../blocs/book/book_state.dart';
import '../blocs/recipe/recipe_bloc.dart';
import '../blocs/recipe/recipe_state.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../repositories/recipe_repository.dart';
import '../theme/recipe_accents.dart';

const _brand = brandOrange;

/// Cloud sync. The enable/push/pull controls and the status/storage cards
/// below are all backed by real state (RecipeRepository, RecipeBloc/BookBloc
/// counts, on-disk file sizes). The one thing that can't be real without an
/// account system is *other devices* — that stays an honest single-device
/// view rather than fabricated entries.
class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final providerName = context.read<RecipeRepository>().syncProviderName;
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        backgroundColor: groupedBg(context),
        title: Text('$providerName Sync'),
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
            final recipeCount = switch (context.watch<RecipeBloc>().state) {
              RecipeLoaded(:final recipes) => recipes.length,
              _ => 0,
            };
            final bookCount = switch (context.watch<BookBloc>().state) {
              BookLoaded(:final books) => books.length,
              _ => 0,
            };
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              children: [
                // Functional controls (existing behaviour).
                Container(
                  decoration: BoxDecoration(
                      color: cardColor(context),
                      borderRadius: BorderRadius.circular(15)),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
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
                          subtitle:
                              const Text('Merge in recipes from the cloud'),
                          onTap: () => context
                              .read<SettingsBloc>()
                              .add(const TriggerPullSync()),
                        ),
                      ],
                    ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (on) ...[
                  _StatusCard(
                    providerName: providerName,
                    state: state,
                    recipeCount: recipeCount,
                    bookCount: bookCount,
                  ),
                  const SizedBox(height: 24),
                ],

                const _SectionLabel('DEVICES'),
                const SizedBox(height: 8),
                _DevicesCard(on: on),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Other devices will appear here once they sign in with '
                    'the same $providerName account.',
                    style: const TextStyle(fontSize: 12, color: metaGrey),
                  ),
                ),
                const SizedBox(height: 24),

                const _SectionLabel('STORAGE'),
                const SizedBox(height: 8),
                const _StorageCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmEnable(BuildContext context) async {
    final providerName = context.read<RecipeRepository>().syncProviderName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enable cloud sync?'),
        content: Text(
            'Recipes already in $providerName will be merged into your '
            'library, and everything on this device will start uploading.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable sync')),
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

/// Big status card: real recipe/book counts, real last-synced time, and a
/// "Sync now" button that pulls the latest from the cloud.
class _StatusCard extends StatelessWidget {
  final String providerName;
  final SettingsState state;
  final int recipeCount;
  final int bookCount;

  const _StatusCard({
    required this.providerName,
    required this.state,
    required this.recipeCount,
    required this.bookCount,
  });

  @override
  Widget build(BuildContext context) {
    final syncing = state.syncStatus == SyncStatus.loading;
    final failed = state.syncStatus == SyncStatus.failure;
    final statusText = syncing
        ? 'Syncing…'
        : failed
            ? 'Sync failed'
            : state.lastSyncDate != null
                ? 'All changes synced'
                : 'Waiting for first sync';
    final iconBg = failed
        ? const Color(0xFFFBEAE6)
        : const Color(0xFFEAF7EE);
    final iconColor = failed ? const Color(0xFFC0492E) : const Color(0xFF34C759);
    final icon = failed ? Icons.error_outline : Icons.check;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: iconColor),
          ),
          const SizedBox(height: 13),
          Text(statusText,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            state.lastSyncDate != null
                ? 'Last synced ${_SyncStatusScreenTime.relative(state.lastSyncDate!)} · $recipeCount recipes, $bookCount books'
                : '$recipeCount recipes, $bookCount books on this device',
            style: const TextStyle(fontSize: 13, color: metaGrey),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: syncing
                ? null
                : () => context
                    .read<SettingsBloc>()
                    .add(const TriggerPullSync()),
            child: Container(
              height: 44,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEEDE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, size: 16, color: Color(0xFFB5701D)),
                  const SizedBox(width: 8),
                  Text(syncing ? 'Syncing…' : 'Sync now',
                      style: const TextStyle(
                          color: Color(0xFFB5701D),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusScreenTime {
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

/// Single, honest device row — this app has no account system, so it cannot
/// know about other devices; it never fabricates them.
class _DevicesCard extends StatelessWidget {
  final bool on;
  const _DevicesCard({required this.on});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Icon(
              Platform.isIOS || Platform.isAndroid
                  ? Icons.smartphone
                  : Icons.laptop_mac,
              size: 20,
              color: const Color(0xFF3A3A3C),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Text('This device',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: on ? const Color(0xFF34C759) : metaGrey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(on ? 'Up to date' : 'Sync off',
                style: TextStyle(
                    fontSize: 12,
                    color: on ? const Color(0xFF2E7D4F) : metaGrey,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Real local storage breakdown: sums photo files vs. everything else (the
/// Hive data files) under the app's documents directory — the same
/// directory every recipe/step photo and the Hive box already live in.
class _StorageCard extends StatefulWidget {
  const _StorageCard();

  @override
  State<_StorageCard> createState() => _StorageCardState();
}

class _StorageCardState extends State<_StorageCard> {
  static const _photoExtensions = {'jpg', 'jpeg', 'png', 'heic', 'webp'};

  late final Future<(int photoBytes, int otherBytes)> _future = _compute();

  Future<(int, int)> _compute() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) return (0, 0);
    var photoBytes = 0;
    var otherBytes = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      int length;
      try {
        length = await entity.length();
      } catch (_) {
        continue;
      }
      final ext = entity.path.split('.').last.toLowerCase();
      if (_photoExtensions.contains(ext)) {
        photoBytes += length;
      } else {
        otherBytes += length;
      }
    }
    return (photoBytes, otherBytes);
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor(context),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: FutureBuilder<(int, int)>(
        future: _future,
        builder: (context, snapshot) {
          final (photoBytes, otherBytes) = snapshot.data ?? (0, 0);
          final total = photoBytes + otherBytes;
          final photoFrac = total == 0 ? 0.0 : photoBytes / total;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Used on this device',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    snapshot.connectionState == ConnectionState.done
                        ? _fmtBytes(total)
                        : '…',
                    style: const TextStyle(fontSize: 13, color: metaGrey),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (photoFrac * 1000).round().clamp(0, 1000),
                        child: Container(color: _brand),
                      ),
                      Expanded(
                        flex: ((1 - photoFrac) * 1000).round().clamp(0, 1000),
                        child: Container(color: const Color(0xFF6E5BD8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _legend(_brand, 'Photos ${_fmtBytes(photoBytes)}'),
                  const SizedBox(width: 16),
                  _legend(const Color(0xFF6E5BD8), 'Data ${_fmtBytes(otherBytes)}'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: metaGrey)),
      ],
    );
  }
}
