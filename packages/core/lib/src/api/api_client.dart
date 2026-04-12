import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../errors/app_exceptions.dart';

/// Centralized API client with hierarchical error handling.
/// All external calls go through this client for consistent error classification.
class ApiClient {
  final SupabaseClient _client = SupabaseConfig.client;

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
      var query = _client.from(table).select(select);

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
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'select($table)');
      throw ApiException('Unexpected error in select: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<Map<String, dynamic>> selectOne(
    String table, {
    String select = '*',
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = _client.from(table).select(select);
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
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'selectOne($table)');
      throw ApiException('Unexpected error in selectOne: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data, {
    String select = '*',
  }) async {
    try {
      final result = await _client
          .from(table)
          .insert(data)
          .select(select)
          .single();
      return result;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'insert($table)');
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
      var query = _client.from(table).update(data);
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
      final result = await query.select(select).single();
      return result;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'update($table)');
      throw ApiException('Unexpected error in update: ${e.runtimeType}', code: 'unknown');
    }
  }

  Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      var query = _client.from(table).delete();
      filters.forEach((key, value) {
        query = query.eq(key, value);
      });
      await query;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'delete($table)');
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
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );
      return Map<String, dynamic>.from(response.data);
    } on FunctionException catch (e) {
      throw _mapFunctionException(e);
    } on SocketException {
      throw const NetworkException();
    } catch (e, stack) {
      _reportUnexpectedError(e, stack, context: 'callFunction($functionName)');
      throw ApiException('Unexpected error calling $functionName: ${e.runtimeType}', code: 'unknown');
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
      await _client.storage.from(bucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: contentType),
      );
      return _client.storage.from(bucket).getPublicUrl(path);
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
    final channelObj = _client.channel(channel);

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

  // ===== Error mapping helpers =====

  /// Map PostgrestException to specific AppException types
  ApiException _mapPostgrestException(PostgrestException e) {
    switch (e.code) {
      case 'PGRST116': // No rows returned
        return NotFoundException(e.message);
      case '23505': // Unique violation
        return ConflictException('Duplicate entry: ${e.message}');
      case '23503': // Foreign key violation
        return ValidationException('Related record not found', fieldErrors: {'reference': e.message});
      case '42501': // Insufficient privilege (RLS)
        return PermissionException(e.message);
      case '22P02': // Invalid text representation
        return ValidationException('Invalid data format', fieldErrors: {'format': e.message});
      default:
        // Server errors (5xx)
        if (e.code != null && e.code!.startsWith('5')) {
          return ServerException(e.message);
        }
        return ApiException(e.message, code: e.code, details: {'postgres': true});
    }
  }

  /// Map FunctionException to specific AppException types
  ApiException _mapFunctionException(FunctionException e) {
    final status = e.status ?? 0;
    switch (status) {
      case 401:
        return UnauthorizedException();
      case 403:
        return ForbiddenException();
      case 429:
        return ApiException('Rate limited', code: 'rate_limit');
      case >= 500:
        return ServerException('Edge function error: ${e.details}');
      default:
        return ApiException('Function error: ${e.details}', code: 'function_$status');
    }
  }

  /// Report unexpected errors (Sentry integration point)
  void _reportUnexpectedError(dynamic error, StackTrace stack, {String? context}) {
    // TODO: Sentry.captureException(error, stackTrace: stack, hint: context)
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      // ignore: avoid_print
      print('ApiClient error [$context]: $error\n$stack');
    }
  }
}
