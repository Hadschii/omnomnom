import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThemeOption(context, 'System Default', ThemeMode.system, state.themeMode),
            _buildThemeOption(context, 'Light Mode', ThemeMode.light, state.themeMode),
            _buildThemeOption(context, 'Dark Mode', ThemeMode.dark, state.themeMode),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    ThemeMode mode,
    ThemeMode currentMode,
  ) {
    return RadioListTile<ThemeMode>(
      title: Text(title),
      value: mode,
      groupValue: currentMode,
      onChanged: (value) {
        if (value != null) {
          context.read<SettingsBloc>().add(UpdateThemeMode(value));
        }
      },
    );
  }
}
