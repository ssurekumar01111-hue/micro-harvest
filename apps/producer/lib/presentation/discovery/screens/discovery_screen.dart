import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/listing_card.dart';
import '../../../data/models/listing_model.dart';
import 'listing_detail_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final List<String> _crops = ['All', 'PINOT_NOIR', 'CHARDONNAY', 'RIESLING', 'CABERNET', 'MERLOT', 'Urgent'];
  String _activeCrop = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Discover', style: AppTextStyles.headlineLarge),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: _crops.map((crop) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(crop.replaceAll('_', ' ')),
                    selected: _activeCrop == crop,
                    onSelected: (val) {
                      setState(() => _activeCrop = crop);
                    },
                    selectedColor: AppColors.moss,
                    labelStyle: TextStyle(
                      color: _activeCrop == crop ? Colors.white : AppColors.stone,
                      fontWeight: _activeCrop == crop ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('listings')
                    .where('status', isEqualTo: 'OPEN')
                    .orderBy('createdAt', descending: true)
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🌾', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('No listings available', style: AppTextStyles.headlineLarge),
                          Text('Check back soon for new surplus',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
                        ],
                      ),
                    );
                  }

                  var listings = snapshot.data!.docs.map((doc) => ListingModel.fromFirestore(doc)).toList();

                  // Local filtering
                  if (_activeCrop != 'All') {
                    if (_activeCrop == 'Urgent') {
                      listings = listings.where((l) => l.perishTier == PerishTier.HOURS_12 || l.perishTier == PerishTier.HOURS_24).toList();
                    } else {
                      listings = listings.where((l) => l.cropType == _activeCrop).toList();
                    }
                  }

                  if (listings.isEmpty) {
                    return const Center(child: Text('No listings match your filter'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final listing = listings[index];
                      return ListingCard(
                        listing: listing,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listingId: listing.listingId),
                          ),
                        ),
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
}
