import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../security/encryption_service.dart';
import '../errors/app_exceptions.dart';
import 'offline_manager.dart';

/// Offline-first data cache that stores Supabase query results locally.
/// Provides instant data access even without network connectivity.
///
/// Architecture:
///   UI → Provider → OfflineDataCache → [Cache Hit? return cached]
///                                      → [Cache Miss? fetch from API, cache, return]
///
/// When offline:
///   UI → Provider → OfflineDataCache → [Return cached data, stale is OK]
class OfflineDataCache {
  static const String _cacheBoxKey = 'data_cache';
  static const String _metadataKey = 'cache_metadata';

  final OfflineManager _offline;
  final EncryptionService _encryption;

  // In-memory cache for fastest access (LRU-style)
  final Map<String, _CacheEntry> _memoryCache = {};
  static const int _maxMemoryEntries = 100;

  OfflineDataCache(this._offline, this._encryption);

  // ═══════════════════════════════════════════════════════════════════════
  // CORE: Get data with offline-first strategy
  // ═══════════════════════════════════════════════════════════════════════

  /// Get data using offline-first strategy:
  /// 1. Return memory cache immediately (if available)
  /// 2. Fetch from network in background
  /// 3. Update cache when network data arrives
  ///
  /// [cacheKey] - unique key for this data (e.g., 'forms', 'submissions_all')
  /// [fetchFn] - function to fetch fresh data from Supabase
  /// [maxAge] - maximum age before cache is considered stale (default: 1 hour)
  /// [forceRefresh] - skip cache and always fetch fresh
  Future<List<Map<String, dynamic>>> getList(
    String cacheKey,
    Future<List<Map<String, dynamic>>> Function() fetchFn, {
    Duration maxAge = const Duration(hours: 1),
    bool forceRefresh = false,
  }) async {
    // 1. Check memory cache first (fastest)
    if (!forceRefresh) {
      final cached = _getFromMemory<List>(cacheKey, maxAge);
      if (cached != null) {
        // Refresh in background if stale
        if (_isStale(cacheKey, maxAge)) {
          _refreshInBackground(cacheKey, fetchFn);
        }
        return List<Map<String, dynamic>>.from(cached);
      }

      // 2. Check persistent cache
      final persistentCached = _getFromPersistent<List>(cacheKey, maxAge);
      if (persistentCached != null) {
        // Load into memory cache for next time
        _putToMemory(cacheKey, persistentCached);
        // Refresh in background if stale
        if (_isStale(cacheKey, maxAge)) {
          _refreshInBackground(cacheKey, fetchFn);
        }
        return List<Map<String, dynamic>>.from(persistentCached);
      }
    }

    // 3. No cache available — fetch from network
    try {
      final data = await fetchFn();
      await _saveToCache(cacheKey, data);
      return data;
    } catch (e) {
      // Network failed — try returning stale cache as fallback
      final staleCache = _getFromMemory<List>(cacheKey, Duration(days: 365));
      if (staleCache != null) {
        if (kDebugMode) print('[OfflineDataCache] Network failed, returning stale cache for $cacheKey');
        return List<Map<String, dynamic>>.from(staleCache);
      }

      final stalePersistent = _getFromPersistent<List>(cacheKey, Duration(days: 365));
      if (stalePersistent != null) {
        if (kDebugMode) print('[OfflineDataCache] Network failed, returning stale persistent cache for $cacheKey');
        return List<Map<String, dynamic>>.from(stalePersistent);
      }

      // Nothing cached at all — rethrow
      rethrow;
    }
  }

  /// Same as getList but for single map results
  Future<Map<String, dynamic>> getMap(
    String cacheKey,
    Future<Map<String, dynamic>> Function() fetchFn, {
    Duration maxAge = const Duration(hours: 1),
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _getFromMemory<Map>(cacheKey, maxAge);
      if (cached != null) {
        if (_isStale(cacheKey, maxAge)) {
          _refreshMapInBackground(cacheKey, fetchFn);
        }
        return Map<String, dynamic>.from(cached);
      }

      final persistentCached = _getFromPersistent<Map>(cacheKey, maxAge);
      if (persistentCached != null) {
        _putToMemory(cacheKey, persistentCached);
        if (_isStale(cacheKey, maxAge)) {
          _refreshMapInBackground(cacheKey, fetchFn);
        }
        return Map<String, dynamic>.from(persistentCached);
      }
    }

    try {
      final data = await fetchFn();
      await _saveToCache(cacheKey, data);
      return data;
    } catch (e) {
      final staleCache = _getFromMemory<Map>(cacheKey, Duration(days: 365));
      if (staleCache != null) return Map<String, dynamic>.from(staleCache);

      final stalePersistent = _getFromPersistent<Map>(cacheKey, Duration(days: 365));
      if (stalePersistent != null) return Map<String, dynamic>.from(stalePersistent);

      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CACHE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Save data to both memory and persistent cache
  Future<void> _saveToCache(String key, dynamic data) async {
    // Memory cache
    _putToMemory(key, data);

    // Persistent cache (via OfflineManager)
    if (data is Map) {
      await _offline.cacheData(key, Map<String, dynamic>.from(data));
    } else if (data is List) {
      await _offline.cacheData(key, {'_list': data, '_type': 'list'});
    }
  }

  /// Get from memory cache if not expired
  dynamic _getFromMemory<T>(String key, Duration maxAge) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.timestamp);
    if (age > maxAge) return null;

    if (entry.data is T) return entry.data;
    return null;
  }

