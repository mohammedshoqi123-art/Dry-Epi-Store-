import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// مزودات مشتركة لشاشات الإدارة
/// Shared providers for admin screens

final governoratesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final response =
      await client.from('governorate').select('id, name_ar').order('name_ar');
  return (response as List<dynamic>).cast<Map<String, dynamic>>();
});

final districtsListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, governorateId) async {
  if (governorateId == null) return [];
  final client = Supabase.instance.client;
  final response = await client
      .from('district')
      .select('id, name_ar')
      .eq('governorate_id', governorateId)
      .order('name_ar');
  return (response as List<dynamic>).cast<Map<String, dynamic>>();
});

final healthFacilitiesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, districtId) async {
  if (districtId == null) return [];
  final client = Supabase.instance.client;
  final response = await client
      .from('health_facility')
      .select('id, name_ar, type')
      .eq('district_id', districtId)
      .order('name_ar');
  return (response as List<dynamic>).cast<Map<String, dynamic>>();
});
