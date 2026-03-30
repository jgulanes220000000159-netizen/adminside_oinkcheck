import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/layer/shared/mobile_layer_transformer.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../services/scan_requests_service.dart';

// Geocoding service for city/barangay coordinates
class GeocodingService {
  Future<Map<String, double>?> geocodeCity({
    required String cityMunicipality,
    required String province,
  }) async {
    final c = cityMunicipality.trim();
    final p = province.trim();
    if (c.isEmpty || p.isEmpty) return null;

    final q = '$c, $p, Philippines';
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '1',
    });

    try {
      final resp = await http
          .get(
            uri,
            headers: const {'User-Agent': 'OinkCheck/1.0 (disease-map-city)'},
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return null;
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final m = data.first as Map<String, dynamic>;
      final lat = double.tryParse(m['lat']?.toString() ?? '');
      final lng = double.tryParse(m['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> geocodeBarangay({
    required String barangay,
    required String cityMunicipality,
    required String province,
  }) async {
    final b = barangay.trim();
    final c = cityMunicipality.trim();
    final p = province.trim();
    if (b.isEmpty || c.isEmpty || p.isEmpty) return null;

    final q = '$b, $c, $p, Philippines';
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '1',
    });

    try {
      final resp = await http
          .get(
            uri,
            headers: const {'User-Agent': 'OinkCheck/1.0 (disease-map-barangay)'},
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return null;
      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      if (data.isEmpty) return null;
      final m = data.first as Map<String, dynamic>;
      final lat = double.tryParse(m['lat']?.toString() ?? '');
      final lng = double.tryParse(m['lon']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return {'lat': lat, 'lng': lng};
    } catch (_) {
      return null;
    }
  }
}

// Disease aggregation class
class _LocationAgg {
  _LocationAgg({
    required this.diseaseKey,
    required this.province,
    required this.city,
    required this.barangay,
  });

  final String diseaseKey;
  final String province;
  final String city;
  final String barangay;
  int count = 0; // Total case count (for heatmap intensity)
  double? lat;
  double? lng;
  // Track disease breakdown when showing "All" diseases (for info display)
  final Map<String, int> diseaseBreakdown = {}; // diseaseKey -> count
}

// Disease Map Widget
class DiseaseMapWidget extends StatefulWidget {
  final String selectedCity;
  final String selectedBarangay;
  final String selectedTimeRange;

  const DiseaseMapWidget({
    Key? key,
    required this.selectedCity,
    required this.selectedBarangay,
    required this.selectedTimeRange,
  }) : super(key: key);

  @override
  State<DiseaseMapWidget> createState() => _DiseaseMapWidgetState();
}

class _DiseaseMapWidgetState extends State<DiseaseMapWidget>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<CircleMarker> _heatmapCircles = [];
  List<Polygon> _ddnPolygons = [];
  String? _selectedDisease;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Keep widget alive when navigating

  // Davao del Norte bounds
  static final LatLngBounds _davaoDelNorteBounds = LatLngBounds(
    const LatLng(6.95, 125.45), // SW
    const LatLng(7.75, 126.05), // NE
  );

  // Disease keys for filtering (dermatitis and pityriasis_rosea excluded per product)
  final List<String> _diseaseKeys = const [
    'swine_pox',
    'infected_bacterial_erysipelas',
    'infected_bacterial_greasy',
    'infected_environmental_sunburn',
    'infected_fungal_ringworm',
    'infected_parasitic_mange',
    'infected_viral_foot_and_mouth',
  ];

  @override
  void initState() {
    super.initState();
    _loadDavaoDelNorteBoundary();
    // Load data on first init
    _loadDiseaseLocations();
  }

  @override
  void didUpdateWidget(covariant DiseaseMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always reload when city or time range changes (no caching)
    // Disease filter changes are handled by the dropdown's onChanged callback
    final cityChanged = oldWidget.selectedCity != widget.selectedCity;
    final barangayChanged =
        oldWidget.selectedBarangay != widget.selectedBarangay;
    final timeRangeChanged =
        oldWidget.selectedTimeRange != widget.selectedTimeRange;

    if (cityChanged || barangayChanged || timeRangeChanged) {
      _loadDiseaseLocations();
    }
  }

  bool _matchesSelectedLocation({
    required String city,
    required String barangay,
  }) {
    final cityMatches =
        widget.selectedCity == 'All' ||
        city.toLowerCase().trim() == widget.selectedCity.toLowerCase().trim();
    final barangayMatches =
        widget.selectedBarangay == 'All' ||
        barangay.toLowerCase().trim() ==
            widget.selectedBarangay.toLowerCase().trim();
    return cityMatches && barangayMatches;
  }

  String _canonicalDiseaseKey(String raw) {
    final normalized =
        raw
            .toLowerCase()
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    // Normalize to stable keys so filters and breakdowns match,
    // even if the stored label has extra words or minor variants.
    switch (normalized) {
      case 'erysipelas':
      case 'bacterial erysipelas':
      case 'infected bacterial erysipelas':
        return 'infected_bacterial_erysipelas';
      case 'greasy pig disease':
      case 'greasy':
      case 'infected bacterial greasy':
        return 'infected_bacterial_greasy';
      case 'sunburn':
      case 'infected environmental sunburn':
        return 'infected_environmental_sunburn';
      case 'ringworm':
      case 'infected fungal ringworm':
        return 'infected_fungal_ringworm';
      case 'mange':
      case 'infected parasitic mange':
        return 'infected_parasitic_mange';
      case 'foot and mouth':
      case 'foot-and-mouth disease':
      case 'infected viral foot and mouth':
        return 'infected_viral_foot_and_mouth';
      case 'swine pox':
      case 'swinepox':
        return 'swine_pox';

      // Dermatitis — handle labels like "Dermatitis / dermatatis",
      // "Environmental Dermatitis", etc.
      default:
        // Match broad patterns for new classes first
        if (normalized.contains('dermatitis') ||
            normalized.contains('dermatatis')) {
          return 'dermatitis';
        }
        if (normalized.contains('pityriasis')) {
          return 'pityriasis_rosea';
        }
        return normalized.replaceAll(' ', '_');
    }
  }

  String _getDiseaseDisplayName(String key) {
    switch (key) {
      case 'infected_bacterial_erysipelas':
        return 'Bacterial Erysipelas';
      case 'infected_bacterial_greasy':
        return 'Greasy Pig Disease';
      case 'infected_environmental_sunburn':
        return 'Sunburn';
      case 'infected_fungal_ringworm':
        return 'Ringworm';
      case 'infected_parasitic_mange':
        return 'Mange';
      case 'infected_viral_foot_and_mouth':
        return 'Foot-and-Mouth Disease';
      case 'swine_pox':
        return 'Swine Pox';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) {
              return word.isEmpty
                  ? ''
                  : word[0].toUpperCase() + word.substring(1);
            })
            .join(' ');
    }
  }

  Future<void> _loadDavaoDelNorteBoundary() async {
    try {
      final rawGeoJson = await rootBundle.loadString('assets/DDN.geojson');
      final Map<String, dynamic> geoJson =
          jsonDecode(rawGeoJson) as Map<String, dynamic>;
      final List<dynamic> features =
          geoJson['features'] as List<dynamic>? ?? const <dynamic>[];

      final List<Polygon> polygons = [];
      for (final feature in features) {
        if (feature is! Map) continue;
        final geometry = feature['geometry'];
        if (geometry is! Map) continue;

        final geometryType = (geometry['type'] ?? '').toString();
        final coordinates = geometry['coordinates'];

        if (geometryType == 'Polygon' && coordinates is List) {
          final polygon = _polygonFromRings(coordinates);
          if (polygon != null) polygons.add(polygon);
        } else if (geometryType == 'MultiPolygon' && coordinates is List) {
          for (final polygonCoords in coordinates) {
            if (polygonCoords is List) {
              final polygon = _polygonFromRings(polygonCoords);
              if (polygon != null) polygons.add(polygon);
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _ddnPolygons = polygons;
      });
    } catch (_) {
      // Keep the map working even if the boundary asset fails to load.
    }
  }

  Polygon? _polygonFromRings(List<dynamic> rings) {
    if (rings.isEmpty) return null;

    final outerRing = _latLngRingFromDynamic(rings.first);
    if (outerRing.length < 3) return null;

    final holeRings = <List<LatLng>>[];
    for (final hole in rings.skip(1)) {
      final holeRing = _latLngRingFromDynamic(hole);
      if (holeRing.length >= 3) {
        holeRings.add(holeRing);
      }
    }

    return Polygon(
      points: outerRing,
      holePointsList: holeRings.isEmpty ? null : holeRings,
      color: const Color(0xFF2D7204).withOpacity(0.10),
      borderColor: const Color(0xFF111111),
      borderStrokeWidth: 1.2,
    );
  }

  List<LatLng> _latLngRingFromDynamic(dynamic ring) {
    if (ring is! List) return const <LatLng>[];

    final points = <LatLng>[];
    for (final coordinate in ring) {
      if (coordinate is List && coordinate.length >= 2) {
        final lng = (coordinate[0] as num?)?.toDouble();
        final lat = (coordinate[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          points.add(LatLng(lat, lng));
        }
      }
    }
    return points;
  }

  Future<void> _loadDiseaseLocations() async {
    // When no disease selected, show empty map — user must select a disease first
    if (_selectedDisease == null) {
      setState(() {
        _markers = [];
        _heatmapCircles = [];
        _isLoading = false;
      });
      return;
    }

    // Clear markers and heatmap circles immediately to avoid showing stale data
    setState(() {
      _markers = [];
      _heatmapCircles = [];
      _isLoading = true;
    });

    try {
      // Get all scan requests
      final all = await ScanRequestsService.getScanRequests();

      final cityFiltered =
          all.where((request) {
            final city =
                (request['cityMunicipality'] ?? '').toString().trim();
            final barangay = (request['barangay'] ?? '').toString().trim();
            return _matchesSelectedLocation(city: city, barangay: barangay);
          }).toList();

      // Filter by time range
      final filtered = ScanRequestsService.filterByTimeRange(
        cityFiltered,
        widget.selectedTimeRange,
      );

      // Only include completed reports
      final completed =
          filtered.where((r) => (r['status'] ?? '') == 'completed').toList();

      // Aggregate by barangay - start fresh
      final Map<String, _LocationAgg> agg = {};
      final geocoder = GeocodingService();

      // Process each completed report
      for (final data in completed) {
        // ONLY use expert-validated disease summary (skip reports without expert validation)
        final expertDiseaseSummary = data['expertDiseaseSummary'];
        if (expertDiseaseSummary == null ||
            !(expertDiseaseSummary is List) ||
            (expertDiseaseSummary as List).isEmpty) {
          continue; // Skip reports that haven't been validated by an expert
        }
        final rawSummary = expertDiseaseSummary as List;
        final List<Map<String, dynamic>> cleaned = [];
        for (final e in rawSummary) {
          if (e is Map) cleaned.add(Map<String, dynamic>.from(e));
        }

        // Get city and province first for filtering
        final province = (data['province'] ?? '').toString().trim();
        final city = (data['cityMunicipality'] ?? '').toString().trim();
        final barangay = (data['barangay'] ?? '').toString().trim();

        if (province.isEmpty || city.isEmpty) continue;

        if (!_matchesSelectedLocation(city: city, barangay: barangay)) {
          continue;
        }

        // Collect all disease labels present in this report
        final Set<String> diseaseKeysInReport = {};
        for (final e in cleaned) {
          final label = e['label']?.toString() ?? '';
          if (label.isNotEmpty) {
            final canonicalKey = _canonicalDiseaseKey(label);
            if (canonicalKey.isNotEmpty) {
              diseaseKeysInReport.add(canonicalKey);
            }
          }
        }
        // Exclude dermatitis and pityriasis rosea — do not show anywhere
        diseaseKeysInReport.remove('dermatitis');
        diseaseKeysInReport.remove('pityriasis_rosea');
        if (diseaseKeysInReport.isEmpty) continue;

        // If a specific disease is selected, ONLY process reports that contain it
        if (_selectedDisease != null) {
          // CRITICAL: Check if this report has the selected disease
          // Use exact match (case-sensitive) since both should be canonical keys
          bool hasSelectedDisease = false;
          for (final diseaseKey in diseaseKeysInReport) {
            if (diseaseKey == _selectedDisease) {
              hasSelectedDisease = true;
              break;
            }
          }

          // If this report does NOT have the selected disease, skip it completely
          // Do NOT create any aggregation entry for this report
          if (!hasSelectedDisease) {
            continue; // Skip this report - it doesn't have the selected disease
          }

          // At this point, we're 100% certain this report has the selected disease
          // Verify one more time before proceeding
          assert(
            diseaseKeysInReport.contains(_selectedDisease),
            'Report should have selected disease $_selectedDisease but diseaseKeysInReport is $diseaseKeysInReport',
          );

          // At this point, we're 100% certain this report has the selected disease
          // Only now do we create an aggregation entry for this barangay+disease combination
          final aggKey =
              '${barangay.toLowerCase()}|${city.toLowerCase()}|${province.toLowerCase()}|$_selectedDisease';

          final locationAgg = agg.putIfAbsent(
            aggKey,
            () => _LocationAgg(
              diseaseKey: _selectedDisease!,
              province: province,
              city: city,
              barangay: barangay,
            ),
          );

          // Double-check: the aggregation entry MUST have the correct disease key
          assert(
            locationAgg.diseaseKey == _selectedDisease,
            'Aggregation disease key mismatch: expected $_selectedDisease, got ${locationAgg.diseaseKey}',
          );

          // Only increment if disease key matches (should always be true at this point)
          if (locationAgg.diseaseKey == _selectedDisease) {
            locationAgg.count++;
          }
        } else {
          // If no disease filter, aggregate by barangay for traditional heatmap
          // Total intensity = sum of all reports (each report = 1 case)
          if (diseaseKeysInReport.isEmpty) {
            continue;
          }
          final aggKey =
              '${barangay.toLowerCase()}|${city.toLowerCase()}|${province.toLowerCase()}';

          final locationAgg = agg.putIfAbsent(
            aggKey,
            () => _LocationAgg(
              diseaseKey: 'all_diseases', // Special key for "All" mode
              province: province,
              city: city,
              barangay: barangay,
            ),
          );

          // Increment total count (each report = 1 case for heatmap intensity)
          locationAgg.count++;

          // Track disease breakdown for info display
          for (final diseaseKey in diseaseKeysInReport) {
            locationAgg.diseaseBreakdown[diseaseKey] =
                (locationAgg.diseaseBreakdown[diseaseKey] ?? 0) + 1;
          }
        }
      }

      // CRITICAL: Final cleanup - remove any aggregation entries that don't match filters
      final keysToRemove = <String>[];
      for (final entry in agg.entries) {
        final locationAgg = entry.value;

        // Remove entries with zero count
        if (locationAgg.count <= 0) {
          keysToRemove.add(entry.key);
          continue;
        }

        // If filtering by disease, ensure disease key matches exactly
        if (_selectedDisease != null) {
          if (locationAgg.diseaseKey != _selectedDisease) {
            keysToRemove.add(entry.key);
            continue;
          }
        }

        if (!_matchesSelectedLocation(
          city: locationAgg.city,
          barangay: locationAgg.barangay,
        )) {
          keysToRemove.add(entry.key);
          continue;
        }
      }

      // Remove all invalid entries
      for (final key in keysToRemove) {
        agg.remove(key);
      }

      // Geocode barangays, with city fallback if barangay lookup fails
      for (final a in agg.values) {
        if (a.province.trim().isEmpty || a.city.trim().isEmpty) continue;
        Map<String, double>? geo;
        if (a.barangay.trim().isNotEmpty) {
          geo = await geocoder.geocodeBarangay(
            barangay: a.barangay,
            cityMunicipality: a.city,
            province: a.province,
          );
        }
        geo ??= await geocoder.geocodeCity(
          cityMunicipality: a.city,
          province: a.province,
        );
        if (geo != null) {
          a.lat = geo['lat'];
          a.lng = geo['lng'];
        }
      }

      // Create heatmap circles - only for barangays that match ALL filters
      final heatmapCircles = <CircleMarker>[];
      final markers = <Marker>[]; // Keep markers for click interaction

      // Percentage thresholds based on completed scans.
      const double lowThresholdPct = 10.0; // Low: <=10%
      const double mediumThresholdPct = 30.0; // Medium: 11-30%
      // High: >=31%
      final int totalCompletedScans = completed.length;

      for (final a in agg.values) {
        // Must have coordinates
        if (a.lat == null || a.lng == null) continue;

        // Must have at least one report
        if (a.count <= 0) continue;

        // CRITICAL: If disease filter is active, verify this aggregation has that disease
        if (_selectedDisease != null) {
          // The disease key MUST exactly match the selected disease
          if (a.diseaseKey != _selectedDisease) {
            continue; // Skip - this aggregation doesn't have the selected disease
          }
        }

        if (!_matchesSelectedLocation(city: a.city, barangay: a.barangay)) {
          continue;
        }

        final count = a.count;
        final double percentageOfCompleted =
            totalCompletedScans <= 0
                ? 0.0
                : (count / totalCompletedScans) * 100.0;

        // Calculate intensity based on percentage thresholds (for color gradient)
        double intensity; // 0.0 to 1.0 for color gradient

        if (percentageOfCompleted <= lowThresholdPct) {
          // Low: 0-10%
          // Normalize within low range: 0% = 0.0, 10% = 0.33
          intensity = (percentageOfCompleted / lowThresholdPct) * 0.33;
        } else if (percentageOfCompleted <= mediumThresholdPct) {
          // Medium: 11-30%
          // Normalize within medium range: 10% = 0.33, 30% = 0.67
          intensity =
              0.33 +
              ((percentageOfCompleted - lowThresholdPct) /
                      (mediumThresholdPct - lowThresholdPct)) *
                  0.34;
        } else {
          // High: 31%+
          // Normalize within high range: 30% = 0.67, 100% = 1.0
          final highSpan = 100.0 - mediumThresholdPct;
          intensity =
              0.67 +
              (math.min((percentageOfCompleted - mediumThresholdPct) / highSpan, 1.0) *
                  0.33);
        }

        // Calculate circle size based on percentage category
        double radius;
        if (percentageOfCompleted <= lowThresholdPct) {
          // Low: 500m to 1.5km
          radius = 500.0 + ((percentageOfCompleted / lowThresholdPct) * 1000.0);
        } else if (percentageOfCompleted <= mediumThresholdPct) {
          // Medium: 1.5km to 3km
          radius =
              1500.0 +
              (((percentageOfCompleted - lowThresholdPct) /
                      (mediumThresholdPct - lowThresholdPct)) *
                  1500.0);
        } else {
          // High: 3km to 5km (capped)
          final highSpan = 100.0 - mediumThresholdPct;
          radius =
              3000.0 +
              (math.min((percentageOfCompleted - mediumThresholdPct) / highSpan, 1.0) *
                  2000.0);
        }

        // Get heatmap color based on intensity
        final heatmapColor = _getHeatmapColor(intensity);

        // Create smooth gradient heatmap effect using multiple overlapping circles
        // This simulates Kernel Density Estimation (KDE) for a smooth gradient
        // More layers = smoother gradient (like the reference image)
        final int numLayers = 5; // Increased layers for smoother gradient
        for (int i = 0; i < numLayers; i++) {
          // Each layer extends further with decreasing opacity
          final layerRadius =
              radius *
              (1.0 +
                  (i *
                      0.2)); // Layers extend outward (reduced from 0.25 to 0.2)
          // Opacity decreases exponentially for smooth falloff
          final layerOpacity =
              0.6 *
              math.exp(
                -i * 0.4,
              ); // Exponential decay: 0.6, 0.4, 0.27, 0.18, 0.12

          if (layerRadius > 50 && layerOpacity > 0.05) {
            // Add gradient layers (semi-transparent for blending)
            heatmapCircles.add(
              CircleMarker(
                point: LatLng(a.lat!, a.lng!),
                radius: layerRadius,
                color: heatmapColor.withOpacity(layerOpacity),
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
                useRadiusInMeter: true,
              ),
            );
          }
        }

        // Add a solid center circle for the core intensity point (like reference image)
        // This creates the "hotspot" effect with white outline
        heatmapCircles.add(
          CircleMarker(
            point: LatLng(a.lat!, a.lng!),
            radius: radius * 0.15, // Smaller solid center
            color: heatmapColor, // Solid color (no opacity)
            borderColor: Colors.white.withOpacity(
              0.9,
            ), // White outline like reference
            borderStrokeWidth: 2.0, // Visible outline
            useRadiusInMeter: true,
          ),
        );

        // Create invisible marker for click interaction
        markers.add(
          Marker(
            point: LatLng(a.lat!, a.lng!),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // Show disease breakdown if "All" is selected, otherwise show single disease
                if (a.diseaseKey == 'all_diseases' &&
                    a.diseaseBreakdown.isNotEmpty) {
                  final diseaseList = a.diseaseBreakdown.entries
                      .map(
                        (e) => '${_getDiseaseDisplayName(e.key)}: ${e.value}',
                      )
                      .join('\n');
                  _showMarkerInfo(
                    'All Diseases',
                    count,
                    percentageOfCompleted: percentageOfCompleted,
                    barangay: a.barangay,
                    city: a.city,
                    province: a.province,
                    diseaseBreakdown: diseaseList,
                  );
                } else {
                  _showMarkerInfo(
                    a.diseaseKey,
                    count,
                    percentageOfCompleted: percentageOfCompleted,
                    barangay: a.barangay,
                    city: a.city,
                    province: a.province,
                  );
                }
              },
              child: Container(
                color: Colors.transparent,
                width: 40,
                height: 40,
              ),
            ),
          ),
        );
      }

      setState(() {
        _heatmapCircles = heatmapCircles;
        _markers = markers;
        _isLoading = false;
      });

      // Zoom to Davao del Norte
      Future.microtask(() {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _davaoDelNorteBounds,
            padding: const EdgeInsets.all(32),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMarkerInfo(
    String diseaseKey,
    int count, {
    required double percentageOfCompleted,
    required String barangay,
    required String city,
    required String province,
    String? diseaseBreakdown,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              diseaseKey == 'all_diseases' || diseaseKey == 'All Diseases'
                  ? 'All Diseases'
                  : _getDiseaseDisplayName(diseaseKey),
            ),
            content: SingleChildScrollView(
              child: Text(
                diseaseBreakdown != null
                    ? 'Location: ${barangay.isEmpty ? 'Unspecified Barangay' : barangay}, $city, $province\nTotal Cases: $count\nCompleted Scan Share: ${percentageOfCompleted.toStringAsFixed(1)}%\nIntensity: ${_getIntensityLabelFromPercentage(percentageOfCompleted)}\n\nDisease Breakdown:\n$diseaseBreakdown'
                    : 'Location: ${barangay.isEmpty ? 'Unspecified Barangay' : barangay}, $city, $province\nCases: $count\nCompleted Scan Share: ${percentageOfCompleted.toStringAsFixed(1)}%\nIntensity: ${_getIntensityLabelFromPercentage(percentageOfCompleted)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _getSeverityLabel(int count) {
    if (count >= 51) return 'Severe';
    if (count >= 21) return 'Moderate';
    return 'Mild';
  }

  Color _severityColor(int count) {
    if (count >= 51) return Colors.red;
    if (count >= 21) return Colors.orange;
    return Colors.green;
  }

  /// Get heatmap color based on normalized intensity (0.0 to 1.0).
  /// Uses strict category colors (no gradient):
  /// - Low: Green
  /// - Medium: Orange
  /// - High: Red
  Color _getHeatmapColor(double intensity) {
    // Intensity buckets map to percentage buckets:
    // <= 0.33 => <=10% (Low), <= 0.67 => 11-30% (Medium), > 0.67 => >=31% (High)
    if (intensity <= 0.33) return const Color(0xFF4CAF50); // Green
    if (intensity <= 0.67) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  /// Get intensity category label based on percentage of completed scans
  /// Thresholds: Low <=10%, Medium 11-30%, High >=31%
  String _getIntensityLabelFromPercentage(double percentage) {
    if (percentage <= 10.0) return 'Low';
    if (percentage <= 30.0) return 'Medium';
    return 'High';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend and disease filter - more compact layout
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Legend on the left
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(const Color(0xFF4CAF50), 'Low'),
                        const SizedBox(width: 16),
                        _buildLegendItem(const Color(0xFFFF9800), 'Medium'),
                        const SizedBox(width: 16),
                        _buildLegendItem(const Color(0xFFF44336), 'High'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thresholds: Low (<=10%) | Medium (11-30%) | High (>=31%)',
                      style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Disease filter on the right
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Disease Filter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedDisease,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                      hint: const Text(
                        'Select disease',
                        style: TextStyle(fontSize: 12),
                      ),
                      items: _diseaseKeys.map((key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(
                            _getDiseaseDisplayName(key),
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (_selectedDisease != value) {
                          setState(() {
                            _selectedDisease = value;
                          });
                          _loadDiseaseLocations();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Map
        SizedBox(
          height: 500,
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: _davaoDelNorteBounds,
                        padding: const EdgeInsets.all(32),
                      ),
                      minZoom: 5.0,
                      maxZoom: 18.0,
                      onMapReady: () {
                        Future.microtask(() {
                          _mapController.fitCamera(
                            CameraFit.bounds(
                              bounds: _davaoDelNorteBounds,
                              padding: const EdgeInsets.all(32),
                            ),
                          );
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.capstone',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      if (_ddnPolygons.isNotEmpty)
                        _DdnOutsideMaskLayer(
                          polygons: _ddnPolygons,
                        ),
                      if (_ddnPolygons.isNotEmpty)
                        PolygonLayer(
                          polygons: _ddnPolygons,
                        ),
                      CircleLayer(circles: _heatmapCircles),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DdnOutsideMaskLayer extends StatelessWidget {
  const _DdnOutsideMaskLayer({
    required this.polygons,
  });

  final List<Polygon> polygons;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = Size(camera.size.x, camera.size.y);

    return MobileLayerTransformer(
      child: IgnorePointer(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: _DdnOutsideMaskPainter(
              camera: camera,
              polygons: polygons,
              maskColor: const Color(0xFFF8FAFC).withOpacity(0.78),
            ),
          ),
        ),
      ),
    );
  }
}

class _DdnOutsideMaskPainter extends CustomPainter {
  _DdnOutsideMaskPainter({
    required this.camera,
    required this.polygons,
    required this.maskColor,
  });

  final MapCamera camera;
  final List<Polygon> polygons;
  final Color maskColor;

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Path path =
        ui.Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size);

    final origin = camera.pixelOrigin;
    final originOffset = Offset(origin.x.toDouble(), origin.y.toDouble());

    for (final polygon in polygons) {
      _addRing(path, polygon.points, originOffset);
      final holes = polygon.holePointsList;
      if (holes != null) {
        for (final hole in holes) {
          _addRing(path, hole, originOffset);
        }
      }
    }

    final paint =
        Paint()
          ..color = maskColor
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  void _addRing(ui.Path path, List<LatLng> points, Offset origin) {
    if (points.length < 3) return;

    final offsets = <Offset>[];
    for (final point in points) {
      final projected = camera.project(point);
      offsets.add(
        Offset(
          projected.x.toDouble() - origin.dx,
          projected.y.toDouble() - origin.dy,
        ),
      );
    }

    final ui.Path polygonPath = ui.Path()..addPolygon(offsets, true);
    path.addPath(polygonPath, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _DdnOutsideMaskPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.polygons != polygons ||
        oldDelegate.maskColor != maskColor;
  }
}
