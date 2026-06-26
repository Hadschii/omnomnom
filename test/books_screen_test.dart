import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/screens/books_screen.dart';

void main() {
  testWidgets('Books tab renders its placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BooksScreen()));

    expect(find.text('Recipe Books'), findsWidgets);
    expect(find.textContaining('PLACEHOLDER'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
  });
}
