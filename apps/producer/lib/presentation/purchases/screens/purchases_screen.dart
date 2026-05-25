import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/handoff_model.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Purchase History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('handoffs')
                  .where('producerId', isEqualTo: uid)
                  .where('gate2', isNull: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No purchases yet'));
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchValidPurchases(snapshot.data!.docs),
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = futureSnapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(child: Text('No purchases yet'));
                    }

                    // Sort items by confirmation date
                    items.sort((a, b) {
                      final hA = a['handoff'] as HandoffModel;
                      final hB = b['handoff'] as HandoffModel;
                      final dateA = (hA.gate2?['confirmedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      final dateB = (hB.gate2?['confirmedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
                      return dateB.compareTo(dateA);
                    });

                    double totalSpent = 0;
                    for (var item in items) {
                      final h = item['handoff'] as HandoffModel;
                      if (h.payment?.releasedAt != null) {
                        totalSpent += h.payment!.totalUSD;
                      }
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.bark,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Total Spending',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.wheat.withValues(alpha: 0.7)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  NumberFormat.simpleCurrency().format(totalSpent),
                                  style: AppTextStyles.displayLarge.copyWith(color: AppColors.wheat, fontSize: 40),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = items[index];
                                return _PurchaseCard(
                                  handoff: item['handoff'] as HandoffModel,
                                  listingData: item['listing'] as Map<String, dynamic>,
                                );
                              },
                              childCount: items.length,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchValidPurchases(List<QueryDocumentSnapshot> docs) async {
    final rawHandoffs = docs.map((doc) => HandoffModel.fromFirestore(doc)).toList();
    final List<Map<String, dynamic>> validItems = [];

    // Fetch all listings in parallel to check existence
    final futures = rawHandoffs.map((h) => FirebaseFirestore.instance.collection('listings').doc(h.listingId).get()).toList();
    final snapshots = await Future.wait(futures);

    for (int i = 0; i < rawHandoffs.length; i++) {
      if (snapshots[i].exists) {
        validItems.add({
          'handoff': rawHandoffs[i],
          'listing': snapshots[i].data(),
        });
      }
    }

    return validItems;
  }
}

class _PurchaseCard extends StatelessWidget {
  final HandoffModel handoff;
  final Map<String, dynamic> listingData;

  const _PurchaseCard({
    required this.handoff,
    required this.listingData,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = handoff.payment?.releasedAt != null;
    final date = (handoff.gate2?['confirmedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final crop = (listingData['cropType'] as String?)?.replaceAll('_', ' ') ?? 'Unknown';
    final weight = listingData['weightKg'] ?? handoff.weightKg;
    final cropInfo = '$crop • ${weight}kg';

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
                Expanded(
                  child: Text(
                    cropInfo.toUpperCase(),
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                  ),
                ),
                _StatusBadge(isSettled: isSettled),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(date),
              style: const TextStyle(fontSize: 12, color: AppColors.stone),
            ),
            const Divider(height: 24),
            
            _buildFeeRow('Grower Share (80%)', handoff.payment?.growerShareUSD ?? 0),
            _buildFeeRow('Transporter Fee (15%)', handoff.payment?.transporterFeeUSD ?? 0),
            _buildFeeRow('Platform Fee (5%)', handoff.payment?.platformFeeUSD ?? 0),
            
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  NumberFormat.simpleCurrency().format(handoff.payment?.totalUSD ?? 0),
                  style: AppTextStyles.titleLarge.copyWith(color: AppColors.moss),
                ),
              ],
            ),
            if (handoff.payment?.stripePaymentId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Stripe ID: ${handoff.payment!.stripePaymentId}',
                style: const TextStyle(fontSize: 10, color: AppColors.stone, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
          Text(NumberFormat.simpleCurrency().format(amount), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isSettled;
  const _StatusBadge({required this.isSettled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSettled ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isSettled ? Colors.green : Colors.blue),
      ),
      child: Text(
        isSettled ? 'COMPLETED' : 'PROCESSING',
        style: TextStyle(
          color: isSettled ? Colors.green : Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
