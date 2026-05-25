import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/listing_model.dart';
import '../../widgets/active_haul_card.dart';

class ActiveHaulsScreen extends StatefulWidget {
  final VoidCallback onGoToDiscover;
  const ActiveHaulsScreen({super.key, required this.onGoToDiscover});

  @override
  State<ActiveHaulsScreen> createState() => _ActiveHaulsScreenState();
}

class _ActiveHaulsScreenState extends State<ActiveHaulsScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Hauls', style: AppTextStyles.headlineLarge.copyWith(fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: currentUserId == null
          ? const Center(child: Text('Please sign in to view active hauls'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('listings')
                  .where('producerId', isEqualTo: currentUserId)
                  .where('status', whereIn: ['MATCHED', 'LOCKED', 'IN_TRANSIT', 'DELIVERED', 'SETTLED'])
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.moss));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.stone),
                          const SizedBox(height: 16),
                          Text('No active hauls', style: AppTextStyles.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Claim a listing from Discover tab to start your harvest',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: widget.onGoToDiscover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.moss,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: const Text('Go to Discover'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final listings = snapshot.data!.docs.map((doc) => ListingModel.fromFirestore(doc)).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return ActiveHaulCard(
                      listing: listing,
                      onTap: () {
                        context.push('/listing/${listing.listingId}');
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
