import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../security/encryption_service.dart';
import '../errors/app_exceptions.dart';

class OfflineManager {
  static const String _boxName = 'epi_offline';
  static const String _syncQueueKey = 'sync_queue';
  static const String _draftsKey = 'drafts';
  static const String _cacheKey = 'cache';

  late Box<String> _box;
  final EncryptionService _encryption;
  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  final _uuid = const Uuid();

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  Stream<bool> get connectivityStream => _connectivityController.stream;

  OfflineManager(this._encryption);

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      if (wasOnline != _isOnline) {
        _connectivityController.add(_isOnline);
      }
    });

    // Initial check
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
  }

  // ===== SUBMISSIONS QUEUE =====

  Future<String> addToSyncQueue(Map<String, dynamic> submission) async {
    final offlineId = _uuid.v4();
    submission['offline_id'] = offlineId;
    submission['created_at'] = DateTime.now().toIso8601String();

    final queue = _getQueue();
    queue.add(submission);
    await _saveQueue(queue);

    return offlineId;
  }

  List<Map<String, dynamic>> _getQueue() {
    final data = _box.get(_syncQueueKey);
    if (data == null || data.isEmpty) return [];
    try {
      final decoded = jsonDecode(_encryption.decrypt(data));
      return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    final encrypted = _encryption.encrypt(jsonEncode(queue));
    await _box.put(_syncQueueKey, encrypted);
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    return _getQueue();
  }

  Future<void> removeFromQueue(String offlineId) async {
    final queue = _getQueue();
    queue.removeWhere((item) => item['offline_id'] == offlineId);
    await _saveQueue(queue);
  }

  Future<void> clearQueue() async {
    await _box.delete(_syncQueueKey);
  }

  int get pendingCount => _getQueue().length;

  // ===== DRAFTS =====

  Future<void> saveDraft(String formId, Map<String, dynamic> data) async {
    final drafts = _getDrafts();
    drafts[formId] = {
      'data': data,
      'saved_at': DateTime.now().toIso8601String(),
    };
    final encrypted = _encryption.encrypt(jsonEncode(drafts));
    await _box.put(_draftsKey, encrypted);
  }

  Map<String, dynamic> _getDrafts() {
    final data = _box.get(_draftsKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(_encryption.decrypt(data)));
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic>? getDraft(String formId) {
    final drafts = _getDrafts();
    return drafts[formId];
  }

  Future<void> removeDraft(String formId) async {
    final drafts = _getDrafts();
    drafts.remove(formId);
    final encrypted = _encryption.encrypt(jsonEncode(drafts));
    await _box.put(_draftsKey, encrypted);
  }

  // ===== CACHE =====

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final cache = _getCache();
    cache[key] = {
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    };
    await _box.put(_cacheKey, jsonEncode(cache));
  }

  Map<String, dynamic> _getCache() {
    final data = _box.get(_cacheKey);
    if (data == null || data.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(data));
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic>? getCachedData(String key) {
    final cache = _getCache();
    final entry = cache[key];
    if (entry == null) return null;

    final cachedAt = DateTime.tryParse(entry['cached_at'] ?? '');
    if (cachedAt != null &&
        DateTime.now().difference(cachedAt) > AppConfig.cacheExpiry) {
      return null;
    }

    return entry['data'];
  }

  Future<void> clearCache() async {
    await _box.delete(_cacheKey);
  }

  void dispose() {
    _connectivityController.close();
  }
}
