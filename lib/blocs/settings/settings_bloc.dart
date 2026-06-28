import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'settings_event.dart';
import 'settings_state.dart';

import '../../repositories/recipe_repository.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _settingsBoxName = 'settings';
  static const String _themeModeKey = 'theme_mode';
  static const String _syncEnabledKey = 'sync_enabled';
  static const String _lastSyncDateKey = 'last_sync_date';
  static const String _accentFromPhotoKey = 'accent_from_photo';
  
  final RecipeRepository _recipeRepository;

  SettingsBloc({required RecipeRepository recipeRepository}) 
      : _recipeRepository = recipeRepository,
        super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<ToggleSync>(_onToggleSync);
    on<UpdateLastSyncDate>(_onUpdateLastSyncDate);
    on<TriggerPushSync>(_onTriggerPushSync);
    on<TriggerPullSync>(_onTriggerPullSync);
    on<ToggleAccentFromPhoto>(_onToggleAccentFromPhoto);

    // Listen to sync completion events
    _recipeRepository.onSyncCompleted.listen((date) {
      add(UpdateLastSyncDate(date));
    });
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    final themeModeIndex = box.get(_themeModeKey, defaultValue: ThemeMode.system.index);
    final themeMode = ThemeMode.values[themeModeIndex];
    final isSyncEnabled = box.get(_syncEnabledKey, defaultValue: false);
    final accentFromPhoto = box.get(_accentFromPhotoKey, defaultValue: true);
    final lastSyncDateMillis = box.get(_lastSyncDateKey);
    final lastSyncDate = lastSyncDateMillis != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncDateMillis) 
        : null;
    
    // Sync with repository state
    bool actualSyncState = isSyncEnabled;
    String? syncError;
    try {
      if (isSyncEnabled) {
        await _recipeRepository.enableSync();
      } else {
        await _recipeRepository.disableSync();
      }
    } catch (e) {
      print('SettingsBloc: Failed to initialize sync on load: $e');
      actualSyncState = false; // Fallback to disabled if initialization fails
      syncError = e.toString().replaceAll('Exception: ', '');
    }

    emit(state.copyWith(
      themeMode: themeMode,
      isSyncEnabled: actualSyncState,
      lastSyncDate: lastSyncDate,
      syncStatus: syncError != null ? SyncStatus.failure : SyncStatus.idle,
      syncErrorMessage: syncError,
      accentFromPhoto: accentFromPhoto,
    ));
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_themeModeKey, event.themeMode.index);
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onToggleSync(
    ToggleSync event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(syncStatus: SyncStatus.loading, syncErrorMessage: null));
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_syncEnabledKey, event.isEnabled);
    
    try {
      if (event.isEnabled) {
        await _recipeRepository.enableSync();
      } else {
        await _recipeRepository.disableSync();
      }
      emit(state.copyWith(
        isSyncEnabled: event.isEnabled,
        syncStatus: SyncStatus.success,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSyncEnabled: false, // fallback to disabled if initialization fails
        syncStatus: SyncStatus.failure,
        syncErrorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onUpdateLastSyncDate(
    UpdateLastSyncDate event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_lastSyncDateKey, event.lastSyncDate.millisecondsSinceEpoch);
    emit(state.copyWith(
      lastSyncDate: event.lastSyncDate,
      syncStatus: SyncStatus.success,
    ));
  }

  Future<void> _onTriggerPushSync(
    TriggerPushSync event,
    Emitter<SettingsState> emit,
  ) async {
    if (!state.isSyncEnabled) return;
    
    emit(state.copyWith(syncStatus: SyncStatus.loading, syncErrorMessage: null));
    try {
      await _recipeRepository.syncToCloud();
      emit(state.copyWith(syncStatus: SyncStatus.success));
    } catch (e) {
      emit(state.copyWith(
        syncStatus: SyncStatus.failure,
        syncErrorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onTriggerPullSync(
    TriggerPullSync event,
    Emitter<SettingsState> emit,
  ) async {
    if (!state.isSyncEnabled) return;

    emit(state.copyWith(syncStatus: SyncStatus.loading, syncErrorMessage: null));
    try {
      await _recipeRepository.syncFromCloud();
      emit(state.copyWith(syncStatus: SyncStatus.success));
    } catch (e) {
      emit(state.copyWith(
        syncStatus: SyncStatus.failure,
        syncErrorMessage: e.toString().replaceAll('Exception: ', ''),
      ));
    }
  }

  Future<void> _onToggleAccentFromPhoto(
    ToggleAccentFromPhoto event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_accentFromPhotoKey, event.enabled);
    emit(state.copyWith(accentFromPhoto: event.enabled));
  }
}
