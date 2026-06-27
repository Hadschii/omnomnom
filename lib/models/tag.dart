import 'package:hive/hive.dart';

part 'tag.g.dart';

/// A first-class tag in the user's tag registry. Recipes still carry tags as
/// plain strings in `Recipe.labels`; a [Tag] adds a stable identity and colour
/// so tags can be created, recoloured and renamed from Settings even before any
/// recipe uses them. The tag's [name] is what matches `Recipe.labels`.
@HiveType(typeId: 5)
class Tag {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// ARGB colour value (use `Color(tag.color)` to render).
  @HiveField(2)
  final int color;

  Tag({required this.id, required this.name, required this.color});
}
