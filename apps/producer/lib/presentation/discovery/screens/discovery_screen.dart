import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/discovery_bloc.dart';
import '../bloc/discovery_event.dart';
import '../bloc/discovery_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/bottom_nav.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final List<String> _crops = ['All', 'PINOT_NOIR', 'CHARDONNAY', 'RIESLING', 'CABERNET', 'MERLOT'];
  String _activeCrop = 'All';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      context.read<DiscoveryBloc>().add(
        LoadDiscovery(location: GeoPoint(pos.latitude, pos.longitude), radius: 50),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(),
      body: BlocBuilder<DiscoveryBloc, DiscoveryState>(
        builder: (context, state) {
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discover', style: AppTextStyles.headlineLarge),
                      const CircleAvatar(
                        backgroundColor: AppColors.wheat,
                        child: Icon(Icons.person, color: AppColors.bark),
                      ),
                    ],
                  ),
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
                          context.read<DiscoveryBloc>().add(FilterByCrop(crop == 'All' ? null : crop));
                        },
                        selectedColor: AppColors.wheat,
                        labelStyle: TextStyle(
                          color: _activeCrop == crop ? AppColors.bark : AppColors.stone,
                          fontWeight: _activeCrop == crop ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: state is DiscoveryLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : state is DiscoveryLoaded
                      ? Column(
                          children: [
                            Container(
                              height: 250,
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppColors.cream2,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(state.producerLocation.latitude, state.producerLocation.longitude),
                                  zoom: 10,
                                ),
                                markers: state.listings.map((l) => Marker(
                                  markerId: MarkerId(l.listingId),
                                  position: LatLng(l.plotLocation.latitude, l.plotLocation.longitude),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                )).toSet(),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text('Flash Surplus', style: AppTextStyles.titleLarge),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                itemCount: state.listings.length,
                                itemBuilder: (context, index) {
                                  return ListingCard(
                                    listing: state.listings[index],
                                    onTap: () => context.push('/listing/${state.listings[index].listingId}'),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : const Center(child: Text('Error loading listings')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
