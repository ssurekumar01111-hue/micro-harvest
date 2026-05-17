import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class ListingDetailScreen extends StatelessWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<DiscoveryBloc, DiscoveryState>(
        listener: (context, state) {
          if (state is DiscoveryClaimed && state.listingId == listingId) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing claimed successfully!')));
            context.go('/active');
          } else if (state is DiscoveryError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is DiscoveryLoaded) {
            final listing = state.listings.firstWhere((l) => l.listingId == listingId);
            
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(listing.cropType.name.replaceAll('_', ' '), style: const TextStyle(color: AppColors.bark)),
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
                            _buildStat('Weight', '${listing.weightKg}kg'),
                            _buildStat('Window', 'Within 24h'),
                            _buildStat('Price', NumberFormat.simpleCurrency().format(listing.askingPriceUSD)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text('Location', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 16),
                        Container(
                          height: 180,
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
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Containers', style: AppTextStyles.titleLarge),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: AppColors.moss),
                                const SizedBox(width: 16),
                                Text('${listing.containerCount}x ${listing.containerType.name.replaceAll('_', ' ')}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        ElevatedButton(
                          onPressed: () => _showClaimConfirm(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.moss,
                            foregroundColor: Colors.white,
                          ),
                          child: state is DiscoveryClaiming 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Claim This Surplus'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Center(child: Text('Save for Later', style: TextStyle(color: AppColors.stone))),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.titleLarge.copyWith(color: AppColors.bark)),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
      ],
    );
  }

  void _showClaimConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        title: const Text('Confirm Claim'),
        content: const Text('By claiming this listing, you commit to purchasing the crop. A transporter will be notified to handle pickup.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(innerContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(innerContext);
              context.read<DiscoveryBloc>().add(ClaimListing(listingId));
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
