import 'package:flutter/material.dart';
import '../widgets/theme_selector.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: ThemeSelector(),
      ),
    );
  }
}
