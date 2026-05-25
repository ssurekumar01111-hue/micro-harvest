import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/listing_model.dart';
import '../../main/navigation_provider.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<DiscoveryBloc, DiscoveryState>(
      listener: (context, state) {
        if (state is DiscoveryClaimed && state.listingId == widget.listingId) {
          final nav = context.read<NavigationProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully claimed! Switching to Active tab.')),
          );
          nav.setIndex(1);
          context.pop();
        } else if (state is DiscoveryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to claim: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('listings').doc(widget.listingId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.moss));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Listing not found'));
            }

            final listing = ListingModel.fromFirestore(snapshot.data!);

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      ListingModel.cropDisplayName(listing.cropType),
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.bark),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.wheat, AppColors.cream],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStat('Weight', '${listing.weightKg.toStringAsFixed(0)}kg'),
                            _buildStat('Window', _getPerishLabel(listing.perishTier)),
                            Builder(
                              builder: (context) {
                                final pricePerTon = listing.askingPricePerTon ?? 0.0;
                                final weightTons = listing.weightKg / 1000;
                                final totalPrice = pricePerTon * weightTons;

                                return Column(
                                  children: [
                                    Text(
                                      totalPrice > 0 ? NumberFormat.simpleCurrency(decimalDigits: 0).format(totalPrice) : 'Price TBD',
                                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.bark, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      pricePerTon > 0 ? '\$${pricePerTon.toStringAsFixed(0)}/ton' : 'Price TBD',
                                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text('Location', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.cream2,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(listing.plotLocation.latitude, listing.plotLocation.longitude),
                              zoom: 14,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('plot'),
                                position: LatLng(listing.plotLocation.latitude, listing.plotLocation.longitude),
                              ),
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Container Breakdown', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppColors.stone.withValues(alpha: 0.1)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: AppColors.moss),
                                const SizedBox(width: 16),
                                Text(
                                  '${listing.containerCount}x ${ListingModel.containerDisplayName(listing.containerType)}',
                                  style: AppTextStyles.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        if (listing.status == ListingStatus.OPEN)
                          BlocBuilder<DiscoveryBloc, DiscoveryState>(
                            builder: (context, state) {
                              final isClaiming = state is DiscoveryClaiming;
                              return SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isClaiming ? null : () => _showClaimConfirm(context, listing),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.moss,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: isClaiming
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Claim This Surplus',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.stone.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Listing Status: ${listing.status.name}',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.stone),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Center(child: Text('Go Back', style: TextStyle(color: AppColors.stone))),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getPerishLabel(PerishTier tier) {
    switch (tier) {
      case PerishTier.HOURS_12:
        return '12h';
      case PerishTier.HOURS_24:
        return '24h';
      case PerishTier.DAYS_3:
        return '3 Days';
      case PerishTier.DAYS_7:
        return '7 Days';
    }
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleLarge.copyWith(color: AppColors.bark, fontWeight: FontWeight.bold)),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
      ],
    );
  }

  void _showClaimConfirm(BuildContext context, ListingModel listing) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        title: const Text('Confirm Claim'),
        content: Text('Claim ${ListingModel.cropDisplayName(listing.cropType)}? This will notify a transporter and secure the surplus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(innerContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(innerContext);
              context.read<DiscoveryBloc>().add(ClaimListing(listing.listingId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss, foregroundColor: Colors.white),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
