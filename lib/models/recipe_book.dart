import 'package:hive/hive.dart';

part 'recipe_book.g.dart';

/// A Recipe Book is a shareable collection of recipes. Membership is stored on
/// the recipe side (`Recipe.bookIds`), so a book is identified by its [id] and
/// carries only its own presentation metadata here.
///
/// Social/sharing features (members, activity, permissions) are intentionally
/// NOT modelled yet — see PLACEHOLDER notes in the Books UI.
@HiveType(typeId: 4)
class RecipeBook {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// Optional explicit cover image. When null, the UI derives a cover from the
  /// book's recipes (e.g. a mosaic of their photos).
  @HiveField(2)
  final String? coverImagePath;

  @HiveField(3)
  final DateTime createdAt;

  RecipeBook({
    required this.id,
    required this.name,
    this.coverImagePath,
    required this.createdAt,
  });
}