  /// Get from persistent cache if not expired
  dynamic _getFromPersistent<T>(String key, Duration maxAge) {
    final cached = _offline.getCachedData(key);
    if (cached == null) return null;

    // Handle list wrapper
    if (T == List && cached['_type'] == 'list') {
      return cached['_list'];
    }

    return cached;
  }

  /// Put data into memory cache with LRU eviction
  void _putToMemory(String key, dynamic data) {
    // Evict oldest if at capacity
    if (_memoryCache.length >= _maxMemoryEntries) {
      final oldest = _memoryCache.entries
          .reduce((a, b) => a.value.timestamp.isBefore(b.value.timestamp) ? a : b);
      _memoryCache.remove(oldest.key);
    }

    _memoryCache[key] = _CacheEntry(data: data, timestamp: DateTime.now());
  }

  /// Check if cache entry is stale
  bool _isStale(String key, Duration maxAge) {
    final entry = _memoryCache[key];
    if (entry == null) return true;
    return DateTime.now().difference(entry.timestamp) > maxAge;
  }

  /// Background refresh — fire and forget
  void _refreshInBackground(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetchFn,
  ) {
    fetchFn().then((data) async {
      await _saveToCache(key, data);
      if (kDebugMode) print('[OfflineDataCache] Background refresh complete for $key');
    }).catchError((e) {
      if (kDebugMode) print('[OfflineDataCache] Background refresh failed for $key: $e');
    });
  }

  void _refreshMapInBackground(
    String key,
    Future<Map<String, dynamic>> Function() fetchFn,
  ) {
    fetchFn().then((data) async {
      await _saveToCache(key, data);
    }).catchError((e) {
      if (kDebugMode) print('[OfflineDataCache] Background refresh failed for $key: $e');
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVALIDATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Invalidate a specific cache key
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    // Note: persistent cache will expire naturally, or we can clear it
    if (kDebugMode) print('[OfflineDataCache] Invalidated cache for $key');
  }

  /// Invalidate all cached data
  Future<void> invalidateAll() async {
    _memoryCache.clear();
    await _offline.clearCache();
    if (kDebugMode) print('[OfflineDataCache] All caches cleared');
  }

  /// Check if we have any cached data for a key
  bool hasCachedData(String key) {
    if (_memoryCache.containsKey(key)) return true;
    return _offline.getCachedData(key) != null;
  }

  /// Get cached data as a raw value (for stats, counts, etc.)
  dynamic getCachedData(String key) {
    return _offline.getCachedData(key);
  }

  /// Cache a single form's data for offline access
  Future<void> cacheFormData(String formId, Map<String, dynamic> formData) async {
    final cachedForms = getCachedDataList('forms') ?? [];
    // Update or add the form in the cached list
    bool found = false;
    for (int i = 0; i < cachedForms.length; i++) {
      if (cachedForms[i]['id'] == formId) {
        cachedForms[i] = formData;
        found = true;
        break;
      }
    }
    if (!found) {
      cachedForms.add(formData);
    }
    await _saveToCache('forms', cachedForms);
  }

  /// Get cached data as a list (handles the list wrapper format)
  List<Map<String, dynamic>>? getCachedDataList(String key) {
    final dynamic cached = _offline.getCachedData(key);
    if (cached == null) return null;

    // Handle list wrapper: { _type: 'list', _list: [...] }
    if (cached is Map) {
      if (cached['_type'] == 'list' && cached['_list'] is List) {
        final list = cached['_list'] as List;
        return list
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return null;
    }

    // If it's directly a list
    if (cached is List) {
      return cached
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return null;
  }

  /// Get cache status for debugging
  Map<String, dynamic> getDebugInfo() {
    return {
      'memoryEntries': _memoryCache.length,
      'maxMemoryEntries': _maxMemoryEntries,
      'keys': _memoryCache.keys.toList(),
    };
  }
}

/// Internal cache entry with timestamp
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  _CacheEntry({required this.data, required this.timestamp});
}
