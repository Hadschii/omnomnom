import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _settingsBoxName = 'settings';
  static const String _themeModeKey = 'theme_mode';

  SettingsBloc() : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<UpdateThemeMode>(_onUpdateThemeMode);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    final themeModeString = box.get(_themeModeKey, defaultValue: 'system');
    
    ThemeMode themeMode;
    switch (themeModeString) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        themeMode = ThemeMode.system;
        break;
    }

    emit(state.copyWith(themeMode: themeMode));
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    final box = await Hive.openBox(_settingsBoxName);
    
    String themeModeString;
    switch (event.themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeModeString = 'system';
        break;
    }

    await box.put(_themeModeKey, themeModeString);
    emit(state.copyWith(themeMode: event.themeMode));
  }
}
