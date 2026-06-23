import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SyncStatus { idle, loading, success, failure }

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool isSyncEnabled;
  final DateTime? lastSyncDate;
  final SyncStatus syncStatus;
  final String? syncErrorMessage;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.isSyncEnabled = false,
    this.lastSyncDate,
    this.syncStatus = SyncStatus.idle,
    this.syncErrorMessage,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? isSyncEnabled,
    DateTime? lastSyncDate,
    SyncStatus? syncStatus,
    String? syncErrorMessage,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      syncStatus: syncStatus ?? this.syncStatus,
      syncErrorMessage: syncErrorMessage, // We don't use ?? to allow clearing error message by passing null
    );
  }

  @override
  List<Object?> get props => [
        themeMode,
        isSyncEnabled,
        lastSyncDate,
        syncStatus,
        syncErrorMessage,
      ];
}
