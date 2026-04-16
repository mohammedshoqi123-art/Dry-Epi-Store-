import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

/// Cache entry with expiry, hash, and access tracking
class CacheEntry {
  final dynamic value;
  final DateTime expiry;
  final String hash;
  final DateTime createdAt;
  final int accessCount;
  final DateTime lastAccessed;
  final int sizeBytes;

  CacheEntry({
    required this.value,
    required this.expiry,
    required this.hash,
    DateTime? createdAt,
    this.accessCount = 0,
    DateTime? lastAccessed,
    this.sizeBytes = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastAccessed = lastAccessed ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiry);

  bool get isValid {
    if (isExpired) return false;
    // Integrity check
    final currentHash = _computeHash(value);
    return currentHash == hash;
  }

  CacheEntry copyWithAccess() => CacheEntry(
        value: value,
        expiry: expiry,
        hash: hash,
        createdAt: createdAt,
        accessCount: accessCount + 1,
        lastAccessed: DateTime.now(),
        sizeBytes: sizeBytes,
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'expiry': expiry.toIso8601String(),
        'hash': hash,
        'created_at': createdAt.toIso8601String(),
        'access_count': accessCount,
        'last_accessed': lastAccessed.toIso8601String(),
        'size_bytes': sizeBytes,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        value: json['value'],
        expiry: DateTime.parse(json['expiry']),
        hash: json['hash'],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        accessCount: json['access_count'] ?? 0,
        lastAccessed:
            DateTime.tryParse(json['last_accessed'] ?? '') ?? DateTime.now(),
        sizeBytes: json['size_bytes'] ?? 0,
      );

  static String _computeHash(dynamic value) {
    final jsonStr = jsonEncode(value);
    return sha256.convert(utf8.encode(jsonStr)).toString().substring(0, 16);
  }
}

/// Cache eviction strategy
enum EvictionStrategy { lru, lfu, fifo, ttl }

/// Cache statistics
class CacheStats {
  final int totalEntries;
  final int totalSizeBytes;
  final int hitCount;
  final int missCount;
  final int evictionCount;
  final int expiredCount;

  const CacheStats({
    this.totalEntries = 0,
    this.totalSizeBytes = 0,
    this.hitCount = 0,
    this.missCount = 0,
    this.evictionCount = 0,
    this.expiredCount = 0,
  });

  double get hitRate =>
      (hitCount + missCount) > 0 ? hitCount / (hitCount + missCount) : 0;

  String get sizeFormatted {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Advanced cache manager with expiry, eviction strategies,
/// size-based partitioning, and integrity verification.
class AdvancedCacheManager {
  final Map<String, CacheEntry> _cache = {};
  final EvictionStrategy _strategy;
  final int _maxEntries;
  final int _maxSizeBytes;

  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;
  int _expiredCount = 0;

  Timer? _cleanupTimer;

  /// Create a cache manager
  /// [strategy] — eviction strategy (default: LRU)
  /// [maxEntries] — maximum number of cache entries
  /// [maxSizeBytes] — maximum total cache size in bytes
  AdvancedCacheManager({
    EvictionStrategy strategy = EvictionStrategy.lru,
    int maxEntries = 500,
    int maxSizeBytes = 50 * 1024 * 1024, // 50MB
  })  : _strategy = strategy,
        _maxEntries = maxEntries,
        _maxSizeBytes = maxSizeBytes;

  void init() {
    // Periodic cleanup every 5 minutes
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpired();
    });
  }

  /// Store a value with optional custom expiry
  Future<void> set(
    String key,
    dynamic value, {
    Duration expiry = const Duration(hours: 24),
    String? partition,
  }) async {
    final fullKey = partition != null ? '$partition::$key' : key;
    final jsonString = jsonEncode(value);
    final sizeBytes = utf8.encode(jsonString).length;

    // Check if we need to evict
    await _ensureCapacity(sizeBytes);

    final hash =
        sha256.convert(utf8.encode(jsonString)).toString().substring(0, 16);

    _cache[fullKey] = CacheEntry(
      value: value,
      expiry: DateTime.now().add(expiry),
      hash: hash,
      sizeBytes: sizeBytes,
    );
  }

  /// Store with smart partitioning for large data
  Future<void> smartCache(
    String key,
    dynamic value, {
    Duration expiry = const Duration(hours: 24),
    int maxSizeKB = 1024,
    String? partition,
  }) async {
    final jsonString = jsonEncode(value);
    final sizeKB = utf8.encode(jsonString).length / 1024;

    if (sizeKB > maxSizeKB) {
      // Split large data into chunks
      await _cacheLargeData(key, value, maxSizeKB, expiry, partition);
    } else {
      await set(key, value, expiry: expiry, partition: partition);
    }
  }

  Future<void> _cacheLargeData(
    String key,
    dynamic value,
    int maxSizeKB,
    Duration expiry,
    String? partition,
  ) async {
    final jsonString = jsonEncode(value);
    final bytes = utf8.encode(jsonString);
    final chunkSize = maxSizeKB * 1024;
    final totalChunks = (bytes.length / chunkSize).ceil();

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, bytes.length);
      final chunk = utf8.decode(bytes.sublist(start, end));

