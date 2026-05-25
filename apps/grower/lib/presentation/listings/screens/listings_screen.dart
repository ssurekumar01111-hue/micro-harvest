import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/bottom_nav.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  ListingStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        bottomNavigationBar: const BottomNav(),
        appBar: AppBar(
          title: Text('My Harvests', style: AppTextStyles.titleLarge),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.moss,
          onPressed: () => context.push('/listings/create'),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _buildFilterChip('All', null),
                  const SizedBox(width: 8),
                  _buildFilterChip('Open', ListingStatus.open),
                  const SizedBox(width: 8),
                  _buildFilterChip('Matched', ListingStatus.matched),
                  const SizedBox(width: 8),
                  _buildFilterChip('Locked', ListingStatus.locked),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Transit', ListingStatus.inTransit),
                  const SizedBox(width: 8),
                  _buildFilterChip('Settled', ListingStatus.settled),
                  const SizedBox(width: 8),
                  _buildFilterChip('Expired', ListingStatus.expired),
                ],
              ),
            ),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Please log in to see listings'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('listings')
                          .where('growerId', isEqualTo: uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];
                        var listings = docs.map((doc) => ListingModel.fromFirestore(doc)).toList();

                        if (_selectedStatus != null) {
                          listings = listings.where((l) => l.status == _selectedStatus).toList();
                        }

                        if (listings.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: listings.length,
                          itemBuilder: (context, index) {
                            final listing = listings[index];
                            return ListingCard(
                              listing: listing,
                              onTap: () => context.push('/listings/${listing.listingId}'),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ListingStatus? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedStatus = status),
      selectedColor: AppColors.moss,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.bark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppColors.cream2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.moss : AppColors.stone.withValues(alpha: 0.3)),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌾', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('No listings yet', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first listing\nor use the AI Agent',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/agent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.moss,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Open AI Agent'),
            ),
          ],
        ),
      ),
    );
  }
}
