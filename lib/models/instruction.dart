import 'package:hive/hive.dart';

part 'instruction.g.dart';

@HiveType(typeId: 3)
class Instruction {
  @HiveField(0)
  final String description;

  @HiveField(1)
  final String? group;

  @HiveField(2)
  final String? photoPath;

  Instruction({
    required this.description,
    this.group,
    this.photoPath,
  });
}
