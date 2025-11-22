import 'package:flutter/material.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/app_logo.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          Text(
            'OmNomNom',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Version 1.0.0',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 24),
          const Text('The best recipe app in the world!'),
        ],
      ),
    );
  }
}
