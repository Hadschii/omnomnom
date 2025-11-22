import 'package:flutter/material.dart';
import '../widgets/about_view.dart';

class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: AboutView(),
      ),
    );
  }
}
