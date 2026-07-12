import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/download_task.dart';

class StorageService {
  static const String _boxName = 'downloads_box';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  List<DownloadTask> getAllTasks() {
    try {
      final list = _box.values.map((val) {
        final Map<dynamic, dynamic> map = val as Map;
        return DownloadTask.fromMap(map);
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  Future<void> saveTask(DownloadTask task) async {
    await _box.put(task.id, task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  Stream<BoxEvent> watchTasks() {
    return _box.watch();
  }
}
