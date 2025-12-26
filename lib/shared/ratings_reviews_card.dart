import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingsReviewsCard extends StatefulWidget {
  final VoidCallback? onTap;
  const RatingsReviewsCard({Key? key, this.onTap}) : super(key: key);

  @override
  State<RatingsReviewsCard> createState() => _RatingsReviewsCardState();
}

class _RatingsReviewsCardState extends State<RatingsReviewsCard> {
  final ValueNotifier<bool> _isHovered = ValueNotifier(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHovered,
      builder: (context, isHovered, _) {
        return MouseRegion(
          onEnter: (_) => _isHovered.value = true,
          onExit: (_) => _isHovered.value = false,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
              child: Card(
                elevation: isHovered ? 8 : 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: _buildCardContent(isHovered),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardContent(bool isHovered) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('app_ratings').snapshots(),
      builder: (context, appRatingsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('ml_expert_evaluations')
                  .snapshots(),
          builder: (context, mlEvaluationsSnapshot) {
            // Calculate counts and average rating
            int farmerRatingsCount = 0;
            int expertRatingsCount = 0;
            int mlExpertRatingsCount = 0;
            double totalRating = 0.0;
            int ratingCount = 0;

            // Process app ratings (farmers and experts)
            if (appRatingsSnapshot.hasData) {
              for (final doc in appRatingsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final userRole = data['userRole']?.toString() ?? '';
                final rating = (data['rating'] as num?)?.toDouble();

                if (userRole == 'farmer') {
                  farmerRatingsCount++;
                } else if (userRole == 'expert' ||
                    userRole == 'head_veterinarian') {
                  expertRatingsCount++;
                }

                // Calculate average from farmers and experts only (excluding ML experts)
                if (rating != null &&
                    rating > 0 &&
                    userRole != 'machine_learning_expert') {
                  totalRating += rating;
                  ratingCount++;
                }
              }
            }

            // Count ML expert evaluations
            if (mlEvaluationsSnapshot.hasData) {
              mlExpertRatingsCount = mlEvaluationsSnapshot.data!.docs.length;
            }

            final averageRating =
                ratingCount > 0 ? totalRating / ratingCount : 0.0;
            final totalCount =
                farmerRatingsCount + expertRatingsCount + mlExpertRatingsCount;

            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7204).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.star_rate_rounded,
                    color: Color(0xFF2D7204),
                    size: 18,
                  ),
                ),
                const SizedBox(height: 8),
                // Title
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                // Average rating with star
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      averageRating > 0
                          ? averageRating.toStringAsFixed(1)
                          : '0.0',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                // Total count
                Text(
                  '$totalCount Total',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                // View all link
                Text(
                  'View all ratings',
                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        );
      },
    );
  }
}
