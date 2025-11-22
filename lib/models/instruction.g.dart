// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instruction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstructionAdapter extends TypeAdapter<Instruction> {
  @override
  final int typeId = 3;

  @override
  Instruction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Instruction(
      description: fields[0] as String,
      group: fields[1] as String?,
      photoPath: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Instruction obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.group)
      ..writeByte(2)
      ..write(obj.photoPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstructionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
