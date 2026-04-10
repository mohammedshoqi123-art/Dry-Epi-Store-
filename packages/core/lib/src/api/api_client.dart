import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../errors/app_exceptions.dart';

class ApiClient {
  final SupabaseClient _client = SupabaseConfig.client;

  // Generic CRUD operations with RLS
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
      throw ApiException(e.message, code: e.code);
    } catch (e) {
      throw ApiException(e.toString());
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
      if (result == null) throw NotFoundException('Record not found');
      return result;
    } on PostgrestException catch (e) {
      throw ApiException(e.message, code: e.code);
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
      throw ApiException(e.message, code: e.code);
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
      throw ApiException(e.message, code: e.code);
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
      throw ApiException(e.message, code: e.code);
    }
  }

  // Soft delete
  Future<void> softDelete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    await update(table, {'deleted_at': DateTime.now().toIso8601String()}, filters: filters);
  }

  // Edge Function calls
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
      throw ApiException(e.details.toString(), code: e.status.toString());
    }
  }

  // Storage operations
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
      throw FileStorageException(e.toString());
    }
  }

  // Realtime subscriptions
  RealtimeChannel subscribe(
    String channel,
    Map<String, dynamic> filter,
    void Function(PostgresChangePayload) callback,
  ) {
    return _client
        .channel(channel)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          filter: filter != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq, 
            column: filter.keys.first, 
            value: filter.values.first
          ) : null,
          callback: callback,
        )
        .subscribe();
  }
}
