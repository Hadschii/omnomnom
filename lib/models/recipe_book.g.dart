// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_book.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeBookAdapter extends TypeAdapter<RecipeBook> {
  @override
  final int typeId = 4;

  @override
  RecipeBook read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeBook(
      id: fields[0] as String,
      name: fields[1] as String,
      coverImagePath: fields[2] as String?,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeBook obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.coverImagePath)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeBookAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
