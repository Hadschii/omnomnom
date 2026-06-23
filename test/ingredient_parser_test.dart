import 'package:flutter_test/flutter_test.dart';
import 'package:omnomnom_recipe_app/services/ingredient_parser.dart';

void main() {
  group('IngredientParser Tests', () {
    test('Parses quantity and unit adjacent (no space)', () {
      final result = IngredientParser.parse('100ml Water');
      expect(result['amount'], '100 ml');
      expect(result['name'], 'Water');
    });

    test('Parses quantity and unit with space', () {
      final result = IngredientParser.parse('100 ml Water');
      expect(result['amount'], '100 ml');
      expect(result['name'], 'Water');
    });

    test('Parses quantity and unit (German)', () {
      final result = IngredientParser.parse('200g Mehl');
      expect(result['amount'], '200 g');
      expect(result['name'], 'Mehl');
    });

    test('Parses quantity with fraction and unit', () {
      final result = IngredientParser.parse('1/2 TL Salz');
      expect(result['amount'], '1/2 TL');
      expect(result['name'], 'Salz');
    });

    test('Parses quantity with fraction and unit (German abbreviation)', () {
      final result = IngredientParser.parse('1 Pkt. Vanillezucker');
      expect(result['amount'], '1 Pkt.');
      expect(result['name'], 'Vanillezucker');
    });

    test('Parses quantity only (no unit)', () {
      final result = IngredientParser.parse('2 Eggs');
      expect(result['amount'], '2');
      expect(result['name'], 'Eggs');
    });

    test('Parses decimals', () {
      final result = IngredientParser.parse('1.5 kg Apples');
      expect(result['amount'], '1.5 kg');
      expect(result['name'], 'Apples');
    });

    test('Parses decimals with comma', () {
      final result = IngredientParser.parse('1,5 kg Apples');
      expect(result['amount'], '1,5 kg');
      expect(result['name'], 'Apples');
    });

    test('Parses unicode fractions', () {
      final result = IngredientParser.parse('½ cup Milk');
      expect(result['amount'], '½ cup');
      expect(result['name'], 'Milk');
    });

    test('Parses name only (no quantity, no unit)', () {
      final result = IngredientParser.parse('Water');
      expect(result['amount'], '');
      expect(result['name'], 'Water');
    });

    test('Parses empty or whitespace inputs', () {
      final result = IngredientParser.parse('   ');
      expect(result['amount'], '');
      expect(result['name'], '');
    });

    test('Correctly handles unit words as part of names when no digit prefix is present', () {
      final result = IngredientParser.parse('Ginger');
      expect(result['amount'], '');
      expect(result['name'], 'Ginger');
    });

    test('Correctly handles unit words as part of names with a digit prefix', () {
      final result = IngredientParser.parse('1 Ginger');
      expect(result['amount'], '1');
      expect(result['name'], 'Ginger');
    });
  });
}
