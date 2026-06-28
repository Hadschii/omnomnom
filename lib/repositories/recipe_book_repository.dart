import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe_book.dart';

class RecipeBookRepository {
  static const String _boxName = 'recipe_books';
  static const String _sortOrdersBox = 'sort_orders';
  static const String _orderKey = 'books';
  static const String favoritesBookId = 'favorites';

  Future<void> init() async {
    await Hive.openBox<RecipeBook>(_boxName);
    await Hive.openBox(_sortOrdersBox);
    _seedDefaults();
  }

  void _seedDefaults() {
    if (_box.containsKey(favoritesBookId)) return;
    _box.put(
      favoritesBookId,
      RecipeBook(
        id: favoritesBookId,
        name: 'Favorites',
        createdAt: DateTime(2020),
      ),
    );
  }

  Box<RecipeBook> get _box => Hive.box<RecipeBook>(_boxName);
  Box get _orderBox => Hive.box(_sortOrdersBox);

  List<String> getBookOrder() =>
      (_orderBox.get(_orderKey) as List?)?.cast<String>() ?? [];

  Future<void> saveBookOrder(List<String> ids) async =>
      _orderBox.put(_orderKey, ids);

  List<RecipeBook> getBooks() {
    final all = {for (final b in _box.values) b.id: b};
    final order = getBookOrder();
    final sorted = <RecipeBook>[
      for (final id in order)
        if (all.containsKey(id)) all[id]!,
    ];
    for (final b in _box.values) {
      if (!order.contains(b.id)) sorted.add(b);
    }
    return sorted;
  }

  Future<void> addBook(RecipeBook book) async {
    await _box.put(book.id, book);
  }

  Future<void> updateBook(RecipeBook book) async {
    await _box.put(book.id, book);
  }

  Future<void> deleteBook(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
