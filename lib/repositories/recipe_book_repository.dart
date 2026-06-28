import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe_book.dart';

class RecipeBookRepository {
  static const String _boxName = 'recipe_books';
  static const String favoritesBookId = 'favorites';

  Future<void> init() async {
    await Hive.openBox<RecipeBook>(_boxName);
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

  List<RecipeBook> getBooks() {
    return _box.values.toList();
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
