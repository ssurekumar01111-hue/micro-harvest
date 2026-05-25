import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../../data/models/handoff_model.dart';

class HaulsHistoryScreen extends StatelessWidget {
  const HaulsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Haul History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('handoffs')
                  .where('transporterId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final handoffsDocs = snapshot.data?.docs ?? [];
                if (handoffsDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchValidHauls(handoffsDocs),
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = futureSnapshot.data ?? [];
                    if (items.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Sort items (fallback sorting)
                    items.sort((a, b) {
                      final hA = a['handoff'] as HandoffModel;
                      final hB = b['handoff'] as HandoffModel;
                      final dateA = (hA.gate2?['confirmedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      final dateB = (hB.gate2?['confirmedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      return dateB.compareTo(dateA);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        return _HandoffCard(
                          handoff: items[index]['handoff'] as HandoffModel,
                          listingData: items[index]['listing'] as Map<String, dynamic>,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.stone),
          const SizedBox(height: 16),
          Text('No hauls yet', style: AppTextStyles.titleLarge),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchValidHauls(List<QueryDocumentSnapshot> docs) async {
    final List<Map<String, dynamic>> validItems = [];

    // Fetch all listings in parallel to check existence
    final futures = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return FirebaseFirestore.instance.collection('listings').doc(data['listingId']).get();
    }).toList();
    
    final snapshots = await Future.wait(futures);

    for (int i = 0; i < docs.length; i++) {
      if (snapshots[i].exists) {
        validItems.add({
          'handoff': HandoffModel.fromFirestore(docs[i]),
          'listing': snapshots[i].data(),
        });
      }
    }

    return validItems;
  }
}

class _HandoffCard extends StatelessWidget {
  final HandoffModel handoff;
  final Map<String, dynamic> listingData;

  const _HandoffCard({
    required this.handoff,
    required this.listingData,
  });

  @override
  Widget build(BuildContext context) {
    final cropType = (listingData['cropType'] as String?)?.replaceAll('_', ' ') ?? 'Unknown';
    final weight = (listingData['weightKg'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cropType.toUpperCase(),
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                ),
                _StatusBadge(handoff: handoff),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${NumberFormat('#,###').format(weight)}kg surplus',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ID: ${handoff.handoffId.substring(0, 8)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.stone, fontFamily: 'monospace'),
                ),
                if (handoff.payment != null)
                  Text(
                    NumberFormat.simpleCurrency().format(handoff.payment!.transporterFeeUSD),
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.moss),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final HandoffModel handoff;
  const _StatusBadge({required this.handoff});

  @override
  Widget build(BuildContext context) {
    String label = 'PENDING';
    Color color = AppColors.stone;

    if (handoff.payment?.releasedAt != null) {
      label = 'SETTLED';
      color = AppColors.moss;
    } else if (handoff.gate2 != null) {
      label = 'DELIVERED';
      color = AppColors.harvest;
    } else if (handoff.gate1 != null) {
      label = 'IN TRANSIT';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
