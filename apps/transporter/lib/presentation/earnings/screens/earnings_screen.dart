import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is! DashboardLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final userId = state.user.uid;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('handoffs')
                .where('transporterId', isEqualTo: userId)
                .where('gate2', isNotEqualTo: null)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final handoffsDocs = snapshot.data?.docs ?? [];

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchValidHandoffs(handoffsDocs),
                builder: (context, futureSnapshot) {
                  if (futureSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = futureSnapshot.data ?? [];
                  double total = 0;
                  for (var item in items) {
                    final data = item['handoff'] as Map<String, dynamic>;
                    total += (data['payment']?['transporterFeeUSD'] ?? 0).toDouble();
                  }

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.bark, AppColors.soil],
                          ),
                        ),
                        child: Column(
                          children: [
                            Text('Earnings Status', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.wheat)),
                            const SizedBox(height: 8),
                            Text(
                              NumberFormat.currency(symbol: '\$').format(total),
                              style: AppTextStyles.displayLarge.copyWith(color: Colors.white, fontSize: 48),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white)),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: items.isEmpty
                            ? const Center(child: Text('No earnings yet.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return HandoffEarningTile(
                                    handoffData: items[index]['handoff'] as Map<String, dynamic>,
                                    listingData: items[index]['listing'] as Map<String, dynamic>,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchValidHandoffs(List<QueryDocumentSnapshot> docs) async {
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
          'handoff': docs[i].data(),
          'listing': snapshots[i].data(),
        });
      }
    }

    return validItems;
  }
}

class HandoffEarningTile extends StatelessWidget {
  final Map<String, dynamic> handoffData;
  final Map<String, dynamic> listingData;

  const HandoffEarningTile({
    super.key,
    required this.handoffData,
    required this.listingData,
  });

  @override
  Widget build(BuildContext context) {
    final fee = (handoffData['payment']?['transporterFeeUSD'] ?? 0).toDouble();
    final releasedAt = (handoffData['payment']?['releasedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final cropType = (listingData['cropType'] as String?)?.replaceAll('_', ' ') ?? 'Unknown';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: const CircleAvatar(
        backgroundColor: AppColors.cream2,
        child: Text('🍇'),
      ),
      title: Text(
        cropType.toUpperCase(),
        style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMM dd, yyyy').format(releasedAt)),
          Text(
            handoffData['payment']?['releasedAt'] != null ? 'Paid' : 'Pending Payout',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: handoffData['payment']?['releasedAt'] != null ? Colors.green : Colors.orange),
          ),
        ],
      ),
      trailing: Text(
        '+\$${fee.toStringAsFixed(2)}',
        style: AppTextStyles.titleLarge.copyWith(fontSize: 16, color: AppColors.moss),
      ),
    );
  }
}
