import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ═══════════════════════════════════════════════════════════════════
///  إدارة البيانات — Data Management (Governorates, Districts, Facilities)
/// ═══════════════════════════════════════════════════════════════════

final governoratesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client.functions.invoke('manage-data', body: {
    'resource': 'governorates',
    'action': 'list',
  });
  if (response.status != 200) throw Exception('فشل تحميل المحافظات');
  return List<Map<String, dynamic>>.from(response.data['governorates'] ?? []);
});

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedGovId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF00897B),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF00897B),
            tabs: const [
              Tab(icon: Icon(Icons.location_city_rounded), text: 'المحافظات'),
              Tab(icon: Icon(Icons.domain_rounded), text: 'المديريات'),
              Tab(icon: Icon(Icons.local_hospital_rounded), text: 'المنشآت الصحية'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGovernoratesTab(),
              _buildDistrictsTab(),
              _buildFacilitiesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGovernoratesTab() {
    final govsAsync = ref.watch(governoratesProvider);
    return govsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('خطأ: $err')),
      data: (govs) => _buildDataTable(
        title: 'المحافظات (${govs.length})',
        columns: const ['الاسم', 'الرمز', 'السكان', 'المديريات', 'نشط', 'إجراءات'],
        rows: govs.map((g) => [
          (g['name_ar'] ?? '').toString(),
          (g['code'] ?? '').toString(),
          '${g['population'] ?? 0}',
          '${(g['districts'] as List?)?.length ?? 0}',
          g['is_active'] == true ? '✓' : '✗',
          '',
        ]).toList(),
        rawData: govs,
        onAdd: () => _showGovDialog(),
        onEdit: (g) => _showGovDialog(gov: g),
        onDelete: (g) => _deleteItem('governorates', g['id'], g['name_ar']),
      ),
    );
  }

  Widget _buildDistrictsTab() {
    return FutureBuilder(
      future: Supabase.instance.client.functions.invoke('manage-data', body: {
        'resource': 'districts',
        'action': 'list',
        if (_selectedGovId != null) 'governorate_id': _selectedGovId,
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data;
        final districts = List<Map<String, dynamic>>.from(data?['districts'] ?? []);

        return Column(
          children: [
            // Governorate filter
            Row(
              children: [
                FutureBuilder(
                  future: Supabase.instance.client.from('governorates').select('id, name_ar').eq('is_active', true).order('name_ar'),
                  builder: (ctx, snap) {
                    final govs = List<Map<String, dynamic>>.from(snap.data ?? []);
                    return SizedBox(
                      width: 250,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedGovId,
                        decoration: const InputDecoration(
                          labelText: 'تصفية حسب المحافظة',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('الكل')),
                          ...govs.map((g) => DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(g['name_ar'] ?? ''),
                          )),
                        ],
                        onChanged: (v) => setState(() => _selectedGovId = v),
                      ),
                    );
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showDistDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة مديرية'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildDataTable(
              title: 'المديريات (${districts.length})',
              columns: const ['الاسم', 'المحافظة', 'الرمز', 'نشط', 'إجراءات'],
              rows: districts.map((d) => [
                (d['name_ar'] ?? '').toString(),
                (d['governorates']?['name_ar'] ?? '').toString(),
                (d['code'] ?? '').toString(),
                d['is_active'] == true ? '✓' : '✗',
                '',
              ]).toList(),
              rawData: districts,
              onEdit: (d) => _showDistDialog(district: d),
              onDelete: (d) => _deleteItem('districts', d['id'], d['name_ar']),
            )),
          ],
        );
      },
    );
  }

  Widget _buildFacilitiesTab() {
    return FutureBuilder(
      future: Supabase.instance.client.functions.invoke('manage-data', body: {
        'resource': 'facilities',
        'action': 'list',
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data?.data;
        final facilities = List<Map<String, dynamic>>.from(data?['facilities'] ?? []);

        return Column(
          children: [
            Row(
              children: [
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showFacilityDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة منشأة'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildDataTable(
              title: 'المنشآت الصحية (${facilities.length})',
              columns: const ['الاسم', 'الرمز', 'النوع', 'المديرية', 'المحافظة', 'نشط', 'إجراءات'],
              rows: facilities.map((f) => [
                (f['name_ar'] ?? '').toString(),
                (f['code'] ?? '').toString(),
                (f['facility_type'] ?? '').toString(),
                (f['districts']?['name_ar'] ?? '').toString(),
                (f['districts']?['governorates']?['name_ar'] ?? '').toString(),
                f['is_active'] == true ? '✓' : '✗',
                '',
              ]).toList(),
              rawData: facilities,
              onEdit: (f) => _showFacilityDialog(facility: f),
              onDelete: (f) => _deleteItem('health_facilities', f['id'], f['name_ar']),
            )),
          ],
        );
      },
    );
  }

  Widget _buildDataTable({
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
    required List<Map<String, dynamic>> rawData,
    VoidCallback? onAdd,
    Function(Map<String, dynamic>)? onEdit,
    Function(Map<String, dynamic>)? onDelete,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const Spacer(),
                if (onAdd != null)
                  IconButton(onPressed: onAdd, icon: const Icon(Icons.add_rounded), tooltip: 'إضافة'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  rows: rows.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return DataRow(
                      cells: row.asMap().entries.map((cell) {
                        if (cell.key == row.length - 1) {
                          return DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  onPressed: () => onEdit(rawData[i]),
                                ),
                              if (onDelete != null)
                                IconButton(
                                  icon: Icon(Icons.delete_rounded, size: 18, color: Colors.red[300]),
                                  onPressed: () => onDelete(rawData[i]),
                                ),
                            ],
                          ));
                        }
                        return DataCell(Text(cell.value));
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGovDialog({Map<String, dynamic>? gov}) {
    final nameAr = TextEditingController(text: gov?['name_ar']);
    final nameEn = TextEditingController(text: gov?['name_en']);
    final code = TextEditingController(text: gov?['code']);
    final population = TextEditingController(text: '${gov?['population'] ?? ''}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gov == null ? 'إضافة محافظة' : 'تعديل محافظة'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم (عربي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم (إنجليزي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: population, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السكان', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.functions.invoke('manage-data', body: {
                  'resource': 'governorates',
                  'action': gov == null ? 'create' : 'update',
                  if (gov != null) 'id': gov['id'],
                  'name_ar': nameAr.text,
                  'name_en': nameEn.text,
                  'code': code.text,
                  'population': int.tryParse(population.text),
                });
                Navigator.pop(ctx);
                ref.invalidate(governoratesProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDistDialog({Map<String, dynamic>? district}) {
    final nameAr = TextEditingController(text: district?['name_ar']);
    final nameEn = TextEditingController(text: district?['name_en']);
    final code = TextEditingController(text: district?['code']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(district == null ? 'إضافة مديرية' : 'تعديل مديرية'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم (عربي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم (إنجليزي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            // Save logic
            Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _showFacilityDialog({Map<String, dynamic>? facility}) {
    final nameAr = TextEditingController(text: facility?['name_ar']);
    final nameEn = TextEditingController(text: facility?['name_en']);
    final code = TextEditingController(text: facility?['code']);
    final type = TextEditingController(text: facility?['facility_type']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(facility == null ? 'إضافة منشأة' : 'تعديل منشأة'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم (عربي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم (إنجليزي)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: code, decoration: const InputDecoration(labelText: 'الرمز', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: type, decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            Navigator.pop(ctx);
            setState(() {});
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _deleteItem(String resource, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف "$name"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.functions.invoke('manage-data', body: {
                  'resource': resource,
                  'action': 'delete',
                  'id': id,
                });
                Navigator.pop(ctx);
                ref.invalidate(governoratesProvider);
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
