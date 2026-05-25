import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/status_badge.dart';

class ListingDetailScreen extends StatelessWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('listings').doc(listingId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Listing not found'));
          }

          final listing = ListingModel.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(status: listing.status),
                    Text(
                      listing.askingPricePerTon != null
                          ? NumberFormat.currency(symbol: '\$').format(listing.askingPricePerTon)
                          : 'Price TBD',
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.moss, fontSize: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  ListingModel.cropDisplayName(listing.cropType),
                  style: AppTextStyles.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${listing.containerCount} ${ListingModel.containerDisplayName(listing.containerType)} • ${listing.weightKg}kg',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.stone),
                ),
                const SizedBox(height: 24),

                // Map View
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          listing.plotLocation.latitude,
                          listing.plotLocation.longitude,
                        ),
                        zoom: 13,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('plot'),
                          position: LatLng(
                            listing.plotLocation.latitude,
                            listing.plotLocation.longitude,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          infoWindow: InfoWindow(
                            title: ListingModel.cropDisplayName(listing.cropType),
                            snippet: '${listing.weightKg}kg',
                          ),
                        ),
                      },
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Text('Timeline', style: AppTextStyles.titleLarge),
                const SizedBox(height: 16),
                _buildTimelineItem('Listed', listing.createdAt, true),
                _buildTimelineItem(
                  'Matched with Producer',
                  null,
                  listing.status != ListingStatus.open,
                  extra: listing.producerId != null && listing.status != ListingStatus.open
                      ? UserInfoWidget(uid: listing.producerId!)
                      : null,
                ),
                _buildTimelineItem(
                  'Transporter Assigned',
                  null,
                  listing.status == ListingStatus.locked ||
                      listing.status == ListingStatus.inTransit ||
                      listing.status == ListingStatus.delivered ||
                      listing.status == ListingStatus.settled,
                  extra: listing.transporterId != null &&
                          (listing.status == ListingStatus.locked ||
                              listing.status == ListingStatus.inTransit ||
                              listing.status == ListingStatus.delivered ||
                              listing.status == ListingStatus.settled)
                      ? UserInfoWidget(uid: listing.transporterId!)
                      : null,
                ),
                _buildTimelineItem(
                  'Picked Up (Gate 1)',
                  null,
                  listing.status == ListingStatus.inTransit ||
                      listing.status == ListingStatus.delivered ||
                      listing.status == ListingStatus.settled,
                ),
                _buildTimelineItem(
                  'Delivered (Gate 2)',
                  null,
                  listing.status == ListingStatus.delivered || listing.status == ListingStatus.settled,
                ),
                _buildTimelineItem(
                  'Payment Settled',
                  null,
                  listing.status == ListingStatus.settled,
                  extra: listing.status == ListingStatus.settled
                      ? PaymentInfoWidget(listingId: listing.listingId)
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime? date, bool isCompleted, {Widget? extra}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? AppColors.moss : AppColors.stone,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    color: isCompleted ? AppColors.bark : AppColors.stone,
                  ),
                ),
                if (date != null)
                  Text(
                    DateFormat('MMM dd, hh:mm a').format(date),
                    style: const TextStyle(fontSize: 12, color: AppColors.stone),
                  ),
                if (extra != null) ...[
                  const SizedBox(height: 4),
                  extra,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserInfoWidget extends StatelessWidget {
  final String uid;
  const UserInfoWidget({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Text(
            'Details unavailable',
            style: TextStyle(fontSize: 12, color: AppColors.stone, fontStyle: FontStyle.italic),
          );
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['displayName'] ?? 'Unknown',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.bark),
            ),
            Text(
              data['phone'] ?? 'No phone',
              style: const TextStyle(fontSize: 12, color: AppColors.stone),
            ),
          ],
        );
      },
    );
  }
}

class PaymentInfoWidget extends StatelessWidget {
  final String listingId;
  const PaymentInfoWidget({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('handoffs')
          .where('listingId', isEqualTo: listingId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Payment info unavailable', style: TextStyle(fontSize: 12, color: AppColors.stone));
        }

        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final payment = data['payment'] as Map<String, dynamic>?;
        if (payment == null) return const Text('Payment pending', style: TextStyle(fontSize: 12, color: AppColors.stone));

        final growerShare = (payment['growerShareUSD'] ?? 0).toDouble();
        final releasedAt = (payment['releasedAt'] as Timestamp?)?.toDate();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your share: ${NumberFormat.currency(symbol: '\$').format(growerShare)} (80%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.moss),
            ),
            if (releasedAt != null)
              Text(
                'Settled on ${DateFormat('MMM dd, yyyy').format(releasedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.stone),
              ),
          ],
        );
      },
    );
  }
}
