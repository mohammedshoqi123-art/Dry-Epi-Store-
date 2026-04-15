import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:epi_shared/epi_shared.dart';
import 'package:epi_core/epi_core.dart';
import '../providers/app_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  String _mapMode = 'submissions'; // submissions, shortages
  bool _showHeatmap = false;
  double _currentZoom = 6.0;

  static const _yemenCenter = LatLng(15.5527, 48.5164); // Center of Yemen

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.map,
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (!ConnectivityUtils.isOnline) return;
              ref.invalidate(submissionsProvider(const SubmissionsFilter()));
              ref.invalidate(shortagesProvider);
              ref.invalidate(governoratesProvider);
            },
            tooltip: 'تحديث البيانات',
          ),
          IconButton(
            icon: Icon(_showHeatmap ? Icons.scatter_plot : Icons.grid_on),
            onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
            tooltip: _showHeatmap ? 'علامات' : 'خريطة حرارية',
          ),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _mapMode = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'submissions', child: Text('الإرساليات')),
              const PopupMenuItem(value: 'shortages', child: Text('النواقص')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(_mapMode == 'submissions' ? Icons.upload_file : Icons.warning),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _mapController.move(_yemenCenter, 6.0),
            tooltip: 'العودة للمركز',
          ),
        ],
      ),
      body: _buildMap(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoom_in',
            mini: true,
            onPressed: () {
              setState(() => _currentZoom = (_currentZoom + 1).clamp(4.0, 18.0));
              _mapController.move(_mapController.camera.center, _currentZoom);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'zoom_out',
            mini: true,
            onPressed: () {
              setState(() => _currentZoom = (_currentZoom - 1).clamp(4.0, 18.0));
              _mapController.move(_mapController.camera.center, _currentZoom);
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final children = <Widget>[
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.epi.supervisor',
      ),
    ];

    if (_showHeatmap) {
      children.add(_buildHeatmapLayer());
    } else {
      children.add(
        _mapMode == 'submissions' ? _buildSubmissionsLayer() : _buildShortagesLayer(),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _yemenCenter,
        initialZoom: _currentZoom,
        minZoom: 4.0,
        maxZoom: 18.0,
      ),
      children: children,
    );
  }

  Widget _buildHeatmapLayer() {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      loading: () => const CircleLayer(circles: []),
      error: (_, __) => const CircleLayer(circles: []),
      data: (governorates) {
        final circles = <CircleMarker>[];
        for (final gov in governorates) {
          final lat = gov['center_lat'];
          final lng = gov['center_lng'];
          if (lat == null || lng == null) continue;

          // Use submission_count or default intensity
          final count = (gov['submission_count'] as num?)?.toDouble() ?? 1.0;
          final maxCount = 50.0;
          final intensity = (count / maxCount).clamp(0.1, 1.0);

          // Color gradient: green (low) → yellow (mid) → red (high)
          Color color;
          if (intensity < 0.33) {
            color = Colors.green.withValues(alpha: 0.3 + intensity);
          } else if (intensity < 0.66) {
            color = Colors.orange.withValues(alpha: 0.3 + intensity);
          } else {
            color = Colors.red.withValues(alpha: 0.3 + intensity * 0.5);
          }

          circles.add(CircleMarker(
            point: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
            radius: 15000 + (count * 500),
            useRadiusInMeter: true,
            color: color,
            borderColor: color.withValues(alpha: 0.8),
            borderStrokeWidth: 2,
          ));
        }
        return CircleLayer(circles: circles);
      },
    );
  }

  Widget _buildSubmissionsLayer() {
    final submissionsAsync = ref.watch(submissionsProvider(const SubmissionsFilter()));

    return submissionsAsync.when(
      loading: () => const MarkerLayer(markers: []),
      error: (_, __) => const MarkerLayer(markers: []),
      data: (submissions) {
        final markers = <Marker>[];

        for (final sub in submissions) {
          final lat = sub['gps_lat'] as double?;
          final lng = sub['gps_lng'] as double?;
          if (lat == null || lng == null) continue;

          final status = sub['status'] as String? ?? 'draft';

          markers.add(Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showSubmissionInfo(sub),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.statusColor(status),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                  ],
                ),
                child: const Icon(Icons.description, color: Colors.white, size: 20),
              ),
            ),
          ));
        }

        // Add governorate center markers if no submission markers
        if (markers.isEmpty) {
          return _buildGovernorateMarkers();
        }

        return MarkerLayer(markers: markers);
      },
    );
  }

  Widget _buildShortagesLayer() {
    final shortagesAsync = ref.watch(shortagesProvider);

    return shortagesAsync.when(
      loading: () => const MarkerLayer(markers: []),
      error: (_, __) => const MarkerLayer(markers: []),
      data: (shortages) {
        final markers = <Marker>[];

        // Shortages might not have direct GPS, so we skip those without coordinates
        // In a real app, you'd derive location from district/governorate

        if (markers.isEmpty) {
          return _buildGovernorateMarkers(severityMode: true);
        }

        return MarkerLayer(markers: markers);
      },
    );
  }

  Widget _buildGovernorateMarkers({bool severityMode = false}) {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      loading: () => const MarkerLayer(markers: []),
      error: (_, __) => const MarkerLayer(markers: []),
      data: (governorates) {
        final markers = governorates.where((g) => g['center_lat'] != null && g['center_lng'] != null).map((gov) {
          final lat = (gov['center_lat'] as num).toDouble();
          final lng = (gov['center_lng'] as num).toDouble();
          final name = gov['name_ar'] ?? '';

          return Marker(
            point: LatLng(lat, lng),
            width: 80,
            height: 60,
            child: GestureDetector(
              onTap: () => _showGovernorateInfo(gov),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityMode ? AppTheme.warningColor : AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    severityMode ? Icons.warning : Icons.location_on,
                    color: severityMode ? AppTheme.warningColor : AppTheme.primaryColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          );
        }).toList();

        return MarkerLayer(markers: markers);
      },
    );
  }

  void _showSubmissionInfo(Map<String, dynamic> sub) {
    final formTitle = sub['forms']?['title_ar'] ?? 'نموذج';
    final status = sub['status'] ?? 'draft';
    final date = sub['created_at']?.toString().split('T')[0] ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description, color: AppTheme.statusColor(status), size: 40),
            const SizedBox(height: 12),
            Text(formTitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            EpiStatusChip(status: status),
            if (date.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(date, style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 16),
            EpiButton(
              text: 'عرض التفاصيل',
              onPressed: () {
                Navigator.pop(context);
                context.go('/submissions/${sub['id']}');
              },
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  void _showGovernorateInfo(Map<String, dynamic> gov) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_city, color: AppTheme.primaryColor, size: 40),
            const SizedBox(height: 12),
            Text(gov['name_ar'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            if (gov['name_en'] != null)
              Text(gov['name_en'], style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            EpiButton(text: 'إغلاق', onPressed: () => Navigator.pop(context), width: double.infinity),
          ],
        ),
      ),
    );
  }
}
