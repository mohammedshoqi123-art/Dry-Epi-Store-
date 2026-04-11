import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:epi_shared/epi_shared.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  String _mapMode = 'markers'; // markers, heatmap
  double _currentZoom = 6.0;

  static const _iraqCenter = LatLng(33.3152, 44.3661);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EpiAppBar(
        title: AppStrings.map,
        showBackButton: false,
        actions: [
          IconButton(
            icon: Icon(_mapMode == 'markers' ? Icons.scatter_plot : Icons.grid_on),
            onPressed: () => setState(() {
              _mapMode = _mapMode == 'markers' ? 'heatmap' : 'markers';
            }),
            tooltip: _mapMode == 'markers' ? 'خريطة حرارية' : 'علامات',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _mapController.move(_iraqCenter, 6.0),
            tooltip: 'العودة للمركز',
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _iraqCenter,
          initialZoom: _currentZoom,
          minZoom: 4.0,
          maxZoom: 18.0,
          onMapReady: () {},
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.epi.supervisor',
          ),
          // Submissions markers would be loaded here
          MarkerLayer(
            markers: _buildSampleMarkers(),
          ),
        ],
      ),
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

  List<Marker> _buildSampleMarkers() {
    // Sample markers for major Iraqi cities
    final cities = [
      {'name': 'بغداد', 'lat': 33.3152, 'lng': 44.3661},
      {'name': 'البصرة', 'lat': 30.5085, 'lng': 47.7804},
      {'name': 'أربيل', 'lat': 36.1911, 'lng': 44.0092},
      {'name': 'الموصل', 'lat': 36.3350, 'lng': 43.1189},
      {'name': 'النجف', 'lat': 32.0282, 'lng': 44.3391},
      {'name': 'كركوك', 'lat': 35.4681, 'lng': 44.3922},
    ];

    return cities.map((city) {
      return Marker(
        point: LatLng(city['lat'] as double, city['lng'] as double),
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showMarkerInfo(city['name'] as String),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                  ],
                ),
                child: Text(
                  city['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 32),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showMarkerInfo(String name) {
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
            const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 40),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('انقر لعرض التفاصيل',
                style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
