import 'package:flutter/material.dart';

/// PLACEHOLDER screen for the Recipe Books tab.
///
/// The full Books experience (cover shelf, a book's recipe list, and the
/// social/sharing views) is built in a later step. This stub exists so the
/// three-tab navigation skeleton — Recipes / Books / Settings — is complete
/// and navigable end to end.
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Books'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Recipe Books',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Organise recipes into shareable books.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PLACEHOLDER · coming in a later step',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
