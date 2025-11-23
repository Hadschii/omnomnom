import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool isSyncEnabled;
  final DateTime? lastSyncDate;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.isSyncEnabled = false,
    this.lastSyncDate,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? isSyncEnabled,
    DateTime? lastSyncDate,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      isSyncEnabled: isSyncEnabled ?? this.isSyncEnabled,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
    );
  }

  @override
  List<Object?> get props => [themeMode, isSyncEnabled, lastSyncDate];
}
