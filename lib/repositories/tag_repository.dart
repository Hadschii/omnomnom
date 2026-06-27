import 'package:hive_flutter/hive_flutter.dart';
import '../models/tag.dart';

class TagRepository {
  static const String _boxName = 'tags';

  Future<void> init() async {
    await Hive.openBox<Tag>(_boxName);
  }

  Box<Tag> get _box => Hive.box<Tag>(_boxName);

  List<Tag> getTags() => _box.values.toList();

  Future<void> addTag(Tag tag) async => _box.put(tag.id, tag);

  Future<void> updateTag(Tag tag) async => _box.put(tag.id, tag);

  Future<void> deleteTag(String id) async => _box.delete(id);

  Future<void> clearAll() async => _box.clear();
}
