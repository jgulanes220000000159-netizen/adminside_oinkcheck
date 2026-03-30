import 'date_range_picker.dart';
import 'package:flutter/material.dart';
// import '../models/user_store.dart';
import '../services/scan_requests_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../screens/admin_dashboard.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Resolve a possibly non-HTTP image reference (e.g., Firebase Storage path)
// to a downloadable URL. Accepts strings, maps with common url keys, or other.
Future<String> resolveStorageImageUrl(dynamic imageData) async {
  String candidate = '';
  String storagePath = '';
  if (imageData is String) {
    candidate = imageData.trim();
  } else if (imageData is Map<String, dynamic>) {
    // Prefer a direct Firebase Storage path when available
    final dynamic sp = imageData['storagePath'] ?? imageData['path'];
    if (sp is String && sp.trim().isNotEmpty) {
      storagePath = sp.trim();
    }
    final dynamic url =
        imageData['url'] ??
        imageData['imageUrl'] ??
        imageData['image'] ??
        imageData['src'] ??
        imageData['link'] ??
        imageData['downloadURL'] ??
        imageData['storageURL'] ??
        '';
    candidate = url.toString().trim();
  } else if (imageData != null) {
    candidate = imageData.toString().trim();
  }

  // Remove accidental line breaks/spaces that corrupt URLs
  candidate = candidate.replaceAll('\n', '').replaceAll('\r', '').trim();
  if (candidate.isEmpty && storagePath.isEmpty) return '';
  final bool isHttp =
      candidate.startsWith('http://') || candidate.startsWith('https://');
  if (isHttp) {
    // Use the URL as-is. Both .appspot.com and .firebasestorage.app are valid
    // bucket domains depending on when the project was created.
    return candidate;
  }

  try {
    if (candidate.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(candidate);
      return await ref.getDownloadURL();
    }
    // Treat as relative path inside default bucket (prefer storagePath if present)
    final String pathToUse = storagePath.isNotEmpty ? storagePath : candidate;
    final ref = FirebaseStorage.instance.ref(pathToUse);
    return await ref.getDownloadURL();
  } catch (_) {
    // Fallback to original; Image.network will likely fail but UI handles errorBuilder
    return candidate.isNotEmpty ? candidate : storagePath;
  }
}

