import 'package:hive_flutter/hive_flutter.dart';
import '../models/tag.dart';

class TagRepository {
  static const String _boxName = 'tags';
  static const String _sortOrdersBox = 'sort_orders';
  static const String _orderKey = 'tags';

  Future<void> init() async {
    await Hive.openBox<Tag>(_boxName);
    await Hive.openBox(_sortOrdersBox);
  }

  Box<Tag> get _box => Hive.box<Tag>(_boxName);
  Box get _orderBox => Hive.box(_sortOrdersBox);

  List<String> getTagOrder() =>
      (_orderBox.get(_orderKey) as List?)?.cast<String>() ?? [];

  Future<void> saveTagOrder(List<String> names) async =>
      _orderBox.put(_orderKey, names);

  List<Tag> getTags() => _box.values.toList();

  Future<void> addTag(Tag tag) async => _box.put(tag.id, tag);

  Future<void> updateTag(Tag tag) async => _box.put(tag.id, tag);

  Future<void> deleteTag(String id) async => _box.delete(id);

  Future<void> clearAll() async => _box.clear();
}
