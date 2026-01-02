import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../services/scan_requests_service.dart';

// Geocoding service for city coordinates
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
}

// Disease aggregation class
class _CityAgg {
  _CityAgg({
    required this.diseaseKey,
    required this.province,
    required this.city,
  });

  final String diseaseKey;
  final String province;
  final String city;
  int count = 0;
  double? lat;
  double? lng;
}

// Disease Map Widget
class DiseaseMapWidget extends StatefulWidget {
  final String selectedCity;
  final String selectedTimeRange;

  const DiseaseMapWidget({
    Key? key,
    required this.selectedCity,
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
  String? _selectedDisease;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true; // Keep widget alive when navigating

  // Davao del Norte bounds
  static final LatLngBounds _davaoDelNorteBounds = LatLngBounds(
    const LatLng(6.95, 125.45), // SW
    const LatLng(7.75, 126.05), // NE
  );

  // Disease keys for filtering
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
    // Load data on first init
    _loadDiseaseLocations();
  }

  @override
  void didUpdateWidget(covariant DiseaseMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always reload when city or time range changes (no caching)
    // Disease filter changes are handled by the dropdown's onChanged callback
    final cityChanged = oldWidget.selectedCity != widget.selectedCity;
    final timeRangeChanged =
        oldWidget.selectedTimeRange != widget.selectedTimeRange;

    if (cityChanged || timeRangeChanged) {
      _loadDiseaseLocations();
    }
  }

  String _canonicalDiseaseKey(String raw) {
    final normalized =
        raw
            .toLowerCase()
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

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
      default:
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

  Future<void> _loadDiseaseLocations() async {
    // Clear markers and heatmap circles immediately to avoid showing stale data
    setState(() {
      _markers = [];
      _heatmapCircles = [];
      _isLoading = true;
    });

    try {
      // Get all scan requests
      final all = await ScanRequestsService.getScanRequests();

      // Filter by city - be more strict with matching
      var cityFiltered = all;
      if (widget.selectedCity != 'All') {
        final selectedCityLower = widget.selectedCity.toLowerCase().trim();
        cityFiltered =
            all.where((request) {
              final city =
                  (request['cityMunicipality'] ?? '').toString().trim();
              final cityLower = city.toLowerCase();
              // Exact match (case-insensitive)
              return cityLower == selectedCityLower;
            }).toList();
      }

      // Filter by time range
      final filtered = ScanRequestsService.filterByTimeRange(
        cityFiltered,
        widget.selectedTimeRange,
      );

      // Only include completed reports
      final completed =
          filtered.where((r) => (r['status'] ?? '') == 'completed').toList();

      // Aggregate by city - start fresh
      final Map<String, _CityAgg> agg = {};
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

        if (province.isEmpty || city.isEmpty) continue;

        // Double-check city filter FIRST (safety check)
        if (widget.selectedCity != 'All') {
          if (city.toLowerCase() != widget.selectedCity.toLowerCase()) {
            continue; // Skip cities that don't match the filter
          }
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
          // Only now do we create an aggregation entry for this city+disease combination
          final aggKey =
              '${city.toLowerCase()}|${province.toLowerCase()}|$_selectedDisease';

          final cityAgg = agg.putIfAbsent(
            aggKey,
            () => _CityAgg(
              diseaseKey: _selectedDisease!,
              province: province,
              city: city,
            ),
          );

          // Double-check: the aggregation entry MUST have the correct disease key
          assert(
            cityAgg.diseaseKey == _selectedDisease,
            'Aggregation disease key mismatch: expected $_selectedDisease, got ${cityAgg.diseaseKey}',
          );

          // Only increment if disease key matches (should always be true at this point)
          if (cityAgg.diseaseKey == _selectedDisease) {
            cityAgg.count++;
          }
        } else {
          // If no disease filter, skip reports with no diseases
          if (diseaseKeysInReport.isEmpty) {
            continue;
          }
          // Group by city only when showing all diseases
          final aggKey = '${city.toLowerCase()}|${province.toLowerCase()}';

          agg.putIfAbsent(
            aggKey,
            () => _CityAgg(
              diseaseKey:
                  diseaseKeysInReport.isNotEmpty
                      ? diseaseKeysInReport.first
                      : 'swine_pox',
              province: province,
              city: city,
            ),
          );
          agg[aggKey]!.count++;
        }
      }

      // CRITICAL: Final cleanup - remove any aggregation entries that don't match filters
      final keysToRemove = <String>[];
      for (final entry in agg.entries) {
        final cityAgg = entry.value;

        // Remove entries with zero count
        if (cityAgg.count <= 0) {
          keysToRemove.add(entry.key);
          continue;
        }

        // If filtering by disease, ensure disease key matches exactly
        if (_selectedDisease != null) {
          if (cityAgg.diseaseKey != _selectedDisease) {
            keysToRemove.add(entry.key);
            continue;
          }
        }

        // If filtering by city, ensure city matches exactly
        if (widget.selectedCity != 'All') {
          if (cityAgg.city.toLowerCase().trim() !=
              widget.selectedCity.toLowerCase().trim()) {
            keysToRemove.add(entry.key);
            continue;
          }
        }
      }

      // Remove all invalid entries
      for (final key in keysToRemove) {
        agg.remove(key);
      }

      // Geocode cities
      for (final a in agg.values) {
        if (a.province.trim().isEmpty || a.city.trim().isEmpty) continue;
        final geo = await geocoder.geocodeCity(
          cityMunicipality: a.city,
          province: a.province,
        );
        if (geo != null) {
          a.lat = geo['lat'];
          a.lng = geo['lng'];
        }
      }

      // Create heatmap circles - only for cities that match ALL filters
      final heatmapCircles = <CircleMarker>[];
      final markers = <Marker>[]; // Keep markers for click interaction

      // Fixed absolute thresholds
      const int lowThreshold = 20; // Low: 1-20 cases
      const int mediumThreshold = 50; // Medium: 21-50 cases
      // High: 51+ cases

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

        // Final safety check: only show markers for the selected city
        if (widget.selectedCity != 'All') {
          if (a.city.toLowerCase().trim() !=
              widget.selectedCity.toLowerCase().trim()) {
            continue; // Skip cities that don't match
          }
        }

        final count = a.count;

        // Calculate intensity based on fixed thresholds (for color gradient)
        double intensity; // 0.0 to 1.0 for color gradient

        if (count <= lowThreshold) {
          // Low: 1-20 cases
          // Normalize within low range: 1 case = 0.0, 20 cases = 0.33
          intensity = (count / lowThreshold) * 0.33;
        } else if (count <= mediumThreshold) {
          // Medium: 21-50 cases
          // Normalize within medium range: 21 cases = 0.33, 50 cases = 0.67
          intensity =
              0.33 +
              ((count - lowThreshold) / (mediumThreshold - lowThreshold)) *
                  0.34;
        } else {
          // High: 51+ cases
          // Normalize within high range: 51 cases = 0.67, cap at 1.0 for very high counts
          final excess = count - mediumThreshold;
          intensity = 0.67 + (math.min(excess / 100.0, 1.0) * 0.33);
        }

        // Calculate circle size based on count category
        double radius;
        if (count <= lowThreshold) {
          // Low: 1km to 3km
          radius = 1000.0 + ((count / lowThreshold) * 2000.0);
        } else if (count <= mediumThreshold) {
          // Medium: 3km to 6km
          radius =
              3000.0 +
              (((count - lowThreshold) / (mediumThreshold - lowThreshold)) *
                  3000.0);
        } else {
          // High: 6km to 10km (capped)
          final excess = count - mediumThreshold;
          radius = 6000.0 + (math.min(excess / 50.0, 1.0) * 4000.0);
        }

        // Get heatmap color based on intensity
        final heatmapColor = _getHeatmapColor(intensity);

        // Create heatmap circle (solid color, no opacity)
        heatmapCircles.add(
          CircleMarker(
            point: LatLng(a.lat!, a.lng!),
            radius: radius,
            color: heatmapColor, // Solid color, no opacity
            borderColor: heatmapColor,
            borderStrokeWidth: 2.0,
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
                _showMarkerInfo(
                  a.diseaseKey,
                  count,
                  city: a.city,
                  province: a.province,
                );
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
    required String city,
    required String province,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(_getDiseaseDisplayName(diseaseKey)),
            content: Text(
              'Location: $city, $province\nCases: $count\nIntensity: ${_getIntensityLabelFromCount(count)}',
              style: const TextStyle(fontSize: 16),
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

  /// Get heatmap color based on intensity (0.0 to 1.0)
  /// Returns gradient from green (low) -> yellow (medium) -> red (high)
  ///
  /// Fixed Absolute Thresholds:
  /// - Low (Green): 1-20 cases
  /// - Medium (Yellow): 21-50 cases
  /// - High (Red): 51+ cases
  Color _getHeatmapColor(double intensity) {
    if (intensity <= 0.0) return const Color(0xFF4CAF50); // Green
    if (intensity >= 1.0) return const Color(0xFFF44336); // Red

    // Define thresholds for Low/Medium/High
    const lowThreshold = 0.33; // 0.0 to 0.33 = Low (Green)
    const mediumThreshold = 0.67; // 0.33 to 0.67 = Medium (Yellow)
    // 0.67 to 1.0 = High (Red)

    if (intensity < lowThreshold) {
      // Low: Green to Light Green (0.0 to 0.33)
      final t = intensity / lowThreshold; // Scale to 0.0-1.0
      return Color.lerp(
        const Color(0xFF4CAF50), // Green
        const Color(0xFF8BC34A), // Light Green
        t,
      )!;
    } else if (intensity < mediumThreshold) {
      // Medium: Light Green to Yellow (0.33 to 0.67)
      final t =
          (intensity - lowThreshold) /
          (mediumThreshold - lowThreshold); // Scale to 0.0-1.0
      return Color.lerp(
        const Color(0xFF8BC34A), // Light Green
        const Color(0xFFFFEB3B), // Yellow
        t,
      )!;
    } else {
      // High: Yellow to Red (0.67 to 1.0)
      final t =
          (intensity - mediumThreshold) /
          (1.0 - mediumThreshold); // Scale to 0.0-1.0
      return Color.lerp(
        const Color(0xFFFFEB3B), // Yellow
        const Color(0xFFF44336), // Red
        t,
      )!;
    }
  }

  /// Get intensity category label based on actual count
  /// Uses fixed absolute thresholds
  String _getIntensityLabelFromCount(int count) {
    if (count <= 20) return 'Low';
    if (count <= 50) return 'Medium';
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
                        _buildLegendItem(const Color(0xFFFFEB3B), 'Medium'),
                        const SizedBox(width: 16),
                        _buildLegendItem(const Color(0xFFF44336), 'High'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thresholds: Low (1-20 cases) | Medium (21-50 cases) | High (51+ cases)',
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
                      hint: const Text('All', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All', style: TextStyle(fontSize: 12)),
                        ),
                        ..._diseaseKeys.map((key) {
                          return DropdownMenuItem<String>(
                            value: key,
                            child: Text(
                              _getDiseaseDisplayName(key),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ],
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
                      initialCenter: _davaoDelNorteBounds.center,
                      initialZoom: 9.0,
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
