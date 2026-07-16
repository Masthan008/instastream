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

  bool getThemePreference() {
    return _box.get('is_dark_mode', defaultValue: false) as bool;
  }

  Future<void> saveThemePreference(bool isDark) async {
    await _box.put('is_dark_mode', isDark);
  }

  static const List<String> defaultBlockedDomains = [
    'doubleclick.net',
    'googleadservices.com',
    'googlesyndication.com',
    'adservice.google.com',
    'adsystem',
    'popads.net',
    'popcash.net',
    'adsterra',
    'exoclick',
    'propellerads',
    'onclickads',
    'adsterramedia',
    'juicyads',
  ];

  List<String> getBlockedDomains() {
    final list = _box.get('blocked_domains');
    if (list == null) {
      return List<String>.from(defaultBlockedDomains);
    }
    return List<String>.from(list as List);
  }

  Future<void> saveBlockedDomains(List<String> domains) async {
    await _box.put('blocked_domains', domains);
  }

  int getMaxConcurrentDownloads() {
    return _box.get('max_concurrent_downloads', defaultValue: 2) as int;
  }

  Future<void> saveMaxConcurrentDownloads(int count) async {
    await _box.put('max_concurrent_downloads', count);
  }

  bool getSmartModeEnabled() {
    return _box.get('smart_mode', defaultValue: false) as bool;
  }

  Future<void> saveSmartModeEnabled(bool enabled) async {
    await _box.put('smart_mode', enabled);
  }

  String? getPreferredFormat(String sourceType) {
    return _box.get('preferred_format_$sourceType') as String?;
  }

  Future<void> savePreferredFormat(String sourceType, String formatId) async {
    await _box.put('preferred_format_$sourceType', formatId);
  }
}
