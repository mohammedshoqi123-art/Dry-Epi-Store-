import 'dart:math';

/// Geo-location utility functions for the EPI platform.
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusKm = 6371.0;

  // ─── Distance ─────────────────────────────────────────────────────────────

  /// Calculate distance between two coordinates in kilometers (Haversine formula)
  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  /// Distance in meters
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      distanceKm(lat1, lng1, lat2, lng2) * 1000;

  // ─── Validation ───────────────────────────────────────────────────────────

  /// Check if coordinates are valid
  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  /// Check if point is within Yemen's bounding box
  static bool isWithinYemen(double lat, double lng) {
    // Yemen approximate bounding box
    return lat >= 12.0 && lat <= 19.0 && lng >= 42.0 && lng <= 54.0;
  }

  /// Generic: Check if point is within a country bounding box
  static bool isWithinBounds(double lat, double lng, {
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  // ─── Formatting ───────────────────────────────────────────────────────────

  /// Format coordinates for display
  static String formatCoordinates(double lat, double lng, {int decimals = 6}) {
    return '${lat.toStringAsFixed(decimals)}, ${lng.toStringAsFixed(decimals)}';
  }

  /// Format coordinates in DMS (degrees, minutes, seconds)
  static String formatDMS(double dd, bool isLatitude) {
    final d = dd.abs().floor();
    final m = ((dd.abs() - d) * 60).floor();
    final s = ((dd.abs() - d - m / 60) * 3600).toStringAsFixed(1);
    final dir = isLatitude ? (dd >= 0 ? 'N' : 'S') : (dd >= 0 ? 'E' : 'W');
    return '$d°$m\'$s\" $dir';
  }

  /// Short distance display (m or km)
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  // ─── PostGIS ──────────────────────────────────────────────────────────────

  /// Convert lat/lng to PostGIS POINT string
  static String toPostGISPoint(double lat, double lng) {
    return 'POINT($lng $lat)';
  }

  /// Parse PostGIS POINT string to lat/lng
  static (double lat, double lng)? fromPostGISPoint(String? point) {
    if (point == null) return null;
    final match = RegExp(r'POINT\(([+-]?\d+\.?\d*) ([+-]?\d+\.?\d*)\)')
        .firstMatch(point);
    if (match == null) return null;
    final lng = double.tryParse(match.group(1) ?? '');
    final lat = double.tryParse(match.group(2) ?? '');
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  // ─── Bounding Box ─────────────────────────────────────────────────────────

  /// Get bounding box around a point
  static ({double north, double south, double east, double west}) boundingBox(
    double lat,
    double lng,
    double radiusKm,
  ) {
    final latDelta = radiusKm / _earthRadiusKm * (180 / pi);
    final lngDelta =
        radiusKm / (_earthRadiusKm * cos(_toRad(lat))) * (180 / pi);

    return (
      north: lat + latDelta,
      south: lat - latDelta,
      east: lng + lngDelta,
      west: lng - lngDelta,
    );
  }

  static double _toRad(double deg) => deg * pi / 180;
}