// Shared disease-to-color mapping used across modals and cards
// Matches the color scheme from reports.dart
Color diseaseColor(String disease) {
  // Normalize common separators and whitespace
  final normalized =
      disease
          .toLowerCase()
          .replaceAll(RegExp(r'[_\-]+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  // Handle display names and model labels
  switch (normalized) {
    // Healthy — Blue (#1E88E5)
    case 'healthy':
      return const Color(0xFF1E88E5);

    // Bacterial Erysipelas — Red (#E53935)
    // Model label: infected_bacterial_erysipelas
    case 'bacterial erysipelas':
    case 'infected bacterial erysipelas':
      return const Color(0xFFE53935);

    // Greasy Pig Disease — Orange (#FB8C00)
    // Model label: infected_bacterial_greasy
    case 'greasy pig disease':
    case 'infected bacterial greasy':
    case 'bacterial greasy':
      return const Color(0xFFFB8C00);

    // Sunburn — Yellow (#FDD835)
    // Model label: infected_environmental_sunburn
    case 'sunburn':
    case 'infected environmental sunburn':
    case 'environmental sunburn':
      return const Color(0xFFFDD835);

    // Ringworm — Purple (#8E24AA)
    // Model label: infected_fungal_ringworm
    case 'ringworm':
    case 'infected fungal ringworm':
    case 'fungal ringworm':
      return const Color(0xFF8E24AA);

    // Mange — Brown (#6D4C41)
    // Model label: infected_parasitic_mange
    case 'mange':
    case 'infected parasitic mange':
    case 'parasitic mange':
      return const Color(0xFF6D4C41);

    // Foot-and-Mouth Disease — Pink (#D81B60)
    // Model label: infected_viral_foot_and_mouth
    case 'foot and mouth disease':
    case 'foot-and-mouth disease':
    case 'infected viral foot and mouth':
    case 'infected viral foot and mouth disease':
      return const Color(0xFFD81B60);

    // Swine Pox — Green (#43A047)
    // Model label: swine_pox
    case 'swine pox':
    case 'swinepox':
      return const Color(0xFF43A047);

    // Unknown — Grey (fallback)
    case 'unknown':
    case 'tip burn':
    case 'tip_burn':
    default:
      return Colors.grey;
  }
}

class TotalUsersCard extends StatefulWidget {
  final VoidCallback? onOpenUserManagement;
  const TotalUsersCard({Key? key, this.onOpenUserManagement}) : super(key: key);

  @override
  State<TotalUsersCard> createState() => _TotalUsersCardState();
}

class TotalReportsReviewedCard extends StatefulWidget {
  final int totalReports;
  final List<Map<String, dynamic>> reportsTrend;
  final VoidCallback? onTap;

  const TotalReportsReviewedCard({
    Key? key,
    required this.totalReports,
    required this.reportsTrend,
    this.onTap,
  }) : super(key: key);

  @override
  State<TotalReportsReviewedCard> createState() =>
      _TotalReportsReviewedCardState();
}

class _TotalReportsReviewedCardState extends State<TotalReportsReviewedCard> {
  int _completedReports = 0;
  int _pendingReports = 0;
  bool _isLoading = true;
  bool _showBoundingBoxes =
      false; // Toggle for bounding boxes visibility (default disabled)
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);

  String _fixDiseaseName(String disease) {
    // Normalize separators and case for robust comparisons
    final String raw = (disease).toString();
    final String normalized =
        raw.replaceAll(RegExp(r'[_\-]+'), ' ').trim().toLowerCase();

    // Map to display names matching the legend (all lowercase except Healthy)
    switch (normalized) {
      case 'healthy':
        return 'Healthy';

      case 'swine pox':
      case 'swinepox':
        return 'swine pox';

      case 'ringworm':
      case 'infected fungal ringworm':
      case 'fungal ringworm':
        return 'ringworm';

      case 'foot and mouth disease':
      case 'foot-and-mouth disease':
      case 'infected viral foot and mouth':
      case 'infected viral foot and mouth disease':
        return 'foot and mouth disease';

      case 'mange':
      case 'infected parasitic mange':
      case 'parasitic mange':
        return 'mange';

      case 'sunburn':
      case 'infected environmental sunburn':
      case 'environmental sunburn':
        return 'sunburn';

      case 'greasy pig disease':
      case 'infected bacterial greasy':
      case 'bacterial greasy':
        return 'greasy pig disease';

      case 'bacterial erysipelas':
      case 'infected bacterial erysipelas':
        return 'bacterial erysipelas';

      // Fix common spelling issues
      case 'backterial b':
      case 'backterial blackspot':
      case 'bacterial b':
        return 'bacterial erysipelas';

      // Map all tip burn variants to Unknown
      case 'tip burn':
      case 'tipburn':
      case 'unknown':
        return 'Unknown';

      default:
        return raw;
    }
  }

  Color _colorForDisease(String disease) {
    return diseaseColor(_fixDiseaseName(disease));
  }

  // Reuse existing color mapping to ensure consistency
  Color _getColorForDisease(String disease) {
    return diseaseColor(_fixDiseaseName(disease));
  }

  List<Widget> _buildRecommendationsList(dynamic recommendations) {
    if (recommendations == null) return [];

    if (recommendations is List) {
      return recommendations.map<Widget>((rec) {
        if (rec is Map<String, dynamic>) {
          final treatment = rec['treatment'] ?? '';
          final dosage = rec['dosage'] ?? '';
          final frequency = rec['frequency'] ?? '';
          final duration = rec['duration'] ?? '';

          String displayText = '';
          if (treatment.isNotEmpty) displayText += 'Treatment: $treatment';
          if (dosage.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Dosage: $dosage';
          if (frequency.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Frequency: $frequency';
          if (duration.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Duration: $duration';

          if (displayText.isEmpty) displayText = 'No details available';

          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '• $displayText',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '• ${rec.toString()}',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          );
        }
      }).toList();
    } else {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${recommendations.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ),
      ];
    }
  }

  List<Widget> _buildPreventiveMeasuresList(dynamic preventiveMeasures) {
    if (preventiveMeasures == null) return [];

    if (preventiveMeasures is List) {
      return preventiveMeasures.map<Widget>((measure) {
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${measure.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        );
      }).toList();
    } else {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${preventiveMeasures.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ),
      ];
    }
  }

  Widget _buildExpertReviewWidget(dynamic expertReview) {
    try {
      if (expertReview == null) {
        return const Text(
          'No expert review available.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        );
      }

      // Debug: Print the actual data structure
      print('Expert review data type: ${expertReview.runtimeType}');
      print('Expert review data: $expertReview');

      // If it's already a Map (most likely case)
      if (expertReview is Map<String, dynamic>) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expertReview['expertName'] != null) ...[
              Text(
                'Expert: ${expertReview['expertName']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (expertReview['comment'] != null &&
                expertReview['comment'].toString().isNotEmpty) ...[
              Text(
                'Comment: ${expertReview['comment']}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
              const SizedBox(height: 4),
            ],
            if (expertReview['severityAssessment'] != null) ...[
              Builder(
                builder: (context) {
                  final severity = expertReview['severityAssessment'];
                  if (severity is Map<String, dynamic> &&
                      severity['level'] != null) {
                    return Text(
                      'Severity: ${severity['level']}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  } else if (severity is String) {
                    return Text(
                      'Severity: $severity',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 4),
            ],
            if (expertReview['treatmentPlan'] != null) ...[
              Builder(
                builder: (context) {
                  final treatmentPlan = expertReview['treatmentPlan'];
                  if (treatmentPlan is Map<String, dynamic>) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (treatmentPlan['recommendations'] != null) ...[
                          Text(
                            'Recommendations:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ..._buildRecommendationsList(
                            treatmentPlan['recommendations'],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (treatmentPlan['preventiveMeasures'] != null) ...[
                          Text(
                            'Preventive Measures:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ..._buildPreventiveMeasuresList(
                            treatmentPlan['preventiveMeasures'],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    );
                  } else {
                    return Text(
                      'Treatment Plan: $treatmentPlan',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  }
                },
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      }

      // Try to parse as JSON string
      if (expertReview is String) {
        try {
          // Remove any extra formatting and parse
          final cleanString = expertReview.replaceAll(RegExp(r'[{}]'), '');
          final parts = cleanString.split(',');

          Map<String, String> reviewData = {};
          for (String part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length >= 2) {
              final key = keyValue[0].trim();
              final value = keyValue.sublist(1).join(':').trim();
              reviewData[key] = value;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reviewData['expertName'] != null) ...[
                Text(
                  'Expert: ${reviewData['expertName']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (reviewData['comment'] != null &&
                  reviewData['comment']!.isNotEmpty) ...[
                Text(
                  'Comment: ${reviewData['comment']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
              if (reviewData['severityAssessment'] != null) ...[
                Text(
                  'Severity: ${reviewData['severityAssessment']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
              if (reviewData['treatmentPlan'] != null) ...[
                Text(
                  'Treatment Plan: ${reviewData['treatmentPlan']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
            ],
          );
        } catch (e) {
          // If parsing fails, show as plain text
          return Text(
            expertReview,
            style: TextStyle(fontSize: 14, color: Colors.green[700]),
          );
        }
      }

      return Text(
        expertReview.toString(),
        style: TextStyle(fontSize: 14, color: Colors.green[700]),
      );
    } catch (e) {
      return Text(
        'Error parsing expert review: $e',
        style: TextStyle(fontSize: 14, color: Colors.red[600]),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get actual counts from the service
      final completedCount =
          await ScanRequestsService.getCompletedReportsCount();
      final pendingCount = await ScanRequestsService.getPendingReportsCount();

      if (!mounted) return;
      setState(() {
        _completedReports = completedCount;
        _pendingReports = pendingCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  String _normalizeCityKey(String value) {
    final normalized =
        value
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    final collapsed =
        normalized
            .replaceAll(RegExp(r'\bcity of\b'), ' ')
            .replaceAll(RegExp(r'\bmunicipality of\b'), ' ')
            .replaceAll(RegExp(r'\bcity\b'), ' ')
            .replaceAll(RegExp(r'\bmunicipality\b'), ' ')
            .replaceAll(RegExp(r'\bof\b'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    switch (collapsed) {
      case 'samal':
        return 'island garden samal';
      default:
        return collapsed;
    }
  }

  String _userCountLabel(int count) =>
      '$count ${count == 1 ? 'user' : 'users'}';

  List<Map<String, dynamic>> _buildCityCounts(
    QuerySnapshot usersSnapshot,
    List<String> knownCities,
  ) {
    final normalizedKnownCities = knownCities.map(_normalizeCityKey).toList();
    final Map<String, String> labelByKey = {
      for (final city in knownCities) _normalizeCityKey(city): city,
    };
    final Map<String, int> countByKey = {
      for (final city in knownCities) _normalizeCityKey(city): 0,
    };

    for (final doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final city = (data['cityMunicipality'] ?? '').toString().trim();
      if (city.isEmpty) {
        continue;
      }

      final key = _normalizeCityKey(city);
      labelByKey.putIfAbsent(key, () => city);
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }

    final extraKeys =
        labelByKey.keys
            .where((key) => !normalizedKnownCities.contains(key))
            .toList()
          ..sort(
            (a, b) => (labelByKey[a] ?? '').toLowerCase().compareTo(
              (labelByKey[b] ?? '').toLowerCase(),
            ),
          );

    final orderedKeys = [...normalizedKnownCities, ...extraKeys];

    return orderedKeys.map((key) {
      return {
        'city': labelByKey[key] ?? 'Unknown City',
        'count': countByKey[key] ?? 0,
      };
    }).toList();
  }

  int _countUsersByRole(QuerySnapshot usersSnapshot, Set<String> roles) {
    return usersSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      return roles.contains(role);
    }).length;
  }

  int _countUsersWithoutCity(QuerySnapshot usersSnapshot) {
    return usersSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final city = (data['cityMunicipality'] ?? '').toString().trim();
      return city.isEmpty;
    }).length;
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _toTitleCaseWords(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }

          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String _displayNameFromUserData(Map<String, dynamic> data) {
    final fullName = (data['fullName'] ?? data['name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) {
      return _toTitleCaseWords(fullName);
    }

    final email = (data['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      return email;
    }

    return 'Unnamed User';
  }

  String _formatRoleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return 'Farmer';
      case 'expert':
        return 'Expert';
      case 'head_veterinarian':
        return 'Head Veterinarian';
      case 'machine_learning_expert':
        return 'Machine Learning Expert';
      case 'admin':
        return 'Admin';
      default:
        return _toTitleCaseWords(role.replaceAll('_', ' '));
    }
  }

  Color _roleAccentColor(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return const Color(0xFF2D7204);
      case 'expert':
        return const Color(0xFF7C3AED);
      case 'head_veterinarian':
        return const Color(0xFFDC2626);
      case 'machine_learning_expert':
        return const Color(0xFF0F766E);
      case 'admin':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF475569);
    }
  }

  int _roleSortRank(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return 0;
      case 'expert':
        return 1;
      case 'head_veterinarian':
        return 2;
      case 'machine_learning_expert':
        return 3;
      case 'admin':
        return 4;
      default:
        return 5;
    }
  }

  List<Map<String, dynamic>> _buildUsersForCity(
    QuerySnapshot usersSnapshot,
    String city,
  ) {
    final cityKey = _normalizeCityKey(city);

    final cityUsers =
        usersSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final userCity =
                  (data['cityMunicipality'] ?? '').toString().trim();
              if (_normalizeCityKey(userCity) != cityKey) {
                return null;
              }

              final role =
                  (data['role'] ?? 'user').toString().trim().toLowerCase();

              return {
                'id': doc.id,
                'name': _displayNameFromUserData(data),
                'role': role,
                'barangay': _toTitleCaseWords(
                  (data['barangay'] ?? '').toString(),
                ),
                'email': (data['email'] ?? '').toString().trim(),
                'phone': (data['phoneNumber'] ?? '').toString().trim(),
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

    cityUsers.sort((a, b) {
      final roleCompare = _roleSortRank(
        (a['role'] ?? '').toString(),
      ).compareTo(_roleSortRank((b['role'] ?? '').toString()));
      if (roleCompare != 0) {
        return roleCompare;
      }

      return (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      );
    });

    return cityUsers;
  }

  Widget _buildUserMetaPill({
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityUserRow(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final roleLabel = _formatRoleLabel(role);
    final accentColor = _roleAccentColor(role);
    final barangay = (user['barangay'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    final phone = (user['phone'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (user['name'] ?? 'Unnamed User').toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (barangay.isNotEmpty)
                      _buildUserMetaPill(
                        icon: Icons.place,
                        label: barangay,
                        accentColor: const Color(0xFF0369A1),
                      ),
                    if (phone.isNotEmpty)
                      _buildUserMetaPill(
                        icon: Icons.phone,
                        label: phone,
                        accentColor: const Color(0xFF475569),
                      ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 14,
                        color: Colors.blueGrey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCityUsersModal(
    BuildContext context,
    QuerySnapshot usersSnapshot,
    String city,
  ) {
    final cityUsers = _buildUsersForCity(usersSnapshot, city);
    final size = MediaQuery.of(context).size;
    final farmerCount =
        cityUsers.where((user) => user['role'] == 'farmer').length;
    final expertCount =
        cityUsers.where((user) => user['role'] == 'expert').length;
    final headVetCount =
        cityUsers.where((user) => user['role'] == 'head_veterinarian').length;
    final mlExpertCount =
        cityUsers
            .where((user) => user['role'] == 'machine_learning_expert')
            .length;
    final adminCount =
        cityUsers.where((user) => user['role'] == 'admin').length;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 860,
              maxHeight: size.height * 0.82,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.place,
                          size: 30,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              city,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Users assigned to this municipality/city.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD6E4D4)),
                        ),
                        child: Text(
                          _userCountLabel(cityUsers.length),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D7204),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    child:
                        cityUsers.isEmpty
                            ? Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.group_off,
                                        color: Color(0xFF1D4ED8),
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No users assigned yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'There are currently no accounts linked to $city.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _buildUserMetaPill(
                                      icon: Icons.people,
                                      label: _userCountLabel(cityUsers.length),
                                      accentColor: const Color(0xFF1D4ED8),
                                    ),
                                    if (farmerCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.person,
                                        label:
                                            '$farmerCount ${farmerCount == 1 ? 'farmer' : 'farmers'}',
                                        accentColor: const Color(0xFF2D7204),
                                      ),
                                    if (expertCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.verified_user,
                                        label:
                                            '$expertCount ${expertCount == 1 ? 'expert' : 'experts'}',
                                        accentColor: const Color(0xFF7C3AED),
                                      ),
                                    if (headVetCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.favorite,
                                        label:
                                            '$headVetCount ${headVetCount == 1 ? 'head vet' : 'head vets'}',
                                        accentColor: const Color(0xFFDC2626),
                                      ),
                                    if (mlExpertCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.settings,
                                        label:
                                            '$mlExpertCount ${mlExpertCount == 1 ? 'ML expert' : 'ML experts'}',
                                        accentColor: const Color(0xFF0F766E),
                                      ),
                                    if (adminCount > 0)
                                      _buildUserMetaPill(
                                        icon:
                                            Icons.admin_panel_settings,
                                        label:
                                            '$adminCount ${adminCount == 1 ? 'admin' : 'admins'}',
                                        accentColor: const Color(0xFFB45309),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: cityUsers.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      return _buildCityUserRow(
                                        cityUsers[index],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total in $city: ${_userCountLabel(cityUsers.length)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityCountTile(
    BuildContext context,
    QuerySnapshot usersSnapshot,
    Map<String, dynamic> item,
  ) {
    final city = (item['city'] ?? 'Unknown City').toString();
    final count = (item['count'] as num?)?.toInt() ?? 0;
    final hasUsers = count > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCityUsersModal(context, usersSnapshot, city),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasUsers ? Colors.white : const Color(0xFFFCFDFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    hasUsers
                        ? const Color(0xFFD6E4D4)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        hasUsers
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.place,
                    color:
                        hasUsers
                            ? const Color(0xFF2D7204)
                            : const Color(0xFF1D4ED8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Municipality/City',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 54),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        hasUsers
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _userCountLabel(count),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color:
                          hasUsers
                              ? const Color(0xFF2D7204)
                              : Colors.blueGrey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersByCityWarning(int usersWithoutCity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$usersWithoutCity ${usersWithoutCity == 1 ? 'account has' : 'accounts have'} no city assigned yet, so ${usersWithoutCity == 1 ? 'it is' : 'they are'} excluded from the city breakdown.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _cityDistributionColumnCount(double maxWidth) {
    if (maxWidth >= 1100) {
      return 3;
    }
    if (maxWidth >= 760) {
      return 2;
    }
    return 1;
  }

  void _showUsersByCityModal(
    BuildContext context,
    QuerySnapshot usersSnapshot,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        const bool showDistributionOnly = false;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 920,
              maxHeight: size.height * 0.78,
            ),
            child: FutureBuilder<List<String>>(
              future: ScanRequestsService.getDavaoDelNorteCityNames(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 920,
                    height: 420,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final knownCities = snapshot.data ?? const <String>[];
                final cityCounts = _buildCityCounts(usersSnapshot, knownCities);
                final totalAccounts = usersSnapshot.docs.length;
                final farmerCount = _countUsersByRole(usersSnapshot, {
                  'farmer',
                });
                final expertCount = _countUsersByRole(usersSnapshot, {
                  'expert',
                });
                final headVetCount = _countUsersByRole(usersSnapshot, {
                  'head_veterinarian',
                });
                final mlExpertCount = _countUsersByRole(usersSnapshot, {
                  'machine_learning_expert',
                });
                final activeCities =
                    cityCounts.where((item) {
                      return ((item['count'] as num?)?.toInt() ?? 0) > 0;
                    }).length;
                final usersWithoutCity = _countUsersWithoutCity(usersSnapshot);

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.people,
                              size: 30,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Users by City',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Live dashboard view of registered accounts grouped by municipality/city.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blueGrey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFD6E4D4),
                              ),
                            ),
                            child: Text(
                              _userCountLabel(totalAccounts),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2D7204),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blueGrey,
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!showDistributionOnly) ...[
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final summaryItems = [
                                    _buildSummaryMetric(
                                      label: 'Total Accounts',
                                      value: _userCountLabel(totalAccounts),
                                      icon: Icons.people,
                                      accentColor: const Color(0xFF1D4ED8),
                                    ),
                                    _buildSummaryMetric(
                                      label: 'Farmer Accounts',
                                      value: _userCountLabel(farmerCount),
                                      icon: Icons.person,
                                      accentColor: const Color(0xFF2D7204),
                                    ),
                                    _buildSummaryMetric(
                                      label: 'Expert Accounts',
                                      value: _userCountLabel(expertCount),
                                      icon: Icons.verified_user,
                                      accentColor: const Color(0xFF7C3AED),
                                    ),
                                    _buildSummaryMetric(
                                      label: 'Head Veterinarian',
                                      value: _userCountLabel(headVetCount),
                                      icon: Icons.favorite,
                                      accentColor: const Color(0xFFDC2626),
                                    ),
                                    _buildSummaryMetric(
                                      label: 'Machine Learning Experts',
                                      value: _userCountLabel(mlExpertCount),
                                      icon: Icons.settings,
                                      accentColor: const Color(0xFF0F766E),
                                    ),
                                    _buildSummaryMetric(
                                      label: 'Cities with Users',
                                      value:
                                          '$activeCities ${activeCities == 1 ? 'city' : 'cities'}',
                                      icon: Icons.location_city,
                                      accentColor: const Color(0xFF0369A1),
                                    ),
                                  ];

                                  final crossAxisCount =
                                      constraints.maxWidth >= 760 ? 3 : 1;
                                  final spacing = 12.0;
                                  final itemWidth =
                                      (constraints.maxWidth -
                                          ((crossAxisCount - 1) * spacing)) /
                                      crossAxisCount;

                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    children:
                                        summaryItems
                                            .map(
                                              (item) => SizedBox(
                                                width: itemWidth,
                                                child: item,
                                              ),
                                            )
                                            .toList(),
                                  );
                                },
                              ),
                              if (usersWithoutCity > 0) ...[
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '$usersWithoutCity ${usersWithoutCity == 1 ? 'account has' : 'accounts have'} no city assigned yet, so ${usersWithoutCity == 1 ? 'it is' : 'they are'} excluded from the city breakdown.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_rounded,
                                      size: 18,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Focused city view enabled. The modal is now showing only the city distribution section for better visibility.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueGrey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (usersWithoutCity > 0) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '$usersWithoutCity ${usersWithoutCity == 1 ? 'account has' : 'accounts have'} no city assigned yet, so ${usersWithoutCity == 1 ? 'it is' : 'they are'} excluded from the city breakdown.',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                            Row(
                              children: [
                                Text(
                                  showDistributionOnly
                                      ? 'City Distribution Only'
                                      : 'City Distribution',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey.shade700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Counts include all account types assigned to a city',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    int crossAxisCount = 1;
                                    if (constraints.maxWidth >= 960) {
                                      crossAxisCount = 2;
                                    } else if (constraints.maxWidth >= 760 &&
                                        !showDistributionOnly) {
                                      crossAxisCount = 2;
                                    }

                                    return GridView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.only(right: 4),
                                      itemCount: cityCounts.length,
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio:
                                                showDistributionOnly
                                                    ? 3.0
                                                    : 3.4,
                                          ),
                                      itemBuilder: (context, index) {
                                        return _buildCityCountTile(
                                          context,
                                          usersSnapshot,
                                          cityCounts[index],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 12,
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Total accounts: ${_userCountLabel(totalAccounts)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.onTap != null;
    final ScanRequestsSnapshot? scanRequestsProvider =
        Provider.of<ScanRequestsSnapshot?>(context);
    final QuerySnapshot? scanRequestsSnapshot = scanRequestsProvider?.snapshot;
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      cursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHovered,
        builder: (context, isHovered, child) {
          return Card(
            elevation: isHovered && isClickable ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: widget.onTap ?? () => _showReportsModal(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: child, // Use the child below
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.assignment_turned_in,
                size: 18,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            // Number (real-time count)
            Builder(
              builder: (context) {
                if (scanRequestsSnapshot == null) {
                  return const CircularProgressIndicator();
                }
                final docs = scanRequestsSnapshot.docs;
                final completedReports =
                    docs.where((doc) => doc['status'] == 'completed').length;
                final pendingReports =
                    docs.where((doc) => doc['status'] == 'pending').length;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$completedReports',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Total Reports Reviewed',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$completedReports Completed',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$pendingReports Pending Review',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: ReportsModalContent(),
          ),
        );
      },
    );
  }

  Widget _buildCompletedReportsTab(bool showBoundingBoxes) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getCompletedReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Text(
              'No completed reports found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _buildReportCard(report, true, showBoundingBoxes);
          },
        );
      },
    );
  }

  Widget _buildPendingReportsTab(bool showBoundingBoxes) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getPendingReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Text(
              'No pending reports found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return _buildReportCard(report, false, showBoundingBoxes);
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getCompletedReports() async {
    try {
      final allReports = await ScanRequestsService.getScanRequests();
      final completedReports =
          allReports
              .where((report) => report['status'] == 'completed')
              .toList();

      // Sort by createdAt date in descending order (most recent first)
      completedReports.sort((a, b) {
        final aDate = _parseDate(a['createdAt']);
        final bDate = _parseDate(b['createdAt']);
        return bDate.compareTo(aDate); // Descending order
      });

      return completedReports;
    } catch (e) {
      print('Error getting completed reports: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingReports() async {
    try {
      final allReports = await ScanRequestsService.getScanRequests();
      final pendingReports =
          allReports.where((report) => report['status'] == 'pending').toList();

      // Sort by createdAt date in descending order (most recent first)
      pendingReports.sort((a, b) {
        final aDate = _parseDate(a['createdAt']);
        final bDate = _parseDate(b['createdAt']);
        return bDate.compareTo(aDate); // Descending order
      });

      return pendingReports;
    } catch (e) {
      print('Error getting pending reports: $e');
      return [];
    }
  }

  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      return DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  Widget _buildReportCard(
    Map<String, dynamic> report,
    bool isCompleted,
    bool showBoundingBoxes,
  ) {
    final userName = report['userName'] ?? 'Unknown User';
    final createdAt = report['createdAt'];
    final reviewedAt = report['reviewedAt'];
    final images = report['images'] ?? [];
    // Get both ML detection and expert validation for comparison
    final mlDiseaseSummary = report['diseaseSummary'] ?? [];
    final expertDiseaseSummary = report['expertDiseaseSummary'];
    // Use expert-validated if available, otherwise use ML detection
    final diseaseSummary = expertDiseaseSummary ?? mlDiseaseSummary;
    final expertReview = report['expertReview'];
    final hasExpertValidation =
        expertDiseaseSummary != null &&
        expertDiseaseSummary is List &&
        (expertDiseaseSummary as List).isNotEmpty;

    // Helper function to normalize disease lists for comparison
    bool areDiseaseListsEqual(List<dynamic> list1, List<dynamic> list2) {
      if (list1.length != list2.length) return false;
      final normalized1 =
          list1.map((d) {
            if (d is Map)
              return (d['label'] ?? d['name'] ?? d['disease'] ?? '')
                  .toString()
                  .toLowerCase();
            return d.toString().toLowerCase();
          }).toSet();
      final normalized2 =
          list2.map((d) {
            if (d is Map)
              return (d['label'] ?? d['name'] ?? d['disease'] ?? '')
                  .toString()
                  .toLowerCase();
            return d.toString().toLowerCase();
          }).toSet();
      return normalized1.length == normalized2.length &&
          normalized1.every((item) => normalized2.contains(item));
    }

    // Check if expert made actual changes (not just copied ML detection)
    final mlList =
        mlDiseaseSummary is List ? (mlDiseaseSummary as List) : <dynamic>[];
    final expertList =
        expertDiseaseSummary is List
            ? (expertDiseaseSummary as List)
            : <dynamic>[];
    final expertMadeChanges =
        hasExpertValidation && !areDiseaseListsEqual(mlList, expertList);

    String _monthShort(int m) =>
        const [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ][m - 1];

    String _formatMdyWithTime(DateTime dt) {
      final mm = _monthShort(dt.month);
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$mm ${dt.day} ${dt.year} $hh:$min';
    }

    String _humanizeDuration(Duration d) {
      int totalMinutes = d.inMinutes.abs();
      final days = totalMinutes ~/ (24 * 60);
      totalMinutes %= (24 * 60);
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      final parts = <String>[];
      if (days > 0) parts.add('$days day${days == 1 ? '' : 's'}');
      if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
      if (minutes > 0 || parts.isEmpty) {
        parts.add('$minutes min${minutes == 1 ? '' : 's'}');
      }
      return parts.join(' ');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        () {
                          final dt = _parseDate(createdAt);
                          return 'Submitted: ${_formatMdyWithTime(dt)}';
                        }(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (isCompleted && reviewedAt != null) ...[
                        Text(
                          () {
                            final dt = _parseDate(reviewedAt);
                            return 'Reviewed: ${_formatMdyWithTime(dt)}';
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          () {
                            final submitted = _parseDate(createdAt);
                            final reviewed = _parseDate(reviewedAt);
                            return 'Turnaround: ${_humanizeDuration(reviewed.difference(submitted))}';
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // no delete action in summary card; delete lives in modal
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Images with bounding boxes
            if (images.isNotEmpty) ...[
              const Text(
                'Images:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, imageIndex) {
                    final imageData = images[imageIndex];
                    String imageUrl = '';

                    // Debug: Print the image data structure
                    print('Image data at index $imageIndex: $imageData');
                    print('Image data type: ${imageData.runtimeType}');

                    // Handle different image data structures
                    if (imageData is String) {
                      imageUrl = imageData;
                      print('Using string URL: $imageUrl');
                    } else if (imageData is Map<String, dynamic>) {
                      // Try different possible field names for the URL
                      imageUrl =
                          imageData['url'] ??
                          imageData['imageUrl'] ??
                          imageData['image'] ??
                          imageData['src'] ??
                          imageData['link'] ??
                          imageData['downloadURL'] ??
                          imageData['storageURL'] ??
                          imageData.toString();
                      print('Using map URL: $imageUrl');
                    } else {
                      imageUrl = imageData.toString();
                      print('Using toString URL: $imageUrl');
                    }

                    // Clean up the URL - remove line breaks and extra spaces
                    imageUrl =
                        imageUrl
                            .replaceAll('\n', '')
                            .replaceAll('\r', '')
                            .trim();
                    print('Cleaned URL: $imageUrl');

                    return GestureDetector(
                      onTap:
                          () => showImageCarouselModal(
                            context,
                            images,
                            imageIndex,
                            showBoundingBoxes,
                          ),
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Image
                              FutureBuilder<String>(
                                future: resolveStorageImageUrl(imageData),
                                builder: (context, snapshot) {
                                  final resolvedUrl = snapshot.data ?? imageUrl;
                                  if (!snapshot.hasData &&
                                      !(resolvedUrl.startsWith('http://') ||
                                          resolvedUrl.startsWith('https://'))) {
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  try {
                                    return Image.network(
                                      resolvedUrl,
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print(
                                          'Image error for URL: $resolvedUrl',
                                        );
                                        print('Error: $error');
                                        return Container(
                                          width: 200,
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Image Error',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    print('Exception loading image: $e');
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.red[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 50,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Image Error',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Bounding boxes overlay (if available)
                              if (showBoundingBoxes &&
                                  imageData is Map<String, dynamic>) ...[
                                ..._buildBoundingBoxes(imageData),
                              ],
                              // Click indicator overlay
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ML Detected Diseases (always show if available, for comparison)
            if (mlDiseaseSummary is List &&
                (mlDiseaseSummary as List).isNotEmpty) ...[
              const Text(
                'ML Detected Diseases:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (mlDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Expert Summary (this is what the farmer sees) - always show if expert validated
            if (hasExpertValidation) ...[
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      expertMadeChanges
                          ? 'Expert Summary (Farmer Sees This):'
                          : 'Expert Summary (No Changes - Same as ML):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: expertMadeChanges ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (expertDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ] else if (mlDiseaseSummary is List &&
                (mlDiseaseSummary as List).isNotEmpty &&
                !hasExpertValidation) ...[
              // Show ML detected diseases if no expert validation yet
              const Text(
                'ML Detected Diseases:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (mlDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Expert Review (for completed reports)
            if (isCompleted && expertReview != null) ...[
              const Text(
                'Expert Review:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: _buildExpertReviewWidget(expertReview),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';

    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        dateTime = date.toDate();
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showImageModal(
    BuildContext context,
    String imageUrl,
    dynamic imageData,
    bool showBoundingBoxes,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // Create local state for the image modal
            bool imageModalShowBoundingBoxes = showBoundingBoxes;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Image View',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Bounding Box Toggle for large image
                              Row(
                                children: [
                                  const Text(
                                    'Bounding Boxes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: imageModalShowBoundingBoxes,
                                    onChanged: (value) {
                                      setModalState(() {
                                        imageModalShowBoundingBoxes = value;
                                      });
                                    },
                                    activeColor: Colors.blue,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Image content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Large image
                              Builder(
                                builder: (context) {
                                  try {
                                    return Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 100,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Image Error',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.red[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 100,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Image Error',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Bounding boxes overlay for large image
                              if (imageModalShowBoundingBoxes &&
                                  imageData is Map<String, dynamic>)
                                ..._buildLargeBoundingBoxes(imageData),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showImageCarouselModal(
    BuildContext context,
    List<dynamic> images,
    int initialIndex,
    bool showBoundingBoxes,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int currentIndex = initialIndex;
        bool showBoxes = showBoundingBoxes;
        final PageController pageController = PageController(
          initialPage: initialIndex,
        );
        print(
          '[Carousel] open: initialIndex=' +
              initialIndex.toString() +
              ', total=' +
              images.length.toString() +
              ', showBoxes=' +
              showBoundingBoxes.toString(),
        );
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            String _extractImageUrl(dynamic imageData) {
              if (imageData is String) {
                return imageData.trim();
              }
              if (imageData is Map<String, dynamic>) {
                final url =
                    imageData['url'] ??
                    imageData['imageUrl'] ??
                    imageData['image'] ??
                    imageData['src'] ??
                    imageData['link'] ??
                    imageData['downloadURL'] ??
                    imageData['storageURL'] ??
                    '';
                final cleaned =
                    url
                        .toString()
                        .replaceAll('\n', '')
                        .replaceAll('\r', '')
                        .trim();
                print('[Carousel] resolved URL from map: ' + cleaned);
                return cleaned;
              }
              final other = imageData.toString().trim();
              print('[Carousel] resolved URL from other: ' + other);
              return other;
            }

            void goPrev() {
              if (currentIndex > 0) {
                print('[Carousel] goPrev from ' + currentIndex.toString());
                pageController.previousPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              }
            }

            void goNext() {
              if (currentIndex < images.length - 1) {
                print('[Carousel] goNext from ' + currentIndex.toString());
                pageController.nextPage(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous',
                                onPressed: currentIndex > 0 ? goPrev : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                'Image ${currentIndex + 1} of ${images.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next',
                                onPressed:
                                    currentIndex < images.length - 1
                                        ? goNext
                                        : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Bounding Box Toggle for large image (modal state)
                              Row(
                                children: [
                                  const Text(
                                    'Bounding Boxes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: showBoxes,
                                    onChanged: (v) {
                                      print(
                                        '[Carousel] toggle boxes -> ' +
                                            v.toString(),
                                      );
                                      setModalState(() {
                                        showBoxes = v;
                                      });
                                    },
                                    activeColor: Colors.blue,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Image content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              PageView.builder(
                                controller: pageController,
                                itemCount: images.length,
                                onPageChanged: (idx) {
                                  setModalState(() {
                                    currentIndex = idx;
                                  });
                                  print(
                                    '[Carousel] onPageChanged -> ' +
                                        idx.toString(),
                                  );
                                },
                                itemBuilder: (context, idx) {
                                  final dynamic pageImageData = images[idx];
                                  final String pageUrl = _extractImageUrl(
                                    pageImageData,
                                  );
                                  print(
                                    '[Carousel] build page idx=' +
                                        idx.toString(),
                                  );
                                  return Stack(
                                    children: [
                                      FutureBuilder<String>(
                                        future: resolveStorageImageUrl(
                                          pageImageData,
                                        ),
                                        builder: (context, snapshot) {
                                          final url = snapshot.data ?? pageUrl;
                                          if (!snapshot.hasData &&
                                              !(url.startsWith('http://') ||
                                                  url.startsWith('https://'))) {
                                            return Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            );
                                          }
                                          try {
                                            return Image.network(
                                              url,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.contain,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return Container(
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  color: Colors.grey[300],
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .image_not_supported,
                                                        size: 100,
                                                        color: Colors.grey,
                                                      ),
                                                      const SizedBox(
                                                        height: 16,
                                                      ),
                                                      Text(
                                                        'Image Error',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          } catch (e) {
                                            return Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              color: Colors.red[100],
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.error,
                                                    size: 100,
                                                    color: Colors.red,
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Image Error',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.red[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      if (showBoxes &&
                                          pageImageData is Map<String, dynamic>)
                                        ..._buildLargeBoundingBoxes(
                                          pageImageData,
                                        ),
                                      // Left/right overlay tap zones
                                      Positioned.fill(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap:
                                                    currentIndex > 0
                                                        ? () {
                                                          print(
                                                            '[Carousel] left overlay tap',
                                                          );
                                                          goPrev();
                                                        }
                                                        : null,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.chevron_left,
                                                      size: 36,
                                                      color:
                                                          currentIndex > 0
                                                              ? Colors.black54
                                                              : Colors
                                                                  .transparent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap:
                                                    currentIndex <
                                                            images.length - 1
                                                        ? () {
                                                          print(
                                                            '[Carousel] right overlay tap',
                                                          );
                                                          goNext();
                                                        }
                                                        : null,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerRight,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Icon(
                                                      Icons.chevron_right,
                                                      size: 36,
                                                      color:
                                                          currentIndex <
                                                                  images.length -
                                                                      1
                                                              ? Colors.black54
                                                              : Colors
                                                                  .transparent,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildLargeBoundingBoxes(Map<String, dynamic> imageData) {
    final results = imageData['results'] as List<dynamic>? ?? [];

    // Get actual image dimensions from the data
    final imageWidth =
        (imageData['imageWidth'] as double?) ??
        (imageData['imageWidth'] as int?)?.toDouble() ??
        4064.0;
    final imageHeight =
        (imageData['imageHeight'] as double?) ??
        (imageData['imageHeight'] as int?)?.toDouble() ??
        3048.0;

    return results.map<Widget>((result) {
      final boundingBox = result['boundingBox'] as Map<String, dynamic>?;
      if (boundingBox == null) {
        return const SizedBox.shrink();
      }

      // Get original coordinates
      final originalLeft =
          (boundingBox['left'] as double?) ??
          (boundingBox['left'] as int?)?.toDouble() ??
          0.0;
      final originalTop =
          (boundingBox['top'] as double?) ??
          (boundingBox['top'] as int?)?.toDouble() ??
          0.0;
      final originalRight =
          (boundingBox['right'] as double?) ??
          (boundingBox['right'] as int?)?.toDouble() ??
          0.0;
      final originalBottom =
          (boundingBox['bottom'] as double?) ??
          (boundingBox['bottom'] as int?)?.toDouble() ??
          0.0;

      final disease = _fixDiseaseName(
        result['disease'] as String? ?? 'Unknown',
      );
      final confidence = result['confidence'] as double? ?? 0.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          // For BoxFit.cover, we need to calculate the actual displayed image size
          // and its position within the container
          final containerWidth = constraints.maxWidth;
          final containerHeight = constraints.maxHeight;

          // Calculate the scale to fit the image in the container while maintaining aspect ratio
          final scaleX = containerWidth / imageWidth;
          final scaleY = containerHeight / imageHeight;
          final scale =
              scaleX < scaleY
                  ? scaleX
                  : scaleY; // Use the smaller scale for contain

          // Calculate the actual displayed image dimensions
          final displayedWidth = imageWidth * scale;
          final displayedHeight = imageHeight * scale;

          // Calculate the offset to center the image
          final offsetX = (containerWidth - displayedWidth) / 2;
          final offsetY = (containerHeight - displayedHeight) / 2;

          // Scale coordinates and apply offset
          final left = (originalLeft * scale) + offsetX;
          final top = (originalTop * scale) + offsetY;
          final right = (originalRight * scale) + offsetX;
          final bottom = (originalBottom * scale) + offsetY;

          final width = right - left;
          final height = bottom - top;

          return Stack(
            children: [
              // Large bounding box
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _colorForDisease(disease),
                      width: 4,
                    ),
                    color: _colorForDisease(disease).withOpacity(0.1),
                  ),
                ),
              ),
              // Large disease label
              Positioned(
                left: left - 10,
                top: top - 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _colorForDisease(disease).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${_fixDiseaseName(disease).substring(0, _fixDiseaseName(disease).length > 20 ? 20 : _fixDiseaseName(disease).length)}\n${(confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildBoundingBoxes(Map<String, dynamic> imageData) {
    final results = imageData['results'] as List<dynamic>? ?? [];

    // Get actual image dimensions from the data
    final imageWidth =
        (imageData['imageWidth'] as double?) ??
        (imageData['imageWidth'] as int?)?.toDouble() ??
        4064.0;
    final imageHeight =
        (imageData['imageHeight'] as double?) ??
        (imageData['imageHeight'] as int?)?.toDouble() ??
        3048.0;

    // Debug: Print image dimensions
    print('=== BOUNDING BOX DEBUG ===');
    print('Image data: $imageData');
    print('Image width: $imageWidth, height: $imageHeight');
    print('Results count: ${results.length}');

    // For BoxFit.contain, we need to calculate the actual displayed image size
    // and its position within the 200x200 container
    final containerWidth = 200.0;
    final containerHeight = 200.0;

    // Calculate the scale to fit the image in the container while maintaining aspect ratio
    final scaleX = containerWidth / imageWidth;
    final scaleY = containerHeight / imageHeight;
    final scale =
        scaleX < scaleY ? scaleX : scaleY; // Use the smaller scale for contain

    // Calculate the actual displayed image dimensions
    final displayedWidth = imageWidth * scale;
    final displayedHeight = imageHeight * scale;

    // Calculate the offset to center the image
    final offsetX = (containerWidth - displayedWidth) / 2;
    final offsetY = (containerHeight - displayedHeight) / 2;

    print('Scale factors: scaleX=$scaleX, scaleY=$scaleY, final scale=$scale');
    print('Displayed size: ${displayedWidth}x${displayedHeight}');
    print('Offset: $offsetX, $offsetY');

    return results.map<Widget>((result) {
      final boundingBox = result['boundingBox'] as Map<String, dynamic>?;
      if (boundingBox == null) {
        print('No bounding box found in result: $result');
        return const SizedBox.shrink();
      }

      // Get original coordinates
      final originalLeft =
          (boundingBox['left'] as double?) ??
          (boundingBox['left'] as int?)?.toDouble() ??
          0.0;
      final originalTop =
          (boundingBox['top'] as double?) ??
          (boundingBox['top'] as int?)?.toDouble() ??
          0.0;
      final originalRight =
          (boundingBox['right'] as double?) ??
          (boundingBox['right'] as int?)?.toDouble() ??
          0.0;
      final originalBottom =
          (boundingBox['bottom'] as double?) ??
          (boundingBox['bottom'] as int?)?.toDouble() ??
          0.0;

      // Scale coordinates and apply offset
      final left = (originalLeft * scale) + offsetX;
      final top = (originalTop * scale) + offsetY;
      final right = (originalRight * scale) + offsetX;
      final bottom = (originalBottom * scale) + offsetY;

      final width = right - left;
      final height = bottom - top;

      final disease = _fixDiseaseName(
        result['disease'] as String? ?? 'Unknown',
      );
      final confidence = result['confidence'] as double? ?? 0.0;

      print(
        'Original coords: left=$originalLeft, top=$originalTop, right=$originalRight, bottom=$originalBottom',
      );
      print(
        'Scaled coords: left=$left, top=$top, width=$width, height=$height',
      );
      print('Disease: $disease, Confidence: $confidence');
      print('========================');

      return Stack(
        children: [
          // Accurate bounding box (no labels inside)
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: diseaseColor(disease), width: 3),
                color: diseaseColor(disease).withOpacity(0.1),
              ),
            ),
          ),
          // Single disease label outside the box (top-left)
          Positioned(
            left: left - 5,
            top: top - 25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: diseaseColor(disease).withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${disease.substring(0, disease.length > 15 ? 15 : disease.length)}\n${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

class ReportsModalContent extends StatefulWidget {
  final ValueNotifier<bool>? fullscreenNotifier;
  const ReportsModalContent({Key? key, this.fullscreenNotifier})
    : super(key: key);

  @override
  _ReportsModalContentState createState() => _ReportsModalContentState();
}

class _ReportsModalContentState extends State<ReportsModalContent>
    with SingleTickerProviderStateMixin {
  // Access the shared date range picker from reports
  Future<DateTimeRange?> _pickRange(
    BuildContext context,
    DateTimeRange initial,
  ) {
    return pickDateRangeWithSf(context, initial: initial);
  }

  final ValueNotifier<bool> _showBoundingBoxesNotifier = ValueNotifier(false);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDisease = 'All';
  // Expert is filtered via search only
  String _selectedExpert = 'All';
  DateTime? _fromDate;
  DateTime? _toDate;
  late Future<List<Map<String, dynamic>>> _completedReportsFuture;
  late Future<List<Map<String, dynamic>>> _pendingReportsFuture;
  late TabController _tabController;
  final ScrollController _completedScrollController = ScrollController();
  final ScrollController _pendingScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Cache futures so typing in the search field doesn't re-fetch or refresh the modal
    _completedReportsFuture = _getCompletedReports();
    _pendingReportsFuture = _getPendingReports();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _showBoundingBoxesNotifier.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _completedScrollController.dispose();
    _pendingScrollController.dispose();
    super.dispose();
  }

  String _fixDiseaseName(String disease) {
    // Normalize separators and case for robust comparisons
    final String raw = (disease).toString();
    final String normalized =
        raw.replaceAll(RegExp(r'[_\-]+'), ' ').trim().toLowerCase();

    // Map to display names matching the legend (all lowercase except Healthy)
    switch (normalized) {
      case 'healthy':
        return 'Healthy';

      case 'swine pox':
      case 'swinepox':
        return 'swine pox';

      case 'ringworm':
      case 'infected fungal ringworm':
      case 'fungal ringworm':
        return 'ringworm';

      case 'foot and mouth disease':
      case 'foot-and-mouth disease':
      case 'infected viral foot and mouth':
      case 'infected viral foot and mouth disease':
        return 'foot and mouth disease';

      case 'mange':
      case 'infected parasitic mange':
      case 'parasitic mange':
        return 'mange';

      case 'sunburn':
      case 'infected environmental sunburn':
      case 'environmental sunburn':
        return 'sunburn';

      case 'greasy pig disease':
      case 'infected bacterial greasy':
      case 'bacterial greasy':
        return 'greasy pig disease';

      case 'bacterial erysipelas':
      case 'infected bacterial erysipelas':
        return 'bacterial erysipelas';

      // Fix common spelling issues
      case 'backterial b':
      case 'backterial blackspot':
      case 'bacterial b':
        return 'bacterial erysipelas';

      // Map all tip burn variants to Unknown
      case 'tip burn':
      case 'tipburn':
      case 'unknown':
        return 'Unknown';

      default:
        return raw;
    }
  }

  List<Widget> _buildRecommendationsList(dynamic recommendations) {
    if (recommendations == null) return [];

    if (recommendations is List) {
      return recommendations.map<Widget>((rec) {
        if (rec is Map<String, dynamic>) {
          final treatment = rec['treatment'] ?? '';
          final dosage = rec['dosage'] ?? '';
          final frequency = rec['frequency'] ?? '';
          final duration = rec['duration'] ?? '';

          String displayText = '';
          if (treatment.isNotEmpty) displayText += 'Treatment: $treatment';
          if (dosage.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Dosage: $dosage';
          if (frequency.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Frequency: $frequency';
          if (duration.isNotEmpty)
            displayText +=
                '${displayText.isNotEmpty ? ', ' : ''}Duration: $duration';

          if (displayText.isEmpty) displayText = 'No details available';

          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '• $displayText',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text(
              '• ${rec.toString()}',
              style: const TextStyle(fontSize: 11, color: Colors.green),
            ),
          );
        }
      }).toList();
    } else {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${recommendations.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ),
      ];
    }
  }

  List<Widget> _buildPreventiveMeasuresList(dynamic preventiveMeasures) {
    if (preventiveMeasures == null) return [];

    if (preventiveMeasures is List) {
      return preventiveMeasures.map<Widget>((measure) {
        return Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${measure.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        );
      }).toList();
    } else {
      return [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(
            '• ${preventiveMeasures.toString()}',
            style: const TextStyle(fontSize: 11, color: Colors.green),
          ),
        ),
      ];
    }
  }

  List<String> _computeDiseaseOptions(List<Map<String, dynamic>> reports) {
    final Set<String> diseaseSet = {};
    for (final report in reports) {
      // Prefer expert-validated disease summary, fall back to ML model detection
      final List<dynamic> diseaseSummary =
          (report['expertDiseaseSummary'] as List<dynamic>?) ??
          (report['diseaseSummary'] as List<dynamic>?) ??
          const [];
      for (final dynamic disease in diseaseSummary) {
        if (disease is Map<String, dynamic>) {
          final String name = _fixDiseaseName(
            (disease['name'] ?? '').toString().trim(),
          );
          if (name.isNotEmpty) {
            diseaseSet.add(name);
          }
        }
      }
    }
    final List<String> options = ['All', ...diseaseSet.toList()..sort()];
    // Ensure currently selected option is valid
    if (!options.contains(_selectedDisease)) {
      _selectedDisease = 'All';
    }
    return options;
  }

  // Expert options dropdown removed; filter by expert through search only

  Future<void> _pickFromDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _fromDate ?? (_toDate != null ? _toDate! : now);
    DateTime? start = initial;
    DateTime? end = _toDate ?? now;
    // Reuse the unified Syncfusion range picker dialog from reports
    final result = await pickDateRangeWithSf(
      context,
      initial: DateTimeRange(start: start, end: end),
    );
    if (result != null) {
      setState(() {
        _fromDate = DateTime(
          result.start.year,
          result.start.month,
          result.start.day,
        );
        _toDate = DateTime(result.end.year, result.end.month, result.end.day);
      });
    }
  }

  Future<void> _pickToDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _toDate ?? (_fromDate != null ? _fromDate! : now);
    DateTime? start = _fromDate ?? now;
    DateTime? end = initial;
    final result = await pickDateRangeWithSf(
      context,
      initial: DateTimeRange(start: start, end: end),
    );
    if (result != null) {
      setState(() {
        _fromDate = DateTime(
          result.start.year,
          result.start.month,
          result.start.day,
        );
        _toDate = DateTime(result.end.year, result.end.month, result.end.day);
      });
    }
  }

  String _formatDateOnly(DateTime? date) {
    if (date == null) return 'Select';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> reports) {
    final String query = _searchQuery.trim().toLowerCase();
    final String selectedDiseaseLower = _selectedDisease.toLowerCase();
    final String selectedExpertLower = _selectedExpert.toLowerCase();

    final List<Map<String, dynamic>> filtered =
        reports.where((report) {
          final String userName =
              (report['userName'] ?? '').toString().toLowerCase();
          // Prefer expert-validated disease summary, fall back to ML model detection
          final List<dynamic> diseaseSummary =
              (report['expertDiseaseSummary'] as List<dynamic>?) ??
              (report['diseaseSummary'] as List<dynamic>?) ??
              const [];
          final dynamic expertReview = report['expertReview'];
          String expertName = '';
          if (expertReview is Map<String, dynamic>) {
            expertName = (expertReview['expertName'] ?? '').toString();
          } else if (expertReview is String) {
            expertName = expertReview;
          }
          final String expertNameLower = expertName.toLowerCase();
          final DateTime createdDate = _parseDate(report['createdAt']);

          bool matchesSearch = true;
          if (query.isNotEmpty) {
            final bool userMatches = userName.contains(query);
            final bool diseaseMatches = diseaseSummary.any((d) {
              if (d is Map<String, dynamic>) {
                final String name =
                    _fixDiseaseName((d['name'] ?? '').toString()).toLowerCase();
                return name.contains(query) ||
                    (name == 'unknown' && 'unknown'.contains(query));
              }
              return false;
            });
            final bool expertMatches = expertNameLower.contains(query);
            // Build flexible date variants to tolerate padded/unpadded day/month
            // and 2-digit or 4-digit years.
            final String dd = createdDate.day.toString().padLeft(2, '0');
            final String d = createdDate.day.toString();
            final String mm = createdDate.month.toString().padLeft(2, '0');
            final String m = createdDate.month.toString();
            final String y4 = createdDate.year.toString();
            final String y2 = y4.substring(2);
            final List<String> dateVariants =
                [
                  '$dd/$mm/$y4',
                  '$d/$m/$y4',
                  '$dd/$m/$y4',
                  '$d/$mm/$y4',
                  '$dd/$mm/$y2',
                  '$d/$m/$y2',
                  '$dd/$m/$y2',
                  '$d/$mm/$y2',
                ].map((s) => s.toLowerCase()).toList();
            final bool dateTextMatches = dateVariants.any(
              (s) => s.contains(query),
            );

            matchesSearch =
                userMatches ||
                diseaseMatches ||
                expertMatches ||
                dateTextMatches;
          }

          bool matchesDisease = true;
          if (_selectedDisease != 'All') {
            matchesDisease = diseaseSummary.any((d) {
              if (d is Map<String, dynamic>) {
                final String name =
                    _fixDiseaseName((d['name'] ?? '').toString()).toLowerCase();
                return name == selectedDiseaseLower;
              }
              return false;
            });
          }

          bool matchesExpert = true;
          if (_selectedExpert != 'All') {
            matchesExpert = expertNameLower == selectedExpertLower;
          }

          bool matchesDate = true;
          if (_fromDate != null) {
            final DateTime from = DateTime(
              _fromDate!.year,
              _fromDate!.month,
              _fromDate!.day,
            );
            if (createdDate.isBefore(from)) matchesDate = false;
          }
          if (matchesDate && _toDate != null) {
            final DateTime to = DateTime(
              _toDate!.year,
              _toDate!.month,
              _toDate!.day,
              23,
              59,
              59,
              999,
            );
            if (createdDate.isAfter(to)) matchesDate = false;
          }

          return matchesSearch &&
              matchesDisease &&
              matchesExpert &&
              matchesDate;
        }).toList();

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reports Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                // Bounding Box Toggle
                Row(
                  children: [
                    const Text(
                      'Bounding Boxes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _showBoundingBoxesNotifier,
                      builder:
                          (context, value, _) => Switch(
                            value: value,
                            onChanged: (val) {
                              _showBoundingBoxesNotifier.value = val;
                            },
                            activeColor: Colors.blue,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                if (widget.fullscreenNotifier != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.fullscreenNotifier!,
                    builder:
                        (context, isFull, _) => IconButton(
                          tooltip: isFull ? 'Exit Fullscreen' : 'Fullscreen',
                          icon: Icon(
                            isFull ? Icons.fullscreen_exit : Icons.fullscreen,
                          ),
                          onPressed:
                              () => widget.fullscreenNotifier!.value = !isFull,
                        ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Tab Bar
        Expanded(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black87,
                  labelPadding: EdgeInsets.zero,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: EdgeInsets.zero,
                  indicator: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  tabs: const [
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        child: Text('Completed Reports'),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        child: Text('Pending Reports'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tab Content
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _showBoundingBoxesNotifier,
                  builder:
                      (context, value, _) => TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCompletedReportsTab(value),
                          _buildPendingReportsTab(value),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedReportsTab(bool showBoundingBoxes) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _completedReportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Text(
              'No completed reports found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final List<String> diseaseOptions = _computeDiseaseOptions(reports);
        final List<Map<String, dynamic>> filteredReports = _applyFilters(
          reports,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by user, disease, expert, or date (dd/mm/yyyy)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedDisease,
                  items:
                      diseaseOptions
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d,
                              child: Text(d),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) =>
                          setState(() => _selectedDisease = value ?? 'All'),
                ),
                // Expert can be filtered via search; no extra dropdown
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _fromDate != null && _toDate != null
                        ? '${_formatDateOnly(_fromDate)} to ${_formatDateOnly(_toDate)}'
                        : 'Pick date range',
                  ),
                ),
                const SizedBox(width: 8),
                if (_fromDate != null || _toDate != null)
                  TextButton(
                    onPressed:
                        () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                    child: const Text('Clear dates'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _completedScrollController,
                itemCount: filteredReports.length,
                itemBuilder: (context, index) {
                  final report = filteredReports[index];
                  return _buildReportCard(report, true, showBoundingBoxes);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingReportsTab(bool showBoundingBoxes) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _pendingReportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return const Center(
            child: Text(
              'No pending reports found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final List<String> diseaseOptions = _computeDiseaseOptions(reports);
        final List<Map<String, dynamic>> filteredReports = _applyFilters(
          reports,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Search by user, disease, expert, or date (dd/mm/yyyy)...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedDisease,
                  items:
                      diseaseOptions
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d,
                              child: Text(d),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (value) =>
                          setState(() => _selectedDisease = value ?? 'All'),
                ),
                // Expert can be filtered via search; no extra dropdown
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFromDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _fromDate != null && _toDate != null
                        ? '${_formatDateOnly(_fromDate)} to ${_formatDateOnly(_toDate)}'
                        : 'Pick date range',
                  ),
                ),
                const SizedBox(width: 8),
                if (_fromDate != null || _toDate != null)
                  TextButton(
                    onPressed:
                        () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                        }),
                    child: const Text('Clear dates'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _pendingScrollController,
                itemCount: filteredReports.length,
                itemBuilder: (context, index) {
                  final report = filteredReports[index];
                  return _buildReportCard(report, false, showBoundingBoxes);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getCompletedReports() async {
    try {
      final allReports = await ScanRequestsService.getScanRequests();
      final completedReports =
          allReports
              .where((report) => report['status'] == 'completed')
              .toList();

      // Sort by createdAt date in descending order (most recent first)
      completedReports.sort((a, b) {
        final aDate = _parseDate(a['createdAt']);
        final bDate = _parseDate(b['createdAt']);
        return bDate.compareTo(aDate); // Descending order
      });

      return completedReports;
    } catch (e) {
      print('Error getting completed reports: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingReports() async {
    try {
      final allReports = await ScanRequestsService.getScanRequests();
      final pendingReports =
          allReports.where((report) => report['status'] == 'pending').toList();

      // Sort by createdAt date in descending order (most recent first)
      pendingReports.sort((a, b) {
        final aDate = _parseDate(a['createdAt']);
        final bDate = _parseDate(b['createdAt']);
        return bDate.compareTo(aDate); // Descending order
      });

      return pendingReports;
    } catch (e) {
      print('Error getting pending reports: $e');
      return [];
    }
  }

  DateTime _parseDate(dynamic date) {
    if (date is Timestamp) {
      return date.toDate();
    } else if (date is String) {
      return DateTime.tryParse(date) ?? DateTime.now();
    } else {
      return DateTime.now();
    }
  }

  Widget _buildReportCard(
    Map<String, dynamic> report,
    bool isCompleted,
    bool showBoundingBoxes,
  ) {
    final userName = report['userName'] ?? 'Unknown User';
    final createdAt = report['createdAt'];
    final reviewedAt = report['reviewedAt'];
    final images = report['images'] ?? [];
    // Get both ML detection and expert validation for comparison
    final mlDiseaseSummary = report['diseaseSummary'] ?? [];
    final expertDiseaseSummary = report['expertDiseaseSummary'];
    // Use expert-validated if available, otherwise use ML detection
    final diseaseSummary = expertDiseaseSummary ?? mlDiseaseSummary;
    final expertReview = report['expertReview'];
    final hasExpertValidation =
        expertDiseaseSummary != null &&
        expertDiseaseSummary is List &&
        (expertDiseaseSummary as List).isNotEmpty;

    // Helper function to normalize disease lists for comparison
    bool areDiseaseListsEqual(List<dynamic> list1, List<dynamic> list2) {
      if (list1.length != list2.length) return false;
      final normalized1 =
          list1.map((d) {
            if (d is Map)
              return (d['label'] ?? d['name'] ?? d['disease'] ?? '')
                  .toString()
                  .toLowerCase();
            return d.toString().toLowerCase();
          }).toSet();
      final normalized2 =
          list2.map((d) {
            if (d is Map)
              return (d['label'] ?? d['name'] ?? d['disease'] ?? '')
                  .toString()
                  .toLowerCase();
            return d.toString().toLowerCase();
          }).toSet();
      return normalized1.length == normalized2.length &&
          normalized1.every((item) => normalized2.contains(item));
    }

    // Check if expert made actual changes (not just copied ML detection)
    final mlList =
        mlDiseaseSummary is List ? (mlDiseaseSummary as List) : <dynamic>[];
    final expertList =
        expertDiseaseSummary is List
            ? (expertDiseaseSummary as List)
            : <dynamic>[];
    final expertMadeChanges =
        hasExpertValidation && !areDiseaseListsEqual(mlList, expertList);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        () {
                          final dt = _parseDate(createdAt);
                          String month(int m) =>
                              const [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ][m - 1];
                          final hh = dt.hour.toString().padLeft(2, '0');
                          final mm = dt.minute.toString().padLeft(2, '0');
                          return 'Submitted: ${month(dt.month)} ${dt.day} ${dt.year} $hh:$mm';
                        }(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (isCompleted && reviewedAt != null) ...[
                        Text(
                          () {
                            final dt = _parseDate(reviewedAt);
                            String month(int m) =>
                                const [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dec',
                                ][m - 1];
                            final hh = dt.hour.toString().padLeft(2, '0');
                            final mm = dt.minute.toString().padLeft(2, '0');
                            return 'Reviewed: ${month(dt.month)} ${dt.day} ${dt.year} $hh:$mm';
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          () {
                            final submitted = _parseDate(createdAt);
                            final reviewed = _parseDate(reviewedAt);
                            Duration d = reviewed.difference(submitted);
                            int totalMinutes = d.inMinutes.abs();
                            final days = totalMinutes ~/ (24 * 60);
                            totalMinutes %= (24 * 60);
                            final hours = totalMinutes ~/ 60;
                            final minutes = totalMinutes % 60;
                            final parts = <String>[];
                            if (days > 0)
                              parts.add('$days day${days == 1 ? '' : 's'}');
                            if (hours > 0)
                              parts.add('$hours hour${hours == 1 ? '' : 's'}');
                            if (minutes > 0 || parts.isEmpty)
                              parts.add(
                                '$minutes min${minutes == 1 ? '' : 's'}',
                              );
                            return 'Turnaround: ${parts.join(' ')}';
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCompleted ? 'Completed' : 'Pending',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () async => _confirmAndDelete(report),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Images with bounding boxes
            if (images.isNotEmpty) ...[
              const Text(
                'Images:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, imageIndex) {
                    final imageData = images[imageIndex];
                    String imageUrl = '';

                    // Debug: Print the image data structure
                    print('Image data at index $imageIndex: $imageData');
                    print('Image data type: ${imageData.runtimeType}');

                    // Handle different image data structures
                    if (imageData is String) {
                      imageUrl = imageData;
                      print('Using string URL: $imageUrl');
                    } else if (imageData is Map<String, dynamic>) {
                      // Try different possible field names for the URL
                      imageUrl =
                          imageData['url'] ??
                          imageData['imageUrl'] ??
                          imageData['image'] ??
                          imageData['src'] ??
                          imageData['link'] ??
                          imageData['downloadURL'] ??
                          imageData['storageURL'] ??
                          imageData.toString();
                      print('Using map URL: $imageUrl');
                    } else {
                      imageUrl = imageData.toString();
                      print('Using toString URL: $imageUrl');
                    }

                    // Clean up the URL - remove line breaks and extra spaces
                    imageUrl =
                        imageUrl
                            .replaceAll('\n', '')
                            .replaceAll('\r', '')
                            .trim();
                    print('Cleaned URL: $imageUrl');

                    return GestureDetector(
                      onTap:
                          () => showImageCarouselModal(
                            context,
                            images,
                            imageIndex,
                            showBoundingBoxes,
                          ),
                      child: Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Image
                              Builder(
                                builder: (context) {
                                  try {
                                    return Image.network(
                                      imageUrl,
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print('Image error for URL: $imageUrl');
                                        print('Error: $error');
                                        return Container(
                                          width: 200,
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Image Error',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    print('Exception loading image: $e');
                                    return Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.red[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 50,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Image Error',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Bounding boxes overlay (if available)
                              if (showBoundingBoxes &&
                                  imageData is Map<String, dynamic>) ...[
                                ..._buildBoundingBoxes(imageData),
                              ],
                              // Click indicator overlay
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ML Detected Diseases (always show if available, for comparison)
            if (mlDiseaseSummary is List &&
                (mlDiseaseSummary as List).isNotEmpty) ...[
              const Text(
                'ML Detected Diseases:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (mlDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Expert Summary (this is what the farmer sees) - always show if expert validated
            if (hasExpertValidation) ...[
              Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      expertMadeChanges
                          ? 'Expert Summary (Farmer Sees This):'
                          : 'Expert Summary (No Changes - Same as ML):',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: expertMadeChanges ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (expertDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ] else if (mlDiseaseSummary is List &&
                (mlDiseaseSummary as List).isNotEmpty &&
                !hasExpertValidation) ...[
              // Show ML detected diseases if no expert validation yet
              const Text(
                'ML Detected Diseases:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (mlDiseaseSummary as List).map<Widget>((disease) {
                      final diseaseName = _fixDiseaseName(
                        (disease is Map
                                ? (disease['name'] ??
                                    disease['label'] ??
                                    'Unknown')
                                : disease.toString())
                            .toString(),
                      );
                      final count =
                          disease is Map ? (disease['count'] ?? 0) : 0;
                      final confidence =
                          disease is Map ? disease['confidence'] : null;

                      String displayText;
                      if (confidence != null) {
                        displayText =
                            '$diseaseName (${(confidence * 100).toStringAsFixed(1)}%)';
                      } else {
                        displayText =
                            '$diseaseName (${count} detection${count != 1 ? 's' : ''})';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Expert Review (for completed reports)
            if (isCompleted && expertReview != null) ...[
              const Text(
                'Expert Review:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: _buildExpertReviewWidget(expertReview),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> report) async {
    final String reportId = (report['id'] ?? '').toString();
    if (reportId.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ScanRequestsService.deleteScanRequest(reportId);
    if (!mounted) return;

    if (success) {
      // Refresh both tabs' data
      setState(() {
        _completedReportsFuture = _getCompletedReports();
        _pendingReportsFuture = _getPendingReports();
      });

      // Log admin activity for deletion
      try {
        final String status = (report['status'] ?? '').toString().toLowerCase();
        final String userName = (report['userName'] ?? 'User').toString();
        String expertName = '';
        final dynamic expertReview = report['expertReview'];
        if (expertReview is Map<String, dynamic>) {
          expertName = (expertReview['expertName'] ?? '').toString();
        } else if (expertReview is String) {
          expertName = expertReview;
        }

        String actionText;
        if (status == 'completed') {
          actionText =
              expertName.isNotEmpty
                  ? 'Deleted completed report for $userName (expert: $expertName)'
                  : 'Deleted completed report for $userName';
        } else {
          actionText = 'Deleted pending report for $userName';
        }

        await FirebaseFirestore.instance.collection('activities').add({
          'action': actionText,
          'user': 'Admin',
          'type': 'delete',
          'color': Colors.red.value,
          'icon': Icons.delete.codePoint,
          'iconKey': 'delete',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Ignore logging errors; do not block UX
        // print('Failed to log delete activity: $e');
      }

      // Show professional success dialog
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Report Deleted'),
            content: const Text('The report has been successfully deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // Show professional error dialog
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Failed'),
            content: const Text(
              'We could not delete the report. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';

    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else {
        dateTime = date.toDate();
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildExpertReviewWidget(dynamic expertReview) {
    try {
      if (expertReview == null) {
        return const Text(
          'No expert review available.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        );
      }

      // Debug: Print the actual data structure
      print('Expert review data type: ${expertReview.runtimeType}');
      print('Expert review data: $expertReview');

      // If it's already a Map (most likely case)
      if (expertReview is Map<String, dynamic>) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expertReview['expertName'] != null) ...[
              Text(
                'Expert: ${expertReview['expertName']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (expertReview['comment'] != null &&
                expertReview['comment'].toString().isNotEmpty) ...[
              Text(
                'Comment: ${expertReview['comment']}',
                style: const TextStyle(fontSize: 12, color: Colors.green),
              ),
              const SizedBox(height: 4),
            ],
            if (expertReview['severityAssessment'] != null) ...[
              Builder(
                builder: (context) {
                  final severity = expertReview['severityAssessment'];
                  if (severity is Map<String, dynamic> &&
                      severity['level'] != null) {
                    return Text(
                      'Severity: ${severity['level']}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  } else if (severity is String) {
                    return Text(
                      'Severity: $severity',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 4),
            ],
            if (expertReview['treatmentPlan'] != null) ...[
              Builder(
                builder: (context) {
                  final treatmentPlan = expertReview['treatmentPlan'];
                  if (treatmentPlan is Map<String, dynamic>) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (treatmentPlan['recommendations'] != null) ...[
                          Text(
                            'Recommendations:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ..._buildRecommendationsList(
                            treatmentPlan['recommendations'],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (treatmentPlan['preventiveMeasures'] != null) ...[
                          Text(
                            'Preventive Measures:',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ..._buildPreventiveMeasuresList(
                            treatmentPlan['preventiveMeasures'],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ],
                    );
                  } else {
                    return Text(
                      'Treatment Plan: $treatmentPlan',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    );
                  }
                },
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      }

      // Try to parse as JSON string
      if (expertReview is String) {
        try {
          // Remove any extra formatting and parse
          final cleanString = expertReview.replaceAll(RegExp(r'[{}]'), '');
          final parts = cleanString.split(',');

          Map<String, String> reviewData = {};
          for (String part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length >= 2) {
              final key = keyValue[0].trim();
              final value = keyValue.sublist(1).join(':').trim();
              reviewData[key] = value;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (reviewData['expertName'] != null) ...[
                Text(
                  'Expert: ${reviewData['expertName']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (reviewData['comment'] != null &&
                  reviewData['comment']!.isNotEmpty) ...[
                Text(
                  'Comment: ${reviewData['comment']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
              if (reviewData['severityAssessment'] != null) ...[
                Text(
                  'Severity: ${reviewData['severityAssessment']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
              if (reviewData['treatmentPlan'] != null) ...[
                Text(
                  'Treatment Plan: ${reviewData['treatmentPlan']}',
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
                const SizedBox(height: 4),
              ],
            ],
          );
        } catch (e) {
          // If parsing fails, show as plain text
          return Text(
            expertReview,
            style: TextStyle(fontSize: 14, color: Colors.green[700]),
          );
        }
      }

      return Text(
        expertReview.toString(),
        style: TextStyle(fontSize: 14, color: Colors.green[700]),
      );
    } catch (e) {
      return Text(
        'Error parsing expert review: $e',
        style: TextStyle(fontSize: 14, color: Colors.red[600]),
      );
    }
  }

  void _showEnlargedImageModal(
    BuildContext context,
    String imageUrl,
    dynamic imageData,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Image View',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Bounding Box Toggle for large image
                              Row(
                                children: [
                                  const Text(
                                    'Bounding Boxes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: _showBoundingBoxesNotifier,
                                    builder:
                                        (context, value, _) => Switch(
                                          value: value,
                                          onChanged: (val) {
                                            _showBoundingBoxesNotifier.value =
                                                val;
                                          },
                                          activeColor: Colors.blue,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Image content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Large image
                              Builder(
                                builder: (context) {
                                  try {
                                    return Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 100,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Image Error',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.red[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 100,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Image Error',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Bounding boxes overlay for large image
                              ValueListenableBuilder<bool>(
                                valueListenable: _showBoundingBoxesNotifier,
                                builder: (context, value, _) {
                                  if (value &&
                                      imageData is Map<String, dynamic>) {
                                    return Stack(
                                      children: _buildLargeBoundingBoxes(
                                        imageData,
                                      ),
                                    );
                                  } else {
                                    return const SizedBox.shrink();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showImageCarouselModal(
    BuildContext context,
    List<dynamic> images,
    int initialIndex,
    bool showBoundingBoxes,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int currentIndex = initialIndex;

        String _extractImageUrl(dynamic imageData) {
          if (imageData is String) {
            return imageData.trim();
          }
          if (imageData is Map<String, dynamic>) {
            final url =
                imageData['url'] ??
                imageData['imageUrl'] ??
                imageData['image'] ??
                imageData['src'] ??
                imageData['link'] ??
                imageData['downloadURL'] ??
                imageData['storageURL'] ??
                '';
            return url
                .toString()
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .trim();
          }
          return imageData.toString().trim();
        }

        void goPrev() {
          if (currentIndex > 0) {
            final int target = currentIndex - 1;
            setState(() {
              currentIndex = target;
            });
          }
        }

        void goNext() {
          if (currentIndex < images.length - 1) {
            final int target = currentIndex + 1;
            setState(() {
              currentIndex = target;
            });
          }
        }

        final dynamic currentImageData = images[currentIndex];
        final String imageUrl = _extractImageUrl(currentImageData);

        bool imageModalShowBoundingBoxes = showBoundingBoxes;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                final dynamic currentImageData = images[currentIndex];
                final String imageUrl = _extractImageUrl(currentImageData);
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Previous',
                                onPressed:
                                    currentIndex > 0
                                        ? () => setModalState(() {
                                          goPrev();
                                        })
                                        : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                'Image ${currentIndex + 1} of ${images.length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next',
                                onPressed:
                                    currentIndex < images.length - 1
                                        ? () => setModalState(() {
                                          goNext();
                                        })
                                        : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Bounding Box Toggle for large image
                              Row(
                                children: [
                                  const Text(
                                    'Bounding Boxes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: imageModalShowBoundingBoxes,
                                    onChanged: (value) {
                                      setModalState(() {
                                        imageModalShowBoundingBoxes = value;
                                      });
                                    },
                                    activeColor: Colors.blue,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Image content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              // Large image
                              Builder(
                                builder: (context) {
                                  try {
                                    return Image.network(
                                      imageUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          color: Colors.grey[300],
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.image_not_supported,
                                                size: 100,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Image Error',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  } catch (e) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      color: Colors.red[100],
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            size: 100,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Image Error',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                              // Bounding boxes overlay for large image
                              if (imageModalShowBoundingBoxes &&
                                  currentImageData is Map<String, dynamic>)
                                ..._buildLargeBoundingBoxes(currentImageData),
                              // Left/right overlay tap zones
                              Positioned.fill(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            currentIndex > 0
                                                ? () {
                                                  print(
                                                    '[Carousel] left overlay tap',
                                                  );
                                                  setModalState(() {
                                                    goPrev();
                                                  });
                                                }
                                                : null,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.chevron_left,
                                              size: 36,
                                              color:
                                                  currentIndex > 0
                                                      ? Colors.black54
                                                      : Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap:
                                            currentIndex < images.length - 1
                                                ? () {
                                                  print(
                                                    '[Carousel] right overlay tap',
                                                  );
                                                  setModalState(() {
                                                    goNext();
                                                  });
                                                }
                                                : null,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.chevron_right,
                                              size: 36,
                                              color:
                                                  currentIndex <
                                                          images.length - 1
                                                      ? Colors.black54
                                                      : Colors.transparent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildLargeBoundingBoxes(Map<String, dynamic> imageData) {
    final results = imageData['results'] as List<dynamic>? ?? [];

    // Get actual image dimensions from the data
    final imageWidth =
        (imageData['imageWidth'] as double?) ??
        (imageData['imageWidth'] as int?)?.toDouble() ??
        4064.0;
    final imageHeight =
        (imageData['imageHeight'] as double?) ??
        (imageData['imageHeight'] as int?)?.toDouble() ??
        3048.0;

    return results.map<Widget>((result) {
      final boundingBox = result['boundingBox'] as Map<String, dynamic>?;
      if (boundingBox == null) {
        return const SizedBox.shrink();
      }

      // Get original coordinates
      final originalLeft =
          (boundingBox['left'] as double?) ??
          (boundingBox['left'] as int?)?.toDouble() ??
          0.0;
      final originalTop =
          (boundingBox['top'] as double?) ??
          (boundingBox['top'] as int?)?.toDouble() ??
          0.0;
      final originalRight =
          (boundingBox['right'] as double?) ??
          (boundingBox['right'] as int?)?.toDouble() ??
          0.0;
      final originalBottom =
          (boundingBox['bottom'] as double?) ??
          (boundingBox['bottom'] as int?)?.toDouble() ??
          0.0;

      final disease = _fixDiseaseName(
        result['disease'] as String? ?? 'Unknown',
      );
      final confidence = result['confidence'] as double? ?? 0.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          // For BoxFit.cover, we need to calculate the actual displayed image size
          // and its position within the container
          final containerWidth = constraints.maxWidth;
          final containerHeight = constraints.maxHeight;

          // Calculate the scale to fit the image in the container while maintaining aspect ratio
          final scaleX = containerWidth / imageWidth;
          final scaleY = containerHeight / imageHeight;
          final scale =
              scaleX < scaleY
                  ? scaleX
                  : scaleY; // Use the smaller scale for contain

          // Calculate the actual displayed image dimensions
          final displayedWidth = imageWidth * scale;
          final displayedHeight = imageHeight * scale;

          // Calculate the offset to center the image
          final offsetX = (containerWidth - displayedWidth) / 2;
          final offsetY = (containerHeight - displayedHeight) / 2;

          // Scale coordinates and apply offset
          final left = (originalLeft * scale) + offsetX;
          final top = (originalTop * scale) + offsetY;
          final right = (originalRight * scale) + offsetX;
          final bottom = (originalBottom * scale) + offsetY;

          final width = right - left;
          final height = bottom - top;

          return Stack(
            children: [
              // Large bounding box
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    border: Border.all(color: diseaseColor(disease), width: 4),
                    color: diseaseColor(disease).withOpacity(0.1),
                  ),
                ),
              ),
              // Large disease label
              Positioned(
                left: left - 10,
                top: top - 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: diseaseColor(disease).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${_fixDiseaseName(disease).substring(0, _fixDiseaseName(disease).length > 20 ? 20 : _fixDiseaseName(disease).length)}\n${(confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildBoundingBoxes(Map<String, dynamic> imageData) {
    final results = imageData['results'] as List<dynamic>? ?? [];

    // Get actual image dimensions from the data
    final imageWidth =
        (imageData['imageWidth'] as double?) ??
        (imageData['imageWidth'] as int?)?.toDouble() ??
        4064.0;
    final imageHeight =
        (imageData['imageHeight'] as double?) ??
        (imageData['imageHeight'] as int?)?.toDouble() ??
        3048.0;

    // Debug: Print image dimensions
    print('=== BOUNDING BOX DEBUG ===');
    print('Image data: $imageData');
    print('Image width: $imageWidth, height: $imageHeight');
    print('Results count: ${results.length}');

    // For BoxFit.contain, we need to calculate the actual displayed image size
    // and its position within the 200x200 container
    final containerWidth = 200.0;
    final containerHeight = 200.0;

    // Calculate the scale to fit the image in the container while maintaining aspect ratio
    final scaleX = containerWidth / imageWidth;
    final scaleY = containerHeight / imageHeight;
    final scale =
        scaleX < scaleY ? scaleX : scaleY; // Use the smaller scale for contain

    // Calculate the actual displayed image dimensions
    final displayedWidth = imageWidth * scale;
    final displayedHeight = imageHeight * scale;

    // Calculate the offset to center the image
    final offsetX = (containerWidth - displayedWidth) / 2;
    final offsetY = (containerHeight - displayedHeight) / 2;

    print('Scale factors: scaleX=$scaleX, scaleY=$scaleY, final scale=$scale');
    print('Displayed size: ${displayedWidth}x${displayedHeight}');
    print('Offset: $offsetX, $offsetY');

    return results.map<Widget>((result) {
      final boundingBox = result['boundingBox'] as Map<String, dynamic>?;
      if (boundingBox == null) {
        print('No bounding box found in result: $result');
        return const SizedBox.shrink();
      }

      // Get original coordinates
      final originalLeft =
          (boundingBox['left'] as double?) ??
          (boundingBox['left'] as int?)?.toDouble() ??
          0.0;
      final originalTop =
          (boundingBox['top'] as double?) ??
          (boundingBox['top'] as int?)?.toDouble() ??
          0.0;
      final originalRight =
          (boundingBox['right'] as double?) ??
          (boundingBox['right'] as int?)?.toDouble() ??
          0.0;
      final originalBottom =
          (boundingBox['bottom'] as double?) ??
          (boundingBox['bottom'] as int?)?.toDouble() ??
          0.0;

      // Scale coordinates and apply offset
      final left = (originalLeft * scale) + offsetX;
      final top = (originalTop * scale) + offsetY;
      final right = (originalRight * scale) + offsetX;
      final bottom = (originalBottom * scale) + offsetY;

      final width = right - left;
      final height = bottom - top;

      final disease = _fixDiseaseName(
        result['disease'] as String? ?? 'Unknown',
      );
      final confidence = result['confidence'] as double? ?? 0.0;

      print(
        'Original coords: left=$originalLeft, top=$originalTop, right=$originalRight, bottom=$originalBottom',
      );
      print(
        'Scaled coords: left=$left, top=$top, width=$width, height=$height',
      );
      print('Disease: $disease, Confidence: $confidence');
      print('========================');

      return Stack(
        children: [
          // Accurate bounding box (no labels inside)
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                border: Border.all(color: diseaseColor(disease), width: 3),
                color: diseaseColor(disease).withOpacity(0.1),
              ),
            ),
          ),
          // Single disease label outside the box (top-left)
          Positioned(
            left: left - 5,
            top: top - 25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: diseaseColor(disease).withOpacity(0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                '${disease.substring(0, disease.length > 15 ? 15 : disease.length)}\n${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

class _TotalUsersCardState extends State<TotalUsersCard> {
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);
  late final Future<List<String>> _cityNamesFuture;

  @override
  void initState() {
    super.initState();
    _cityNamesFuture = ScanRequestsService.getDavaoDelNorteCityNames();
  }

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  String _normalizeCityKey(String value) {
    final normalized =
        value
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    final collapsed =
        normalized
            .replaceAll(RegExp(r'\bcity of\b'), ' ')
            .replaceAll(RegExp(r'\bmunicipality of\b'), ' ')
            .replaceAll(RegExp(r'\bcity\b'), ' ')
            .replaceAll(RegExp(r'\bmunicipality\b'), ' ')
            .replaceAll(RegExp(r'\bof\b'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    switch (collapsed) {
      case 'samal':
        return 'island garden samal';
      default:
        return collapsed;
    }
  }

  String _userCountLabel(int count) =>
      '$count ${count == 1 ? 'user' : 'users'}';

  Widget _buildUsersByCityWarning(int usersWithoutCity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$usersWithoutCity ${usersWithoutCity == 1 ? 'account has' : 'accounts have'} no city assigned yet, so ${usersWithoutCity == 1 ? 'it is' : 'they are'} excluded from the city breakdown.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildCityCounts(
    QuerySnapshot usersSnapshot,
    List<String> knownCities,
  ) {
    final normalizedKnownCities = knownCities.map(_normalizeCityKey).toList();
    final Map<String, String> labelByKey = {
      for (final city in knownCities) _normalizeCityKey(city): city,
    };
    final Map<String, int> countByKey = {
      for (final city in knownCities) _normalizeCityKey(city): 0,
    };

    for (final doc in usersSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final city = (data['cityMunicipality'] ?? '').toString().trim();
      if (city.isEmpty) {
        continue;
      }

      final key = _normalizeCityKey(city);
      labelByKey.putIfAbsent(key, () => city);
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }

    final extraKeys =
        labelByKey.keys
            .where((key) => !normalizedKnownCities.contains(key))
            .toList()
          ..sort(
            (a, b) => (labelByKey[a] ?? '').toLowerCase().compareTo(
              (labelByKey[b] ?? '').toLowerCase(),
            ),
          );

    final orderedKeys = [...normalizedKnownCities, ...extraKeys];

    return orderedKeys.map((key) {
      return {
        'city': labelByKey[key] ?? 'Unknown City',
        'count': countByKey[key] ?? 0,
      };
    }).toList();
  }

  int _countUsersByRole(QuerySnapshot usersSnapshot, Set<String> roles) {
    return usersSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      return roles.contains(role);
    }).length;
  }

  int _countUsersWithoutCity(QuerySnapshot usersSnapshot) {
    return usersSnapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final city = (data['cityMunicipality'] ?? '').toString().trim();
      return city.isEmpty;
    }).length;
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _toTitleCaseWords(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '';
    }

    return normalized
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }

          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String _displayNameFromUserData(Map<String, dynamic> data) {
    final fullName = (data['fullName'] ?? data['name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) {
      return _toTitleCaseWords(fullName);
    }

    final email = (data['email'] ?? '').toString().trim();
    if (email.isNotEmpty) {
      return email;
    }

    return 'Unnamed User';
  }

  String _formatRoleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return 'Farmer';
      case 'expert':
        return 'Expert';
      case 'head_veterinarian':
        return 'Head Veterinarian';
      case 'machine_learning_expert':
        return 'Machine Learning Expert';
      case 'admin':
        return 'Admin';
      default:
        return _toTitleCaseWords(role.replaceAll('_', ' '));
    }
  }

  Color _roleAccentColor(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return const Color(0xFF2D7204);
      case 'expert':
        return const Color(0xFF7C3AED);
      case 'head_veterinarian':
        return const Color(0xFFDC2626);
      case 'machine_learning_expert':
        return const Color(0xFF0F766E);
      case 'admin':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF475569);
    }
  }

  int _roleSortRank(String role) {
    switch (role.trim().toLowerCase()) {
      case 'farmer':
        return 0;
      case 'expert':
        return 1;
      case 'head_veterinarian':
        return 2;
      case 'machine_learning_expert':
        return 3;
      case 'admin':
        return 4;
      default:
        return 5;
    }
  }

  List<Map<String, dynamic>> _buildUsersForCity(
    QuerySnapshot usersSnapshot,
    String city,
  ) {
    final cityKey = _normalizeCityKey(city);

    final cityUsers =
        usersSnapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final userCity =
                  (data['cityMunicipality'] ?? '').toString().trim();
              if (_normalizeCityKey(userCity) != cityKey) {
                return null;
              }

              final role =
                  (data['role'] ?? 'user').toString().trim().toLowerCase();

              return {
                'id': doc.id,
                'name': _displayNameFromUserData(data),
                'role': role,
                'barangay': _toTitleCaseWords(
                  (data['barangay'] ?? '').toString(),
                ),
                'email': (data['email'] ?? '').toString().trim(),
                'phone': (data['phoneNumber'] ?? '').toString().trim(),
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

    cityUsers.sort((a, b) {
      final roleCompare = _roleSortRank(
        (a['role'] ?? '').toString(),
      ).compareTo(_roleSortRank((b['role'] ?? '').toString()));
      if (roleCompare != 0) {
        return roleCompare;
      }

      return (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      );
    });

    return cityUsers;
  }

  Widget _buildUserMetaPill({
    required IconData icon,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityUserRow(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final roleLabel = _formatRoleLabel(role);
    final accentColor = _roleAccentColor(role);
    final barangay = (user['barangay'] ?? '').toString().trim();
    final email = (user['email'] ?? '').toString().trim();
    final phone = (user['phone'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.person,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (user['name'] ?? 'Unnamed User').toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (barangay.isNotEmpty)
                      _buildUserMetaPill(
                        icon: Icons.place,
                        label: barangay,
                        accentColor: const Color(0xFF0369A1),
                      ),
                    if (phone.isNotEmpty)
                      _buildUserMetaPill(
                        icon: Icons.phone,
                        label: phone,
                        accentColor: const Color(0xFF475569),
                      ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.email,
                        size: 14,
                        color: Colors.blueGrey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCityUsersModal(
    BuildContext context,
    QuerySnapshot usersSnapshot,
    String city,
  ) {
    final cityUsers = _buildUsersForCity(usersSnapshot, city);
    final size = MediaQuery.of(context).size;
    final farmerCount =
        cityUsers.where((user) => user['role'] == 'farmer').length;
    final expertCount =
        cityUsers.where((user) => user['role'] == 'expert').length;
    final headVetCount =
        cityUsers.where((user) => user['role'] == 'head_veterinarian').length;
    final mlExpertCount =
        cityUsers
            .where((user) => user['role'] == 'machine_learning_expert')
            .length;
    final adminCount =
        cityUsers.where((user) => user['role'] == 'admin').length;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 860,
              maxHeight: size.height * 0.82,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.place,
                          size: 30,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              city,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Users assigned to this municipality/city.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD6E4D4)),
                        ),
                        child: Text(
                          _userCountLabel(cityUsers.length),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D7204),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    child:
                        cityUsers.isEmpty
                            ? Center(
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.group_off,
                                        color: Color(0xFF1D4ED8),
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No users assigned yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'There are currently no accounts linked to $city.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _buildUserMetaPill(
                                      icon: Icons.people,
                                      label: _userCountLabel(cityUsers.length),
                                      accentColor: const Color(0xFF1D4ED8),
                                    ),
                                    if (farmerCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.person,
                                        label:
                                            '$farmerCount ${farmerCount == 1 ? 'farmer' : 'farmers'}',
                                        accentColor: const Color(0xFF2D7204),
                                      ),
                                    if (expertCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.verified_user,
                                        label:
                                            '$expertCount ${expertCount == 1 ? 'expert' : 'experts'}',
                                        accentColor: const Color(0xFF7C3AED),
                                      ),
                                    if (headVetCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.favorite,
                                        label:
                                            '$headVetCount ${headVetCount == 1 ? 'head vet' : 'head vets'}',
                                        accentColor: const Color(0xFFDC2626),
                                      ),
                                    if (mlExpertCount > 0)
                                      _buildUserMetaPill(
                                        icon: Icons.settings,
                                        label:
                                            '$mlExpertCount ${mlExpertCount == 1 ? 'ML expert' : 'ML experts'}',
                                        accentColor: const Color(0xFF0F766E),
                                      ),
                                    if (adminCount > 0)
                                      _buildUserMetaPill(
                                        icon:
                                            Icons.admin_panel_settings,
                                        label:
                                            '$adminCount ${adminCount == 1 ? 'admin' : 'admins'}',
                                        accentColor: const Color(0xFFB45309),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: cityUsers.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      return _buildCityUserRow(
                                        cityUsers[index],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total in $city: ${_userCountLabel(cityUsers.length)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCityCountTile(
    BuildContext context,
    QuerySnapshot usersSnapshot,
    Map<String, dynamic> item,
  ) {
    final city = (item['city'] ?? 'Unknown City').toString();
    final count = (item['count'] as num?)?.toInt() ?? 0;
    final hasUsers = count > 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showCityUsersModal(context, usersSnapshot, city),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: hasUsers ? Colors.white : const Color(0xFFFCFDFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    hasUsers
                        ? const Color(0xFFD6E4D4)
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        hasUsers
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.place,
                    color:
                        hasUsers
                            ? const Color(0xFF2D7204)
                            : const Color(0xFF1D4ED8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Municipality/City',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 54),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        hasUsers
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _userCountLabel(count),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color:
                          hasUsers
                              ? const Color(0xFF2D7204)
                              : Colors.blueGrey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _cityDistributionColumnCount(double maxWidth) {
    if (maxWidth >= 1120) {
      return 3;
    }
    if (maxWidth >= 780) {
      return 2;
    }
    return 1;
  }

  void _showUsersByCityModal(
    BuildContext context,
    QuerySnapshot usersSnapshot,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1240,
              maxHeight: size.height * 0.86,
            ),
            child: FutureBuilder<List<String>>(
              future: _cityNamesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    width: 1080,
                    height: 420,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final knownCities = snapshot.data ?? const <String>[];
                final cityCounts = _buildCityCounts(usersSnapshot, knownCities);
                final totalAccounts = usersSnapshot.docs.length;
                final farmerCount = _countUsersByRole(usersSnapshot, {
                  'farmer',
                });
                final expertCount = _countUsersByRole(usersSnapshot, {
                  'expert',
                });
                final headVetCount = _countUsersByRole(usersSnapshot, {
                  'head_veterinarian',
                });
                final mlExpertCount = _countUsersByRole(usersSnapshot, {
                  'machine_learning_expert',
                });
                final activeCities =
                    cityCounts.where((item) {
                      return ((item['count'] as num?)?.toInt() ?? 0) > 0;
                    }).length;
                final usersWithoutCity = _countUsersWithoutCity(usersSnapshot);

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 18, 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                          child: const Icon(
                            Icons.people,
                            size: 30,
                            color: Color(0xFF1D4ED8),
                          ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Users by City',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Live dashboard view of registered accounts grouped by municipality/city.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFFD6E4D4),
                                  ),
                                ),
                                child: Text(
                                  _userCountLabel(totalAccounts),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2D7204),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blueGrey,
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final summaryItems = [
                              _buildSummaryMetric(
                                label: 'Total Accounts',
                                value: _userCountLabel(totalAccounts),
                                icon: Icons.people,
                                accentColor: const Color(0xFF1D4ED8),
                              ),
                              _buildSummaryMetric(
                                label: 'Farmer Accounts',
                                value: _userCountLabel(farmerCount),
                                icon: Icons.person,
                                accentColor: const Color(0xFF2D7204),
                              ),
                              _buildSummaryMetric(
                                label: 'Expert Accounts',
                                value: _userCountLabel(expertCount),
                                icon: Icons.verified_user,
                                accentColor: const Color(0xFF7C3AED),
                              ),
                              _buildSummaryMetric(
                                label: 'Head Veterinarian',
                                value: _userCountLabel(headVetCount),
                                icon: Icons.favorite,
                                accentColor: const Color(0xFFDC2626),
                              ),
                              _buildSummaryMetric(
                                label: 'Machine Learning Experts',
                                value: _userCountLabel(mlExpertCount),
                                icon: Icons.settings,
                                accentColor: const Color(0xFF0F766E),
                              ),
                              _buildSummaryMetric(
                                label: 'Cities/Municipalities with Users',
                                value:
                                    '$activeCities ${activeCities == 1 ? 'city/municipality' : 'cities/municipalities'}',
                                icon: Icons.location_city,
                                accentColor: const Color(0xFF0369A1),
                              ),
                            ];

                            final summaryColumnCount =
                                constraints.maxWidth >= 1080
                                    ? 4
                                    : constraints.maxWidth >= 760
                                    ? 3
                                    : constraints.maxWidth >= 520
                                    ? 2
                                    : 1;
                            const summarySpacing = 12.0;
                            final summaryItemWidth =
                                (constraints.maxWidth -
                                    ((summaryColumnCount - 1) *
                                        summarySpacing)) /
                                summaryColumnCount;

                            final cityColumnCount =
                                _cityDistributionColumnCount(
                                  constraints.maxWidth,
                                );
                            const citySpacing = 10.0;
                            final cityTileWidth =
                                (constraints.maxWidth -
                                    ((cityColumnCount - 1) * citySpacing)) /
                                cityColumnCount;
                            final useCompactHeader = constraints.maxWidth < 700;

                            return SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: summarySpacing,
                                      runSpacing: summarySpacing,
                                      children:
                                          summaryItems
                                              .map(
                                                (item) => SizedBox(
                                                  width: summaryItemWidth,
                                                  child: item,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                    if (usersWithoutCity > 0) ...[
                                      const SizedBox(height: 14),
                                      _buildUsersByCityWarning(
                                        usersWithoutCity,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    if (useCompactHeader) ...[
                                      Text(
                                        'Municipality/City Distribution',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.blueGrey.shade700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Click a city card to view the users assigned there.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blueGrey.shade500,
                                        ),
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Text(
                                            'Municipality/City Distribution',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.blueGrey.shade700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Click a city card to view its users',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blueGrey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: citySpacing,
                                      runSpacing: citySpacing,
                                      children:
                                          cityCounts
                                              .map(
                                                (item) => SizedBox(
                                                  width: cityTileWidth,
                                                  child: _buildCityCountTile(
                                                    context,
                                                    usersSnapshot,
                                                    item,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 12,
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Total accounts: ${_userCountLabel(totalAccounts)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onOpenUserManagement != null) ...[
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onOpenUserManagement?.call();
                                  },
                                  icon: const Icon(
                                    Icons.people_outline_rounded,
                                  ),
                                  label: const Text('Open User Management'),
                                ),
                                const SizedBox(width: 10),
                              ],
                              FilledButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UsersSnapshot? usersProvider = Provider.of<UsersSnapshot?>(context);
    final QuerySnapshot? usersSnapshot = usersProvider?.snapshot;
    final isClickable = usersSnapshot != null;

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      cursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHovered,
        builder: (context, isHovered, child) {
          return Card(
            elevation: isHovered && isClickable ? 8 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap:
                  usersSnapshot == null
                      ? null
                      : () => _showUsersByCityModal(context, usersSnapshot),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: child, // Use the child below
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.people, size: 18, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            // Number (real-time count)
            Builder(
              builder: (context) {
                if (usersSnapshot == null) {
                  return const CircularProgressIndicator();
                }
                final docs = usersSnapshot.docs;
                final totalUsers = docs.length;
                // Count users by role
                final farmerCount =
                    docs.where((doc) {
                      final role = (doc['role'] ?? '').toString().toLowerCase();
                      return role == 'farmer';
                    }).length;
                final expertCount =
                    docs.where((doc) {
                      final role = (doc['role'] ?? '').toString().toLowerCase();
                      return role == 'expert' ||
                          role == 'head_veterinarian' ||
                          role == 'machine_learning_expert';
                    }).length;
                return Column(
                  children: [
                    Text(
                      '$totalUsers',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Total Users',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$farmerCount Farmers',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$expertCount Experts',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
