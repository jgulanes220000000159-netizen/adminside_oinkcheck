import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  String? _selectedDisease;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  String? _lastCity;
  String? _lastTimeRange;
  String? _lastDisease;

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
    // Initialize last values
    _lastCity = widget.selectedCity;
    _lastTimeRange = widget.selectedTimeRange;
    _lastDisease = _selectedDisease;
    // Load data on first init
    _loadDiseaseLocations();
  }

  @override
  void didUpdateWidget(covariant DiseaseMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if filters actually changed
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
    // Check if we need to reload (filters changed)
    final needsReload =
        _lastCity != widget.selectedCity ||
        _lastTimeRange != widget.selectedTimeRange ||
        _lastDisease != _selectedDisease;

    // If we have markers and filters haven't changed, don't reload
    if (_hasLoadedOnce && _markers.isNotEmpty && !needsReload) {
      return;
    }

    // Update last values
    _lastCity = widget.selectedCity;
    _lastTimeRange = widget.selectedTimeRange;
    _lastDisease = _selectedDisease;

    setState(() {
      _isLoading =
          _markers.isEmpty; // Only show loading if we don't have markers
    });

    try {
      // Get all scan requests
      final all = await ScanRequestsService.getScanRequests();

      // Filter by city
      var cityFiltered = all;
      if (widget.selectedCity != 'All') {
        cityFiltered =
            all.where((request) {
              final city =
                  (request['cityMunicipality'] ?? '').toString().trim();
              return city.toLowerCase() == widget.selectedCity.toLowerCase();
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

      // Aggregate by city
      final Map<String, _CityAgg> agg = {};
      final geocoder = GeocodingService();

      for (final data in completed) {
        final rawSummary = (data['diseaseSummary'] as List?) ?? const [];
        final List<Map<String, dynamic>> cleaned = [];
        for (final e in rawSummary) {
          if (e is Map) cleaned.add(Map<String, dynamic>.from(e));
        }
        if (cleaned.isEmpty) continue;

        // Collect all disease labels
        final Set<String> diseaseKeysInReport =
            cleaned
                .map((e) => _canonicalDiseaseKey(e['label']?.toString() ?? ''))
                .where((k) => k.isNotEmpty)
                .toSet();

        // Filter by selected disease
        if (_selectedDisease != null &&
            !diseaseKeysInReport.contains(_selectedDisease)) {
          continue;
        }

        final province = (data['province'] ?? '').toString();
        final city = (data['cityMunicipality'] ?? '').toString();

        if (province.trim().isEmpty || city.trim().isEmpty) continue;

        // Group by city
        final key = '${city.toLowerCase()}|${province.toLowerCase()}';
        agg.putIfAbsent(
          key,
          () => _CityAgg(
            diseaseKey:
                diseaseKeysInReport.isNotEmpty
                    ? diseaseKeysInReport.first
                    : 'swine_pox',
            province: province,
            city: city,
          ),
        );
        agg[key]!.count++;
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

      // Create markers
      final markers = <Marker>[];
      for (final a in agg.values) {
        if (a.lat == null || a.lng == null) continue;
        final count = a.count;
        final severityColor = _severityColor(count);
        final double pinSize = (32 + (count * 4)).clamp(32, 56).toDouble();

        markers.add(
          Marker(
            point: LatLng(a.lat!, a.lng!),
            width: pinSize,
            height: pinSize,
            child: GestureDetector(
              onTap: () {
                _showMarkerInfo(
                  a.diseaseKey,
                  count,
                  city: a.city,
                  province: a.province,
                );
              },
              child: Icon(
                Icons.location_pin,
                color: severityColor,
                size: pinSize,
              ),
            ),
          ),
        );
      }

      setState(() {
        _markers = markers;
        _isLoading = false;
        _hasLoadedOnce = true;
        _lastCity = widget.selectedCity;
        _lastTimeRange = widget.selectedTimeRange;
        _lastDisease = _selectedDisease;
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
              'Location: $city, $province\nCases: $count\nSeverity: ${_getSeverityLabel(count)}',
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
    if (count >= 5) return 'Severe';
    if (count >= 3) return 'Moderate';
    return 'Mild';
  }

  Color _severityColor(int count) {
    if (count >= 5) return Colors.red;
    if (count >= 3) return Colors.orange;
    return Colors.green;
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
                        _buildLegendItem(Colors.green, 'Mild'),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.orange, 'Moderate'),
                        const SizedBox(width: 16),
                        _buildLegendItem(Colors.red, 'Severe'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pin color = Severity • Pin size = Cases',
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
                            _lastDisease = value;
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
