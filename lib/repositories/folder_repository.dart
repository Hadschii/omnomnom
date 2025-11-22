import 'package:hive_flutter/hive_flutter.dart';
import '../models/folder.dart';

class FolderRepository {
  static const String _boxName = 'folders';

  Future<void> init() async {
    await Hive.openBox<Folder>(_boxName);
  }

  Box<Folder> get _box => Hive.box<Folder>(_boxName);

  List<Folder> getFolders() {
    return _box.values.toList();
  }

  Future<void> addFolder(Folder folder) async {
    await _box.put(folder.id, folder);
  }

  Future<void> updateFolder(Folder folder) async {
    await _box.put(folder.id, folder);
  }

  Future<void> deleteFolder(String id) async {
    await _box.delete(id);
  }
  
  Future<void> clearAll() async {
    await _box.clear();
  }
}
