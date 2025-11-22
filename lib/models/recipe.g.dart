// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 2;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String,
      title: fields[1] as String,
      ingredients: (fields[2] as List).cast<Ingredient>(),
      instructions: (fields[3] as List).cast<Instruction>(),
      folderId: fields[4] as String?,
      labels: (fields[5] as List).cast<String>(),
      createdAt: fields[6] as DateTime,
      imagePath: fields[7] as String?,
      servings: fields[8] as int?,
      prepTime: fields[9] as int?,
      cookTime: fields[10] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.ingredients)
      ..writeByte(3)
      ..write(obj.instructions)
      ..writeByte(4)
      ..write(obj.folderId)
      ..writeByte(5)
      ..write(obj.labels)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.imagePath)
      ..writeByte(8)
      ..write(obj.servings)
      ..writeByte(9)
      ..write(obj.prepTime)
      ..writeByte(10)
      ..write(obj.cookTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
