import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../config/sentry_config.dart';
import '../errors/app_exceptions.dart';

/// Centralized API client with hierarchical error handling.
/// All external calls go through this client for consistent error classification.
class ApiClient {
  SupabaseClient? _client;

  /// Lazy initialization — don't crash if Supabase isn't set up yet.
  SupabaseClient get _safeClient {
    if (_client == null) {
      if (!SupabaseConfig.isConfigured) {
        throw const NetworkException('Supabase is not configured');
      }
      try {
        _client = Supabase.instance.client;
      } catch (e) {
        throw NetworkException('Supabase not initialized: $e');
      }
    }
    return _client!;
  }

  // ===== Generic CRUD operations with RLS =====

  Future<List<Map<String, dynamic>>> select(
    String table, {
    String select = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = _safeClient.from(table).select(select);

      if (filters != null) {
        for (final key in filters.keys) {
          if (filters[key] != null) query = query.eq(key, filters[key]);
        }
      }

      dynamic finalQuery = query;

      if (orderBy != null) {
        finalQuery = finalQuery.order(orderBy, ascending: ascending);
      }

      if (limit != null) finalQuery = finalQuery.limit(limit);
      if (offset != null) finalQuery = finalQuery.range(offset, offset + (limit ?? 20) - 1);

      return List<Map<String, dynamic>>.from(await finalQuery);
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'select($table)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error in select: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<Map<String, dynamic>> selectOne(
    String table, {
    String select = '*',
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = _safeClient.from(table).select(select);
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
      final result = await query.maybeSingle();
      if (result == null) throw NotFoundException('Record not found in $table');
      return result;
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'selectOne($table)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error in selectOne: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data, {
    String select = '*',
  }) async {
    try {
      final result = await _safeClient
          .from(table)
          .insert(data)
          .select(select)
          .single();
      return result;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'insert($table)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error in insert: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<Map<String, dynamic>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
    String select = '*',
  }) async {
    try {
      var query = _safeClient.from(table).update(data);
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
      final result = await query.select(select).single();
      return result;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'update($table)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error in update: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = _safeClient.from(table).delete();
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
      await query;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'delete($table)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error in delete: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<void> softDelete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    await update(table, {'deleted_at': DateTime.now().toIso8601String()}, filters: filters);
  }

  // ===== Edge Function calls =====

  Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      // Ensure token is fresh before calling the function
      await _ensureFreshSession();

      final response = await _safeClient.functions.invoke(
        functionName,
        body: body,
      );
      return Map<String, dynamic>.from(response.data);
    } on FunctionException catch (e) {
      // If 401, try refreshing the token ONCE and retry
      if (e.status == 401) {
        try {
          await _forceRefreshSession();
          final response = await _safeClient.functions.invoke(
            functionName,
            body: body,
          );
          return Map<String, dynamic>.from(response.data);
        } on FunctionException catch (retryError) {
          throw _mapFunctionException(retryError);
        } catch (retryError) {
          throw const UnauthorizedException();
        }
      }
      throw _mapFunctionException(e);
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'callFunction($functionName)');
      if (_isNetworkError(e)) throw const NetworkException();
      throw ApiException('Unexpected error calling $functionName: ${e.runtimeType}', code: 'unknown');
    }
  }

  /// Ensure the current session has a fresh token (refresh if expiring within 5 min).
  Future<void> _ensureFreshSession() async {
    try {
      final session = _safeClient.auth.currentSession;
      if (session == null) return;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      final now = DateTime.now();

      // Refresh if token expires within 5 minutes
      if (expiresAt.difference(now).inMinutes < 5) {
        await _safeClient.auth.refreshSession();
      }
    } catch (_) {
      // If refresh fails here, the main call will handle the 401
    }
  }

  /// Force a session refresh (used as retry after 401).
  Future<void> _forceRefreshSession() async {
    final session = _safeClient.auth.currentSession;
    if (session == null) throw const UnauthorizedException();

    try {
      final result = await _safeClient.auth.refreshSession();
      if (result.session == null) throw const UnauthorizedException();
    } catch (_) {
      throw const UnauthorizedException();
    }
  }

  // ===== Storage operations =====

  Future<String> uploadFile(
    String bucket,
    String path,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    try {
      await _safeClient.storage.from(bucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: contentType),
      );
      return _safeClient.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      throw FileStorageException('Upload failed: ${e.runtimeType}');
    }
  }

  // ===== Realtime subscriptions =====

  RealtimeChannel subscribe(
    String channel,
    Map<String, dynamic> filter,
    void Function(PostgresChangePayload) callback,
  ) {
    final channelObj = _safeClient.channel(channel);

    if (filter.isNotEmpty) {
      channelObj.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: filter.keys.first,
          value: filter.values.first,
        ),
        callback: callback,
      );
    } else {
      channelObj.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        callback: callback,
      );
    }

    return channelObj.subscribe();
  }

  // ===== Error helpers =====

  /// Detect network-related errors without importing dart:io
  bool _isNetworkError(dynamic e) {
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Network is unreachable') ||
        s.contains('Connection timed out');
  }

  /// Map PostgrestException to specific AppException types
  AppException _mapPostgrestException(PostgrestException e) {
    switch (e.code) {
      case 'PGRST116':
        return NotFoundException(e.message);
      case '23505':
        return ConflictException('Duplicate entry: ${e.message}');
      case '23503':
        return ValidationException('Related record not found', fieldErrors: {'reference': e.message});
      case '42501':
        return PermissionException(e.message);
      case '22P02':
        return ValidationException('Invalid data format', fieldErrors: {'format': e.message});
      default:
        if (e.code != null && e.code!.startsWith('5')) {
          return ServerException(e.message);
        }
        return ApiException(e.message, code: e.code, details: {'postgres': true});
    }
  }

  /// Map FunctionException to specific AppException types
  AppException _mapFunctionException(FunctionException e) {
    final status = e.status;
    if (status == 401) return const UnauthorizedException();
    if (status == 403) return const ForbiddenException();
    if (status == 429) return const ApiException('Rate limited', code: 'rate_limit');
    if (status >= 500) {
      return ServerException('Edge function error: ${e.details}');
    }
    return ApiException('Function error: ${e.details}', code: 'function_$status');
  }

  /// Report unexpected errors via Sentry (if configured) and debug print.
  void _reportUnexpectedError(dynamic error, StackTrace stack, {String? context}) {
    SentryConfig.captureError(error, stack, context: context);
    assert(() {
      // ignore: avoid_print
      print('ApiClient error [$context]: $error');
      return true;
    }());
  }
}
