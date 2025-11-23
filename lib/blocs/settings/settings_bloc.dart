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
    final lastSyncDateMillis = box.get(_lastSyncDateKey);
    final lastSyncDate = lastSyncDateMillis != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncDateMillis) 
        : null;
    
    // Sync with repository state
    if (isSyncEnabled) {
      await _recipeRepository.enableSync();
    } else {
      await _recipeRepository.disableSync();
    }

    emit(state.copyWith(
      themeMode: themeMode,
      isSyncEnabled: isSyncEnabled,
      lastSyncDate: lastSyncDate,
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
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_syncEnabledKey, event.isEnabled);
    
    if (event.isEnabled) {
      await _recipeRepository.enableSync();
    } else {
      await _recipeRepository.disableSync();
    }
    
    emit(state.copyWith(isSyncEnabled: event.isEnabled));
  }

  Future<void> _onUpdateLastSyncDate(
    UpdateLastSyncDate event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    await box.put(_lastSyncDateKey, event.lastSyncDate.millisecondsSinceEpoch);
    emit(state.copyWith(lastSyncDate: event.lastSyncDate));
  }

  Future<void> _onTriggerPushSync(
    TriggerPushSync event,
    Emitter<SettingsState> emit,
  ) async {
    if (state.isSyncEnabled) {
      await _recipeRepository.syncToCloud();
    }
  }

  Future<void> _onTriggerPullSync(
    TriggerPullSync event,
    Emitter<SettingsState> emit,
  ) async {
    if (state.isSyncEnabled) {
      await _recipeRepository.syncFromCloud();
    }
  }
}