      await set(
        '${key}_chunk_$i',
        {
          'data': chunk,
          'chunk_index': i,
          'total_chunks': totalChunks,
          'original_key': key,
        },
        expiry: expiry,
        partition: partition,
      );
    }

    // Store metadata
    await set(
      '${key}_meta',
      {
        'total_chunks': totalChunks,
        'total_size_bytes': bytes.length,
        'original_key': key,
      },
      expiry: expiry,
      partition: partition,
    );
  }

  /// Retrieve a cached value
  T? get<T>(String key, {String? partition}) {
    final fullKey = partition != null ? '$partition::$key' : key;
    final entry = _cache[fullKey];

    if (entry == null) {
      _missCount++;
      return null;
    }

    if (entry.isExpired) {
      _cache.remove(fullKey);
      _expiredCount++;
      _missCount++;
      return null;
    }

    if (!entry.isValid) {
      // Integrity check failed — data corrupted
      _cache.remove(fullKey);
      _missCount++;
      return null;
    }

    // Update access tracking
    _cache[fullKey] = entry.copyWithAccess();
    _hitCount++;

    return entry.value as T;
  }

  /// Retrieve large data that was split into chunks
  Future<T?> getLargeData<T>(String key, {String? partition}) async {
    final meta = get<Map<String, dynamic>>('${key}_meta', partition: partition);
    if (meta == null) return null;

    final totalChunks = meta['total_chunks'] as int;
    final buffer = StringBuffer();

    for (var i = 0; i < totalChunks; i++) {
      final chunk =
          get<Map<String, dynamic>>('${key}_chunk_$i', partition: partition);
      if (chunk == null) return null; // Missing chunk
      buffer.write(chunk['data']);
    }

    try {
      return jsonDecode(buffer.toString()) as T;
    } catch (_) {
      return null;
    }
  }

  /// Check if key exists and is valid
  bool has(String key, {String? partition}) {
    return get<dynamic>(key, partition: partition) != null;
  }

  /// Remove a specific key
  Future<void> remove(String key, {String? partition}) async {
    final fullKey = partition != null ? '$partition::$key' : key;
    _cache.remove(fullKey);
  }

  /// Clear a specific partition
  Future<void> clearPartition(String partition) async {
    final prefix = '$partition::';
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cache
  Future<void> clearAll() async {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    _expiredCount = 0;
  }

  /// Get cache statistics
  CacheStats get stats => CacheStats(
        totalEntries: _cache.length,
        totalSizeBytes: _cache.values.fold(0, (sum, e) => sum + e.sizeBytes),
        hitCount: _hitCount,
        missCount: _missCount,
        evictionCount: _evictionCount,
        expiredCount: _expiredCount,
      );

  /// Get all keys in a partition
  List<String> getPartitionKeys(String partition) {
    final prefix = '$partition::';
    return _cache.keys
        .where((k) => k.startsWith(prefix))
        .map((k) => k.substring(prefix.length))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ═══════════════════════════════════════════════════════════════════════════

  void _cleanupExpired() {
    final expired = <String>[];
    _cache.forEach((key, entry) {
      if (entry.isExpired) expired.add(key);
    });
    for (final key in expired) {
      _cache.remove(key);
      _expiredCount++;
    }
    if (kDebugMode && expired.isNotEmpty) {
      print('[Cache] Cleaned up ${expired.length} expired entries');
    }
  }

  Future<void> _ensureCapacity(int newEntrySizeBytes) async {
    // Check entry count
    while (_cache.length >= _maxEntries) {
      _evictOne();
    }

    // Check total size
    final currentSize = _cache.values.fold(0, (sum, e) => sum + e.sizeBytes);
    while (
        currentSize + newEntrySizeBytes > _maxSizeBytes && _cache.isNotEmpty) {
      _evictOne();
    }
  }

  void _evictOne() {
    if (_cache.isEmpty) return;

    String? keyToEvict;

    switch (_strategy) {
      case EvictionStrategy.lru:
        // Least recently used
        DateTime oldest = DateTime.now();
        _cache.forEach((key, entry) {
          if (entry.lastAccessed.isBefore(oldest)) {
            oldest = entry.lastAccessed;
            keyToEvict = key;
          }
        });
        break;

      case EvictionStrategy.lfu:
        // Least frequently used
        int minAccess = 999999;
        _cache.forEach((key, entry) {
          if (entry.accessCount < minAccess) {
            minAccess = entry.accessCount;
            keyToEvict = key;
          }
        });
        break;

      case EvictionStrategy.fifo:
        // First in, first out
        DateTime oldest = DateTime.now();
        _cache.forEach((key, entry) {
          if (entry.createdAt.isBefore(oldest)) {
            oldest = entry.createdAt;
            keyToEvict = key;
          }
        });
        break;

      case EvictionStrategy.ttl:
        // Shortest TTL first
        DateTime soonest = DateTime(2100);
        _cache.forEach((key, entry) {
          if (entry.expiry.isBefore(soonest)) {
            soonest = entry.expiry;
            keyToEvict = key;
          }
        });
        break;
    }

    if (keyToEvict != null) {
      _cache.remove(keyToEvict);
      _evictionCount++;
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}
