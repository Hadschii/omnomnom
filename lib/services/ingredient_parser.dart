class IngredientParser {
  static Map<String, String> parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return {'name': '', 'amount': ''};
    }

    // Regex for: Quantity + Unit + Name
    // Group 1: Quantity (numbers, decimals, fractions, or unicode fractions)
    // Group 2: Unit (g, kg, ml, l, cl, dl, tsp, tbsp, cup/cups, pinch/pinches, piece/pieces, stk, stck, pkg, pkt, el, tl, prise, prisen, dose, dosen, etc.)
    // Group 3: Name (remaining text)
    final unitRegex = RegExp(
      r'^(\d+(?:\s+\d+\/\d+|\/\d+|(?:[.,]\d+)?)?|[\u00BC-\u00BE\u2150-\u215E])\s*(ml|g|kg|l|cl|dl|tsp|tbsp|cups?|pinches?|pieces?|stk\.?|stck\.?|pkg\.?|pkt\.?|el\.?|tl\.?|prise|prisen|dosen|dose|fl\.?\s*oz\.?|oz|lbs?\.?|Pkt\.?|TL\.?|EL\.?|Stk\.?)(?:\s+(.*)|$)',
      caseSensitive: false,
    );

    final unitMatch = unitRegex.firstMatch(trimmed);
    if (unitMatch != null) {
      final qty = unitMatch.group(1) ?? '';
      final unit = unitMatch.group(2) ?? '';
      final name = unitMatch.group(3) ?? '';
      return {
        'amount': '$qty $unit'.trim().replaceAll(RegExp(r'\s+'), ' '),
        'name': name.trim(),
      };
    }

    // Fallback: Quantity + Name (no unit, e.g. "2 Eggs")
    final qtyRegex = RegExp(
      r'^(\d+(?:\s+\d+\/\d+|\/\d+|(?:[.,]\d+)?)?|[\u00BC-\u00BE\u2150-\u215E])\s+(.*)$',
    );
    final qtyMatch = qtyRegex.firstMatch(trimmed);
    if (qtyMatch != null) {
      final qty = qtyMatch.group(1) ?? '';
      final name = qtyMatch.group(2) ?? '';
      return {
        'amount': qty.trim(),
        'name': name.trim(),
      };
    }

    // Default: Entire string as name
    return {
      'amount': '',
      'name': trimmed,
    };
  }
}
