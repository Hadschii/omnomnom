import 'package:hive/hive.dart';
import 'ingredient.dart';
import 'instruction.dart';

part 'recipe.g.dart';

@HiveType(typeId: 2)
class Recipe {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<Ingredient> ingredients;

  @HiveField(3)
  final List<Instruction> instructions;

  /// Deprecated: the Folder feature was retired in favour of Recipe Books
  /// (`bookIds`). Kept only so existing Hive records still read; do not build
  /// new features on it.
  @HiveField(4)
  final String? folderId;

  @HiveField(5)
  final List<String> labels;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String? imagePath;

  @HiveField(8)
  final int? servings;

  @HiveField(9)
  final int? prepTime; // in minutes

  @HiveField(10)
  final int? cookTime; // in minutes

  /// The recipe books this recipe belongs to (many-to-many). A recipe can be
  /// in 0..n books. This is the source of truth for book membership. Null on
  /// records created before this field existed.
  @HiveField(11)
  final List<String>? bookIds;

  /// ARGB32 accent colour sampled from [imagePath]. Null until a photo is set.
  @HiveField(12)
  final int? accentColor;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.folderId,
    required this.labels,
    required this.createdAt,
    this.imagePath,
    this.servings,
    this.prepTime,
    this.cookTime,
    this.bookIds,
    this.accentColor,
  });

  /// Returns a copy with the given fields replaced. Each argument falls back to
  /// the current value when omitted (so nullable fields can't be cleared here).
  Recipe copyWith({
    String? id,
    String? title,
    List<Ingredient>? ingredients,
    List<Instruction>? instructions,
    String? folderId,
    List<String>? labels,
    DateTime? createdAt,
    String? imagePath,
    int? servings,
    int? prepTime,
    int? cookTime,
    List<String>? bookIds,
    int? accentColor,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      folderId: folderId ?? this.folderId,
      labels: labels ?? this.labels,
      createdAt: createdAt ?? this.createdAt,
      imagePath: imagePath ?? this.imagePath,
      servings: servings ?? this.servings,
      prepTime: prepTime ?? this.prepTime,
      cookTime: cookTime ?? this.cookTime,
      bookIds: bookIds ?? this.bookIds,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}
