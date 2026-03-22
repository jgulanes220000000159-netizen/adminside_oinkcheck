import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/scan_requests_service.dart';

class RatingsReviewsModalContent extends StatefulWidget {
  const RatingsReviewsModalContent({Key? key}) : super(key: key);

  @override
  State<RatingsReviewsModalContent> createState() =>
      _RatingsReviewsModalContentState();
}

class _RatingsReviewsModalContentState extends State<RatingsReviewsModalContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedRatingFilter; // null = All, 1-5 = specific rating

  static const Set<String> _veterinarianRoles = {
    'expert',
    'head_veterinarian',
    'head veterinarian',
    'head veterenarian',
    'head_vet',
    'head vet',
    'veterinarian',
    'veterenarian',
  };

  String _normalizeRole(String? rawRole) {
    final role = (rawRole ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (role == 'head veterinarian' || role == 'head vet' || role == 'head_vet') {
      return 'head_veterinarian';
    }
    if (role == 'head veterenarian') {
      return 'head_veterinarian';
    }
    if (role == 'veterenarian') {
      return 'veterinarian';
    }
    return role;
  }

  double _calcAverageFromDocs(List<QueryDocumentSnapshot> docs) {
    double total = 0.0;
    int count = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final rating = (data['rating'] as num?)?.toDouble();
      if (rating != null && rating > 0) {
        total += rating;
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  Widget _buildAverageHeader({
    required String title,
    required double average,
    required int totalCount,
    String? breakdownText,
    Color accent = const Color(0xFF2D7204),
    IconData icon = Icons.star_rate_rounded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                if (breakdownText != null && breakdownText.trim().isNotEmpty)
                  Text(
                    breakdownText,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    average > 0 ? average.toStringAsFixed(1) : '0.0',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$totalCount total',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _selectedRatingFilter = null; // Show all by default
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Update when tab changes to reflect icon color
      }
    });
  }

  /// Normalize disease label for comparison (match reports/disease map logic).
  static String _normalizeDiseaseLabel(String raw) {
    final s =
        raw
            .toLowerCase()
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (s.isEmpty || s == 'unknown' || s.contains('tip burn')) return '';
    if (s.contains('dermatitis') ||
        s.contains('dermatatis') ||
        s.contains('pityriasis'))
      return '';
    return s.replaceAll(' ', '_');
  }

  /// Extract set of normalized disease keys from a disease summary list.
  static Set<String> _diseaseSetFromSummary(List<dynamic> summary) {
    final set = <String>{};
    if (summary.isEmpty) return set;
    for (final e in summary) {
      String label = '';
      if (e is Map<String, dynamic>) {
        label =
            (e['label'] ?? e['disease'] ?? e['name'] ?? '').toString().trim();
      } else if (e is String) {
        label = e.trim();
      }
      final key = _normalizeDiseaseLabel(label);
      if (key.isNotEmpty) set.add(key);
    }
    return set;
  }

  /// True if expert agreed with farmer (same disease set). Else expert corrected.
  static bool _isCorrectDetection(Map<String, dynamic> request) {
    final expert = request['expertDiseaseSummary'];
    final farmer = request['diseaseSummary'];
    if (expert == null || expert is! List || expert.isEmpty) return false;
    final farmerList = farmer is List ? farmer : <dynamic>[];
    final expertSet = _diseaseSetFromSummary(expert);
    final farmerSet = _diseaseSetFromSummary(farmerList);
    return expertSet.length == farmerSet.length &&
        expertSet.containsAll(farmerSet);
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
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7204).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rate_rounded,
                    color: Color(0xFF2D7204),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Tabs
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFF2D7204),
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[700],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/farmer.png',
                        width: 18,
                        height: 18,
                        color:
                            _tabController.index == 0
                                ? Colors.white
                                : Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Farmers'),
                      ),
                    ],
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.medical_services, size: 18),
                      SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Veterinarians'),
                      ),
                    ],
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.smart_toy, size: 18),
                      SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('ML Experts'),
                      ),
                    ],
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.fact_check, size: 18),
                      SizedBox(width: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Disease Accuracy'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Rating Filter (hidden on Disease Accuracy tab)
        if (_tabController.index != 3)
          Row(
            children: [
              const Text(
                'Filter by Rating:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRatingFilterChip(null, 'All'),
                    _buildRatingFilterChip(5, '5 ⭐'),
                    _buildRatingFilterChip(4, '4 ⭐'),
                    _buildRatingFilterChip(3, '3 ⭐'),
                    _buildRatingFilterChip(2, '2 ⭐'),
                    _buildRatingFilterChip(1, '1 ⭐'),
                  ],
                ),
              ),
            ],
          ),
        if (_tabController.index != 3) const SizedBox(height: 16),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFarmersRatings(),
              _buildExpertsRatings(),
              _buildMLExpertsRatings(),
              _buildDiseaseAccuracyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingFilterChip(int? rating, String label) {
    final isSelected = _selectedRatingFilter == rating;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _selectedRatingFilter = selected ? rating : null;
        });
      },
      selectedColor: const Color(0xFF2D7204),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildFarmersRatings() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('app_ratings')
              .where('userRole', isEqualTo: 'farmer')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var ratings = snapshot.data?.docs ?? [];

        // Sort by createdAt in memory (descending)
        ratings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'];
          final bCreated = bData['createdAt'];

          DateTime? aDate, bDate;
          if (aCreated is Timestamp)
            aDate = aCreated.toDate();
          else if (aCreated is String)
            aDate = DateTime.tryParse(aCreated);

          if (bCreated is Timestamp)
            bDate = bCreated.toDate();
          else if (bCreated is String)
            bDate = DateTime.tryParse(bCreated);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate); // Descending
        });

        if (ratings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No farmer ratings yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Filter by selected rating if any
        final filteredRatings =
            _selectedRatingFilter == null
                ? ratings
                : ratings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  return rating == _selectedRatingFilter;
                }).toList();

        if (filteredRatings.isEmpty) {
          final avg = _calcAverageFromDocs(ratings);
          return Column(
            children: [
              _buildAverageHeader(
                title: 'Farmers average rating',
                average: avg,
                totalCount: ratings.length,
                accent: Colors.green,
                icon: Icons.agriculture,
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedRatingFilter == null
                            ? 'No farmer ratings yet'
                            : 'No ${_selectedRatingFilter}-star farmer ratings',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final avg = _calcAverageFromDocs(ratings);
        return Column(
          children: [
            _buildAverageHeader(
              title: 'Farmers average rating',
              average: avg,
              totalCount: ratings.length,
              accent: Colors.green,
              icon: Icons.agriculture,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredRatings.length,
                itemBuilder: (context, index) {
                  final doc = filteredRatings[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  final comment = data['comment']?.toString() ?? '';
                  final userName =
                      data['userName']?.toString() ?? 'Unknown Farmer';
                  final createdAt = data['createdAt'];
                  DateTime? date;
                  if (createdAt != null) {
                    if (createdAt is Timestamp) {
                      date = createdAt.toDate();
                    } else if (createdAt is String) {
                      date = DateTime.tryParse(createdAt);
                    }
                  }

                  return _buildRatingCard(
                    userName: userName,
                    rating: rating,
                    comment: comment,
                    date: date,
                    icon: Icons.agriculture,
                    color: Colors.green,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpertsRatings() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('app_ratings')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var ratings = (snapshot.data?.docs ?? []).where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final normalizedRole = _normalizeRole(data['userRole']?.toString());
          return _veterinarianRoles.contains(normalizedRole);
        }).toList();

        // Sort by createdAt in memory (descending)
        ratings.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'];
          final bCreated = bData['createdAt'];

          DateTime? aDate, bDate;
          if (aCreated is Timestamp)
            aDate = aCreated.toDate();
          else if (aCreated is String)
            aDate = DateTime.tryParse(aCreated);

          if (bCreated is Timestamp)
            bDate = bCreated.toDate();
          else if (bCreated is String)
            bDate = DateTime.tryParse(bCreated);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate); // Descending
        });

        if (ratings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No expert ratings yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Filter by selected rating if any
        final filteredRatings =
            _selectedRatingFilter == null
                ? ratings
                : ratings.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  return rating == _selectedRatingFilter;
                }).toList();

        if (filteredRatings.isEmpty) {
          final avgAll = _calcAverageFromDocs(ratings);
          // Optional breakdown
          final expertDocs = ratings.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _normalizeRole(data['userRole']?.toString()) == 'expert';
          }).toList();
          final headDocs = ratings.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _normalizeRole(data['userRole']?.toString()) == 'head_veterinarian';
          }).toList();
          final expertAvg = _calcAverageFromDocs(expertDocs);
          final headAvg = _calcAverageFromDocs(headDocs);
          final breakdown =
              'Experts: ${expertDocs.isEmpty ? '0.0' : expertAvg.toStringAsFixed(1)} (${expertDocs.length}) • '
              'Head Vets: ${headDocs.isEmpty ? '0.0' : headAvg.toStringAsFixed(1)} (${headDocs.length})';

          return Column(
            children: [
              _buildAverageHeader(
                title: 'Veterinarians average rating',
                average: avgAll,
                totalCount: ratings.length,
                breakdownText: breakdown,
                accent: Colors.purple,
                icon: Icons.medical_services,
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedRatingFilter == null
                            ? 'No expert ratings yet'
                            : 'No ${_selectedRatingFilter}-star expert ratings',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final avgAll = _calcAverageFromDocs(ratings);
        // Optional breakdown
        final expertDocs = ratings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _normalizeRole(data['userRole']?.toString()) == 'expert';
        }).toList();
        final headDocs = ratings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _normalizeRole(data['userRole']?.toString()) == 'head_veterinarian';
        }).toList();
        final expertAvg = _calcAverageFromDocs(expertDocs);
        final headAvg = _calcAverageFromDocs(headDocs);
        final breakdown =
            'Experts: ${expertDocs.isEmpty ? '0.0' : expertAvg.toStringAsFixed(1)} (${expertDocs.length}) • '
            'Head Vets: ${headDocs.isEmpty ? '0.0' : headAvg.toStringAsFixed(1)} (${headDocs.length})';

        return Column(
          children: [
            _buildAverageHeader(
              title: 'Veterinarians average rating',
              average: avgAll,
              totalCount: ratings.length,
              breakdownText: breakdown,
              accent: Colors.purple,
              icon: Icons.medical_services,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredRatings.length,
                itemBuilder: (context, index) {
                  final doc = filteredRatings[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  final comment = data['comment']?.toString() ?? '';
                  final userName =
                      data['userName']?.toString() ?? 'Unknown Expert';
                  final userRole = _normalizeRole(
                    data['userRole']?.toString() ?? 'expert',
                  );
                  final createdAt = data['createdAt'];
                  DateTime? date;
                  if (createdAt != null) {
                    if (createdAt is Timestamp) {
                      date = createdAt.toDate();
                    } else if (createdAt is String) {
                      date = DateTime.tryParse(createdAt);
                    }
                  }

                  return _buildRatingCard(
                    userName: userName,
                    rating: rating,
                    comment: comment,
                    date: date,
                    icon: userRole == 'head_veterinarian'
                        ? Icons.verified_user
                        : Icons.medical_services,
                    color: userRole == 'head_veterinarian'
                        ? Colors.blue
                        : Colors.purple,
                    role: userRole == 'head_veterinarian'
                        ? 'Head Veterinarian'
                        : (userRole == 'veterinarian'
                              ? 'Head veterenatian'
                              : 'Expert'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMLExpertsRatings() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('ml_expert_evaluations')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var evaluations = snapshot.data?.docs ?? [];

        // Sort by createdAt in memory (descending)
        evaluations.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'];
          final bCreated = bData['createdAt'];

          DateTime? aDate, bDate;
          if (aCreated is Timestamp)
            aDate = aCreated.toDate();
          else if (aCreated is String)
            aDate = DateTime.tryParse(aCreated);

          if (bCreated is Timestamp)
            bDate = bCreated.toDate();
          else if (bCreated is String)
            bDate = DateTime.tryParse(bCreated);

          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate); // Descending
        });

        if (evaluations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No ML expert evaluations yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Filter by selected rating if any
        final filteredEvaluations =
            _selectedRatingFilter == null
                ? evaluations
                : evaluations.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  return rating == _selectedRatingFilter;
                }).toList();

        if (filteredEvaluations.isEmpty) {
          final avg = _calcAverageFromDocs(evaluations);
          return Column(
            children: [
              _buildAverageHeader(
                title: 'ML Experts average rating',
                average: avg,
                totalCount: evaluations.length,
                accent: Colors.orange,
                icon: Icons.smart_toy,
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedRatingFilter == null
                            ? 'No ML expert evaluations yet'
                            : 'No ${_selectedRatingFilter}-star ML expert evaluations',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final avg = _calcAverageFromDocs(evaluations);
        return Column(
          children: [
            _buildAverageHeader(
              title: 'ML Experts average rating',
              average: avg,
              totalCount: evaluations.length,
              accent: Colors.orange,
              icon: Icons.smart_toy,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredEvaluations.length,
                itemBuilder: (context, index) {
                  final doc = filteredEvaluations[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final rating = (data['rating'] as num?)?.toInt() ?? 0;
                  final comment = data['comment']?.toString() ?? '';
                  final evaluatorName =
                      data['evaluatorName']?.toString() ?? 'Unknown ML Expert';
                  final imageCount = (data['imageCount'] as num?)?.toInt() ?? 0;
                  final summary = data['summary']?.toString() ?? '';
                  final createdAt = data['createdAt'];
                  DateTime? date;
                  if (createdAt != null) {
                    if (createdAt is Timestamp) {
                      date = createdAt.toDate();
                    } else if (createdAt is String) {
                      date = DateTime.tryParse(createdAt);
                    }
                  }

                  return _buildMLExpertCard(
                    evaluatorName: evaluatorName,
                    rating: rating,
                    comment: comment,
                    date: date,
                    imageCount: imageCount,
                    summary: summary,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiseaseAccuracyTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ScanRequestsService.getScanRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final all = snapshot.data ?? [];
        final completed =
            all.where((r) {
              if ((r['status'] ?? '').toString() != 'completed') return false;
              final expert = r['expertDiseaseSummary'];
              return expert != null && expert is List && expert.isNotEmpty;
            }).toList();

        int correctDetection = 0;
        int expertVerification = 0;
        for (final r in completed) {
          if (_isCorrectDetection(r)) {
            correctDetection++;
          } else {
            expertVerification++;
          }
        }

        final total = completed.length;
        final correctPct = total > 0 ? (correctDetection / total) * 100 : 0.0;
        final expertPct = total > 0 ? (expertVerification / total) * 100 : 0.0;

        if (total == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed reviews yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Disease accuracy is based on expert-validated scans.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                'Scans submitted by farmers are reviewed by experts. Counts below are for completed reviews only.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              // Summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total completed reviews',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Correct detection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7204).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2D7204).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: const Color(0xFF2D7204),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Correct detection',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expert agreed with farmer/model',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$correctDetection',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D7204),
                          ),
                        ),
                        Text(
                          '${correctPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Expert verification
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: Colors.orange.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expert verification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expert corrected or changed the result',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$expertVerification',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        Text(
                          '${expertPct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRatingCard({
    required String userName,
    required int rating,
    required String comment,
    DateTime? date,
    required IconData icon,
    required Color color,
    String? role,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (role != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Star rating
                Row(
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMLExpertCard({
    required String evaluatorName,
    required int rating,
    required String comment,
    DateTime? date,
    required int imageCount,
    required String summary,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        evaluatorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (date != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Star rating
                Row(
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 20,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Scan details
            Row(
              children: [
                _buildInfoChip(
                  Icons.image,
                  '$imageCount image${imageCount != 1 ? 's' : ''}',
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                if (summary.isNotEmpty)
                  Expanded(
                    child: _buildInfoChip(
                      Icons.description,
                      summary.length > 30
                          ? '${summary.substring(0, 30)}...'
                          : summary,
                      Colors.green,
                    ),
                  ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
