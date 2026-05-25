import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/haul_bloc.dart';
import '../bloc/haul_event.dart';
import '../bloc/haul_state.dart';
import '../../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class HaulAlertScreen extends StatefulWidget {
  final dynamic listing; // Can be ListingModel or String (listingId)
  const HaulAlertScreen({super.key, required this.listing});

  @override
  State<HaulAlertScreen> createState() => _HaulAlertScreenState();
}

class _HaulAlertScreenState extends State<HaulAlertScreen> {
  int _secondsRemaining = 1800; // 30 minutes default
  Timer? _timer;
  ListingModel? _currentListing;
  Future<DocumentSnapshot>? _producerFuture;

  @override
  void initState() {
    super.initState();
    if (widget.listing is ListingModel) {
      _currentListing = widget.listing as ListingModel;
      _initFutures();
      _startTimer();
    } else if (widget.listing is String) {
      // Trigger fetch from Firestore via BLoC
      context.read<HaulBloc>().add(FetchHaulDetails(widget.listing as String));
    }
  }

  void _initFutures() {
    if (_currentListing?.producerId != null) {
      _producerFuture = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentListing!.producerId)
          .get()
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('timeout'),
          );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _timer?.cancel();
            context.pop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getUrgencyLabel(PerishTier tier) {
    switch (tier) {
      case PerishTier.HOURS_12: return '12h window';
      case PerishTier.HOURS_24: return '24h window';
      case PerishTier.DAYS_3: return '3 day window';
      case PerishTier.DAYS_7: return '7 day window';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<HaulBloc, HaulState>(
        listener: (context, state) {
          if (state is HaulAccepted) {
            context.go('/dashboard');
          } else if (state is HaulLoaded) {
            setState(() {
              _currentListing = state.listing;
              _initFutures();
              // Sync timer with matchedAt if available, otherwise 30m from now
              if (_currentListing!.matchedAt != null) {
                final elapsed = DateTime.now().difference(_currentListing!.matchedAt!).inSeconds;
                _secondsRemaining = (1800 - elapsed).clamp(0, 1800);
              }
            });
            _startTimer();
          }
        },
        builder: (context, state) {
          if (state is HaulLoading && _currentListing == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.harvest));
          }

          if (state is HaulError && _currentListing == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message, textAlign: TextAlign.center, style: AppTextStyles.bodyLarge),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_currentListing == null) {
            return const SizedBox.shrink();
          }

          final listing = _currentListing!;
          final weightKg = listing.weightKg;
          final pricePerTon = listing.askingPricePerTon ?? listing.askingPriceUSD;
          final weightTons = weightKg / 1000;
          
          // FIX: Use pricePerTon (askingPricePerTon) * weightTons * 0.15
          final estimatedFee = (pricePerTon > 0)
              ? weightTons * pricePerTon * 0.15
              : null;

          return Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.harvest,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('NEW HAUL ALERT', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                    child: Text(_timerText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                ListingModel.cropDisplayName(listing.cropType),
                                style: AppTextStyles.displayMedium.copyWith(color: Colors.white, fontSize: 32),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              '${NumberFormat('#,###').format(listing.weightKg)}kg · ${listing.containerCount} ${ListingModel.containerDisplayName(listing.containerType)}',
                              style: AppTextStyles.bodyLarge.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.bark.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                _getUrgencyLabel(listing.perishTier).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Pickup Location
                        _buildLocationCard(
                          'Pickup', 
                          listing.pickupAddress ?? 'lat ${listing.plotLocation.latitude.toStringAsFixed(4)}, lon ${listing.plotLocation.longitude.toStringAsFixed(4)}'
                        ),
                        const SizedBox(height: 16),
                        _buildLocationCard('Delivery', 'Producer Location · Pending Claim'),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimated Earnings', style: AppTextStyles.bodyLarge),
                            Text(
                              estimatedFee != null ? NumberFormat.simpleCurrency(decimalDigits: 0).format(estimatedFee) : 'Price TBD',
                              style: AppTextStyles.headlineLarge.copyWith(color: AppColors.moss),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: state is HaulAccepting
                              ? null
                              : () {
                                  context.read<HaulBloc>().add(AcceptHaul(listing.listingId));
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.moss),
                          child: state is HaulAccepting
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Accept Haul'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Decline', style: TextStyle(color: AppColors.stone)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationCard(String label, String value) {
    if (label == 'Delivery') {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.harvest),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
                  // FIX 2: Better FutureBuilder for delivery location
                  if (_currentListing?.producerId == null)
                    Text('Producer not assigned yet', style: AppTextStyles.titleLarge.copyWith(fontSize: 16))
                  else
                    FutureBuilder<DocumentSnapshot>(
                      future: _producerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Loading...');
                        }
                        if (snapshot.hasError) {
                          return const Text('Delivery location unavailable');
                        }
                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        final geoPoint = data?['geoPoint'] as GeoPoint?;
                        if (geoPoint == null) return const Text('Producer address not set');
                        return Text(
                          'lat ${geoPoint.latitude.toStringAsFixed(4)}, lon ${geoPoint.longitude.toStringAsFixed(4)}',
                          style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.harvest),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
                Text(value, style: AppTextStyles.titleLarge.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
