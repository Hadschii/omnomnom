import '../models/ingredient.dart';
import '../models/instruction.dart';
import '../models/recipe.dart';

/// Single source of truth for turning a [Recipe] into JSON and back, used by
/// every cloud sync backend. Covers every current model field — previously
/// [GoogleDriveSyncService] and [ICloudSyncService] each carried their own
/// copy of this and both silently dropped `bookIds`, `accentColor`,
/// `Instruction.groups` and `Instruction.timerSeconds` on a round-trip.
///
/// Image fields are stored as basenames only (`imagePath?.split('/').last`);
/// callers resolve them to on-device absolute paths after downloading the
/// referenced blob.
Map<String, dynamic> recipeToJson(Recipe recipe) {
  return {
    'id': recipe.id,
    'title': recipe.title,
    'ingredients': [
      for (final i in recipe.ingredients)
        {'name': i.name, 'amount': i.amount, 'group': i.group},
    ],
    'instructions': [
      for (final s in recipe.instructions)
        {
          'description': s.description,
          'group': s.group,
          'groups': s.groups,
          'timerSeconds': s.timerSeconds,
          'photoPath': s.photoPath?.split('/').last,
        },
    ],
    'folderId': recipe.folderId,
    'labels': recipe.labels,
    'createdAt': recipe.createdAt.toIso8601String(),
    'imagePath': recipe.imagePath?.split('/').last,
    'servings': recipe.servings,
    'prepTime': recipe.prepTime,
    'cookTime': recipe.cookTime,
    'bookIds': recipe.bookIds,
    'accentColor': recipe.accentColor,
  };
}

Recipe recipeFromJson(Map<String, dynamic> json) {
  return Recipe(
    id: json['id'] as String,
    title: json['title'] as String,
    ingredients: [
      for (final e in (json['ingredients'] as List? ?? const []))
        Ingredient(
          name: (e as Map)['name'] as String? ?? '',
          amount: e['amount'] as String? ?? '',
          group: e['group'] as String?,
        ),
    ],
    instructions: [
      for (final e in (json['instructions'] as List? ?? const []))
        Instruction(
          description: (e as Map)['description'] as String? ?? '',
          group: e['group'] as String?,
          groups: (e['groups'] as List?)?.cast<String>(),
          timerSeconds: (e['timerSeconds'] as num?)?.toInt(),
          photoPath: e['photoPath'] as String?,
        ),
    ],
    folderId: json['folderId'] as String?,
    labels: (json['labels'] as List?)?.cast<String>() ?? const [],
    createdAt: DateTime.parse(json['createdAt'] as String),
    imagePath: json['imagePath'] as String?,
    servings: (json['servings'] as num?)?.toInt(),
    prepTime: (json['prepTime'] as num?)?.toInt(),
    cookTime: (json['cookTime'] as num?)?.toInt(),
    bookIds: (json['bookIds'] as List?)?.cast<String>(),
    accentColor: (json['accentColor'] as num?)?.toInt(),
  );
}
