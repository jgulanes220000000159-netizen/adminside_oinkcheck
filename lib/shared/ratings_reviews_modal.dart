import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedRatingFilter = null; // Show all by default
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Update when tab changes to reflect icon color
      }
    });
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Custom icon using Image.asset - you can replace 'assets/logo.png' with your farmer icon
                      Image.asset(
                        'assets/farmer.png', // Replace with your custom farmer icon path
                        width: 20,
                        height: 20,
                        color:
                            _tabController.index == 0
                                ? Colors.white
                                : Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      const Text('Farmers'),
                    ],
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.medical_services, size: 20),
                      SizedBox(width: 8),
                      Text('Experts & Head Vets'),
                    ],
                  ),
                ),
              ),
              Tab(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.smart_toy, size: 20),
                      SizedBox(width: 8),
                      Text('ML Experts'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Rating Filter
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
        const SizedBox(height: 16),
        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFarmersRatings(),
              _buildExpertsRatings(),
              _buildMLExpertsRatings(),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedRatingFilter == null
                      ? 'No farmer ratings yet'
                      : 'No ${_selectedRatingFilter}-star farmer ratings',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredRatings.length,
          itemBuilder: (context, index) {
            final doc = filteredRatings[index];
            final data = doc.data() as Map<String, dynamic>;
            final rating = (data['rating'] as num?)?.toInt() ?? 0;
            final comment = data['comment']?.toString() ?? '';
            final userName = data['userName']?.toString() ?? 'Unknown Farmer';
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
        );
      },
    );
  }

  Widget _buildExpertsRatings() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('app_ratings')
              .where('userRole', whereIn: ['expert', 'head_veterinarian'])
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedRatingFilter == null
                      ? 'No expert ratings yet'
                      : 'No ${_selectedRatingFilter}-star expert ratings',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredRatings.length,
          itemBuilder: (context, index) {
            final doc = filteredRatings[index];
            final data = doc.data() as Map<String, dynamic>;
            final rating = (data['rating'] as num?)?.toInt() ?? 0;
            final comment = data['comment']?.toString() ?? '';
            final userName = data['userName']?.toString() ?? 'Unknown Expert';
            final userRole = data['userRole']?.toString() ?? 'expert';
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
              icon:
                  userRole == 'head_veterinarian'
                      ? Icons.verified_user
                      : Icons.medical_services,
              color:
                  userRole == 'head_veterinarian' ? Colors.blue : Colors.purple,
              role:
                  userRole == 'head_veterinarian'
                      ? 'Head Veterinarian'
                      : 'Expert',
            );
          },
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _selectedRatingFilter == null
                      ? 'No ML expert evaluations yet'
                      : 'No ${_selectedRatingFilter}-star ML expert evaluations',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
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
