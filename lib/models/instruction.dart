import 'package:hive/hive.dart';

part 'instruction.g.dart';

@HiveType(typeId: 3)
class Instruction {
  @HiveField(0)
  final String description;

  /// Legacy single ingredient group. Kept for backward compatibility with
  /// existing data and the current editor; new code should prefer [groups]
  /// via [effectiveGroups].
  @HiveField(1)
  final String? group;

  @HiveField(2)
  final String? photoPath;

  /// Optional countdown for this step, in seconds. Surfaced as a timer in the
  /// cook view. Null means the step has no timer.
  @HiveField(3)
  final int? timerSeconds;

  /// The 0..n ingredient groups this step uses. A group may be shared across
  /// several steps. Null on records created before this field existed.
  @HiveField(4)
  final List<String>? groups;

  Instruction({
    required this.description,
    this.group,
    this.photoPath,
    this.timerSeconds,
    this.groups,
  });

  /// The groups this step uses, preferring the new multi-group [groups] list
  /// and falling back to the legacy single [group] for older data.
  List<String> get effectiveGroups =>
      groups ?? (group != null ? [group!] : const <String>[]);
}
