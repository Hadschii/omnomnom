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
  });
}
