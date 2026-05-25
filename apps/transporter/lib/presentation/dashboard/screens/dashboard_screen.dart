import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../../../data/repositories/location_repository.dart';
import '../../../../data/models/handoff_model.dart';
import '../../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(LoadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardLoaded) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ready to Haul', style: AppTextStyles.headlineLarge),
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: const CircleAvatar(
                            backgroundColor: AppColors.harvest,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (state.activeHandoff != null) ...[
                      Text('Active Route', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: HaulMap(handoff: state.activeHandoff!),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Availability Toggle Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available for Hauls',
                                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "You'll receive haul alerts",
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cream2),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: state.isAvailable,
                            onChanged: (val) {
                              context.read<DashboardBloc>().add(ToggleAvailability(val));
                            },
                            activeTrackColor: AppColors.moss,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Today', '\$${state.todayEarnings.toStringAsFixed(0)}'),
                        _buildStat('Total Hauls', state.totalHauls.toString()),
                        _buildStat('Rating', state.rating.toString()),
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (state.activeHandoff != null) ...[
                      Text('Active Haul', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 16),
                      _buildActiveHaulCard(state.activeHandoff!),
                      const SizedBox(height: 32),
                    ],

                    if (state.pendingHauls.isNotEmpty) ...[
                      Text('Incoming Haul Requests', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 16),
                      ...state.pendingHauls.map((haul) => _buildPendingHaulCard(haul)),
                      const SizedBox(height: 32),
                    ],

                    if (state.activeHandoff == null && state.pendingHauls.isEmpty) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('No active hauls. Stay available to receive alerts!'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text('Error loading dashboard'));
        },
      ),
    );
  }

  Widget _buildPendingHaulCard(ListingModel listing) {
    return Card(
      color: AppColors.moss.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.moss,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('NEW REQUEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Text('Expires in 30m', style: TextStyle(color: AppColors.stone, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined, color: AppColors.moss, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ListingModel.cropDisplayName(listing.cropType), style: AppTextStyles.titleLarge.copyWith(fontSize: 18)),
                      Text('${listing.weightKg}kg · Pickup near lat ${listing.plotLocation.latitude.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.stone)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/haul/${listing.listingId}', extra: listing),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss),
              child: const Text('View Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.headlineLarge.copyWith(fontSize: 24)),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
      ],
    );
  }

  Widget _buildActiveHaulCard(HandoffModel handoff) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.harvest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('IN TRANSIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Text('02:45 remaining', style: TextStyle(color: AppColors.stone, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppColors.bark, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Haul', style: AppTextStyles.titleLarge.copyWith(fontSize: 18)),
                      Text('Handoff #${handoff.handoffId.substring(0, 8)}', style: const TextStyle(color: AppColors.stone)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (handoff.gate1 == null) {
                  context.push('/gate1/${handoff.handoffId}');
                } else if (handoff.gate2 == null) {
                  context.push('/gate2/${handoff.handoffId}');
                }
              },
              child: const Text('Confirm Delivery'),
            ),
          ],
        ),
      ),
    );
  }
}

class HaulMap extends StatefulWidget {
  final HandoffModel handoff;
  const HaulMap({super.key, required this.handoff});

  @override
  State<HaulMap> createState() => _HaulMapState();
}

class _HaulMapState extends State<HaulMap> {
  LatLng? _pickupLoc;
  LatLng? _deliveryLoc;
  LatLng? _myLoc;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _fetchStaticLocations();
    _startLocationTracking();
  }

  Future<void> _fetchStaticLocations() async {
    final listingDoc = await FirebaseFirestore.instance.collection('listings').doc(widget.handoff.listingId).get();
    if (listingDoc.exists) {
      final plot = listingDoc.data()?['plotLocation'] as GeoPoint?;
      if (plot != null) {
        setState(() => _pickupLoc = LatLng(plot.latitude, plot.longitude));
      }
    }

    final producerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.handoff.producerId).get();
    if (producerDoc.exists) {
      final prodLoc = producerDoc.data()?['geoPoint'] as GeoPoint?;
      if (prodLoc != null) {
        setState(() => _deliveryLoc = LatLng(prodLoc.latitude, prodLoc.longitude));
      }
    }
  }

  void _startLocationTracking() {
    _updateMyLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateMyLocation());
  }

  Future<void> _updateMyLocation() async {
    try {
      final pos = await context.read<LocationRepository>().getCurrentPosition();
      final newLoc = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _myLoc = newLoc);
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.handoff.transporterId).update({
        'geoPoint': GeoPoint(pos.latitude, pos.longitude),
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_pickupLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLoc!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));
    }
    if (_deliveryLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('delivery'),
        position: _deliveryLoc!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Delivery Location'),
      ));
    }
    if (_myLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('self'),
        position: _myLoc!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _myLoc ?? _pickupLoc ?? const LatLng(38.5, -121.7),
        zoom: 12,
      ),
      markers: markers,
      myLocationEnabled: true,
    );
  }
}
