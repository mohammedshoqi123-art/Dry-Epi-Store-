
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:epi_shared/epi_shared.dart';
import '../providers/app_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  String _mapMode = 'submissions'; // submissions, shortages, facilities
  bool _showHeatmap = false;
  bool _showStats = true;
  double _currentZoom = 6.0;

  late AnimationController _fabAnimController;
  late Animation<double> _fabAnimation;

  static const _yemenCenter = LatLng(15.5527, 48.5164);

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeInOut,
    );
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  // ─── Color helpers ────────────────────────────────────────────────────

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'submitted':
        return const Color(0xFF3B82F6);
      case 'reviewed':
        return const Color(0xFFF59E0B);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'draft':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'submitted':
        return Icons.send_rounded;
      case 'reviewed':
        return Icons.rate_review_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'draft':
        return Icons.edit_note_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
        return const Color(0xFFFBBF24);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          _buildMap(),

          // Gradient header overlay
          _buildHeaderOverlay(),

          // Title & mode selector
          _buildTopBar(),

          // Stats overlay
          if (_showStats) _buildStatsOverlay(),

          // Legend
          _buildLegend(),

          // FABs
          _buildFABs(),
        ],
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────

  Widget _buildHeaderOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF004D40).withValues(alpha: 0.85),
                const Color(0xFF004D40).withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خريطة البيانات',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'اليمن — مراية شاملة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Refresh
                  _iconButton(
                    Icons.refresh_rounded,
                    onTap: () {
                      ref.invalidate(submissionsProvider(
                          SubmissionsFilter(
                              campaignType:
                                  ref.read(campaignProvider).value)));
                      ref.invalidate(shortagesProvider);
                      ref.invalidate(governoratesProvider);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Toggle stats
                  _iconButton(
                    _showStats
                        ? Icons.info_rounded
                        : Icons.info_outline_rounded,
                    onTap: () =>
                        setState(() => _showStats = !_showStats),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mode chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _modeChip('submissions', 'إرساليات',
                        Icons.description_rounded),
                    const SizedBox(width: 8),
                    _modeChip(
                        'shortages', 'نواقص', Icons.warning_rounded),
                    const SizedBox(width: 8),
                    _modeChip(
                        'heatmap', 'خريطة حرارية', Icons.grid_on_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String mode, String label, IconData icon) {
    final isActive = mode == 'heatmap'
        ? _showHeatmap
        : _mapMode == mode && !_showHeatmap;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (mode == 'heatmap') {
            _showHeatmap = true;
          } else {
            _showHeatmap = false;
            _mapMode = mode;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? const Color(0xFF00695C)
                  : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF00695C)
                    : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ─── Stats Overlay ───────────────────────────────────────────────────

  Widget _buildStatsOverlay() {
    return Positioned(
      top: 155,
      left: 16,
      right: 16,
      child: Consumer(
        builder: (context, ref, _) {
          final submissionsAsync = ref.watch(submissionsProvider(
              SubmissionsFilter(
                  campaignType: ref.read(campaignProvider).value)));
          final governoratesAsync = ref.watch(governoratesProvider);

          final subCount = submissionsAsync.valueOrNull?.length ?? 0;
          final govCount = governoratesAsync.valueOrNull?.length ?? 0;

          return Row(
            children: [
              _statCard(
                  'إرساليات', '$subCount', Icons.description_rounded,
                  const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _statCard('محافظات', '$govCount',
                  Icons.location_city_rounded, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _statCard('خريطة', _showHeatmap ? 'حرارية' : 'علامات',
                  _showHeatmap ? Icons.grid_on : Icons.place_rounded,
                  const Color(0xFFF59E0B)),
            ],
          );
        },
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2332),
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Legend ───────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Positioned(
      bottom: 90,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _showHeatmap
            ? _heatmapLegend()
            : _mapMode == 'submissions'
                ? _submissionLegend()
                : _shortageLegend(),
      ),
    );
  }

  Widget _submissionLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(const Color(0xFF10B981), 'معتمد'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFF3B82F6), 'مُرسل'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFFF59E0B), 'قيد المراجعة'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFFEF4444), 'مرفوض'),
      ],
    );
  }

  Widget _shortageLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(const Color(0xFFDC2626), 'حرج'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFFF97316), 'عالي'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFFFBBF24), 'متوسط'),
        const SizedBox(width: 12),
        _legendDot(const Color(0xFF22C55E), 'منخفض'),
      ],
    );
  }

  Widget _heatmapLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF22C55E),
                Color(0xFFFBBF24),
                Color(0xFFEF4444),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'منخفض ← عالي',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 10,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ─── FABs ─────────────────────────────────────────────────────────────

  Widget _buildFABs() {
    return Positioned(
      bottom: 24,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // My location
          ScaleTransition(
            scale: _fabAnimation,
            child: _fabMini(
              Icons.my_location_rounded,
              const Color(0xFF00897B),
              () => _mapController.move(_yemenCenter, 6.0),
            ),
          ),
          const SizedBox(height: 8),
          // Zoom in
          ScaleTransition(
            scale: _fabAnimation,
            child: _fabMini(
              Icons.add_rounded,
              Colors.white,
              () {
                setState(
                    () => _currentZoom = (_currentZoom + 1).clamp(4.0, 18.0));
                _mapController.move(
                    _mapController.camera.center, _currentZoom);
              },
              iconColor: const Color(0xFF1A2332),
            ),
          ),
          const SizedBox(height: 8),
          // Zoom out
          ScaleTransition(
            scale: _fabAnimation,
            child: _fabMini(
              Icons.remove_rounded,
              Colors.white,
              () {
                setState(
                    () => _currentZoom = (_currentZoom - 1).clamp(4.0, 18.0));
                _mapController.move(
                    _mapController.camera.center, _currentZoom);
              },
              iconColor: const Color(0xFF1A2332),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fabMini(IconData icon, Color bgColor, VoidCallback onTap,
      {Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  // ─── Map Layers ──────────────────────────────────────────────────────

  Widget _buildMap() {
    final children = <Widget>[
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.epi.supervisor',
        tileBuilder: _darkTileBuilder,
      ),
    ];

    if (_showHeatmap) {
      children.add(_buildHeatmapLayer());
    } else if (_mapMode == 'submissions') {
      children.add(_buildSubmissionsClusterLayer());
    } else {
      children.add(_buildShortagesLayer());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _yemenCenter,
        initialZoom: _currentZoom,
        minZoom: 4.0,
        maxZoom: 18.0,
        onPositionChanged: (pos, _) {
          setState(() => _currentZoom = pos.zoom ?? _currentZoom);
        },
      ),
      children: children,
    );
  }

  // Dark tile overlay for better marker visibility
  Widget _darkTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.85, 0, 0, 0, 10,
        0, 0.9, 0, 0, 8,
        0, 0, 0.95, 0, 5,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  // ─── Heatmap Layer ───────────────────────────────────────────────────

  Widget _buildHeatmapLayer() {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      loading: () => const CircleLayer(circles: []),
      error: (_, __) => const CircleLayer(circles: []),
      data: (governorates) {
        final circles = <CircleMarker>[];
        final labels = <Marker>[];

        for (final gov in governorates) {
          final lat = gov['center_lat'];
          final lng = gov['center_lng'];
          if (lat == null || lng == null) continue;

          final count =
              (gov['submission_count'] as num?)?.toDouble() ?? 1.0;
          const maxCount = 50.0;
          final intensity = (count / maxCount).clamp(0.1, 1.0);

          Color color;
          if (intensity < 0.33) {
            color = Color.lerp(
                const Color(0xFF22C55E), const Color(0xFFFBBF24),
                intensity * 3)!;
          } else if (intensity < 0.66) {
            color = Color.lerp(const Color(0xFFFBBF24),
                const Color(0xFFF97316), (intensity - 0.33) * 3)!;
          } else {
            color = Color.lerp(const Color(0xFFF97316),
                const Color(0xFFEF4444), (intensity - 0.66) * 3)!;
          }

          circles.add(CircleMarker(
            point: LatLng(
                lat.toDouble(), lng.toDouble()),
            radius: 12000 + (count * 600),
            useRadiusInMeter: true,
            color: color.withValues(alpha: 0.35),
            borderColor: color.withValues(alpha: 0.7),
            borderStrokeWidth: 2,
          ));

          // Add count label
          labels.add(Marker(
            point: LatLng(
                lat.toDouble(), lng.toDouble()),
            width: 40,
            height: 24,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${count.toInt()}',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ));
        }

        return Stack(
          children: [
            CircleLayer(circles: circles),
            MarkerLayer(markers: labels),
          ],
        );
      },
    );
  }

  // ─── Submissions Cluster Layer ───────────────────────────────────────

  Widget _buildSubmissionsClusterLayer() {
    final submissionsAsync = ref.watch(submissionsProvider(SubmissionsFilter(
        campaignType: ref.read(campaignProvider).value)));

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
          final color = _statusColor(status);

          markers.add(Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => _showSubmissionInfo(sub),
              child: _animatedMarker(color, _statusIcon(status)),
            ),
          ));
        }

        if (markers.isEmpty) {
          return _buildGovernorateMarkers();
        }

        // Cluster if many markers
        if (markers.length > 20) {
          return MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 50,
              size: const Size(40, 40),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(50),
              markers: markers,
              builder: (context, clusterMarkers) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF00695C)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${clusterMarkers.length}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

        return MarkerLayer(markers: markers);
      },
    );
  }

  Widget _animatedMarker(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ─── Shortages Layer ─────────────────────────────────────────────────

  Widget _buildShortagesLayer() {
    final shortagesAsync = ref.watch(shortagesProvider);

    return shortagesAsync.when(
      loading: () => const MarkerLayer(markers: []),
      error: (_, __) => const MarkerLayer(markers: []),
      data: (shortages) {
        final markers = <Marker>[];
        for (final shortage in shortages) {
          final lat = shortage['gps_lat'] as double?;
          final lng = shortage['gps_lng'] as double?;
          if (lat == null || lng == null) continue;

          final severity =
              shortage['severity'] as String? ?? 'medium';
          final color = _severityColor(severity);

          markers.add(Marker(
            point: LatLng(lat, lng),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _showShortageInfo(shortage),
              child: _animatedMarker(
                  color, Icons.warning_rounded),
            ),
          ));
        }

        if (markers.isEmpty) {
          return _buildGovernorateMarkers(severityMode: true);
        }

        return MarkerLayer(markers: markers);
      },
    );
  }

  // ─── Governorate Markers ─────────────────────────────────────────────

  Widget _buildGovernorateMarkers({bool severityMode = false}) {
    final governoratesAsync = ref.watch(governoratesProvider);

    return governoratesAsync.when(
      loading: () => const MarkerLayer(markers: []),
      error: (_, __) => const MarkerLayer(markers: []),
      data: (governorates) {
        final markers = governorates
            .where((g) =>
                g['center_lat'] != null && g['center_lng'] != null)
            .map((gov) {
          final lat = (gov['center_lat'] as num).toDouble();
          final lng = (gov['center_lng'] as num).toDouble();
          final name = gov['name_ar'] ?? '';
          final count =
              (gov['submission_count'] as num?)?.toInt() ?? 0;
          final color = severityMode
              ? const Color(0xFFF97316)
              : const Color(0xFF00897B);

          return Marker(
            point: LatLng(lat, lng),
            width: 100,
            height: 70,
            child: GestureDetector(
              onTap: () => _showGovernorateInfo(gov),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: 0.25),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Pin
                  Icon(
                    Icons.location_on_rounded,
                    color: color,
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

  // ─── Info Bottom Sheets ──────────────────────────────────────────────

  void _showSubmissionInfo(Map<String, dynamic> sub) {
    final formTitle = sub['forms']?['title_ar'] ?? 'نموذج';
    final status = sub['status'] ?? 'draft';
    final date =
        sub['created_at']?.toString().split('T')[0] ?? '';
    final gov = sub['governorates']?['name_ar'] ?? '';
    final dist = sub['districts']?['name_ar'] ?? '';
    final color = _statusColor(status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon(status), color: color, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                formTitle,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              EpiStatusChip(status: status),
              const SizedBox(height: 16),
              // Details row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (gov.isNotEmpty) ...[
                    _detailChip(Icons.location_city_rounded, gov),
                    const SizedBox(width: 12),
                  ],
                  if (dist.isNotEmpty) ...[
                    _detailChip(Icons.map_rounded, dist),
                    const SizedBox(width: 12),
                  ],
                  if (date.isNotEmpty)
                    _detailChip(Icons.calendar_today_rounded, date),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/forms/status/submission/${sub['id']}');
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('عرض التفاصيل',
                      style: TextStyle(fontFamily: 'Tajawal')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  void _showShortageInfo(Map<String, dynamic> shortage) {
    final item = shortage['item_name'] ?? 'غير محدد';
    final severity = shortage['severity'] ?? 'medium';
    final color = _severityColor(severity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              item,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'خطورة: $severity',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('إغلاق',
                    style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGovernorateInfo(Map<String, dynamic> gov) {
    final name = gov['name_ar'] ?? '';
    final nameEn = gov['name_en'] ?? '';
    final count =
        (gov['submission_count'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Avatar circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF00695C)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00897B).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.location_city_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (nameEn.isNotEmpty)
              Text(
                nameEn,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            const SizedBox(height: 16),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _govStatBox('الإرساليات', '$count',
                    Icons.description_rounded),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('إغلاق',
                    style: TextStyle(fontFamily: 'Tajawal')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _govStatBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00897B), size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2332),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
