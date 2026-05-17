import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/listings_bloc.dart';
import '../bloc/listings_state.dart';
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
      appBar: AppBar(
        title: const Text('Listing Details'),
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<ListingsBloc, ListingsState>(
        builder: (context, state) {
          if (state is ListingsLoaded) {
            final listing = state.listings.firstWhere((l) => l.listingId == listingId);
            
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
                        NumberFormat.currency(symbol: '\$').format(listing.askingPriceUSD),
                        style: AppTextStyles.headlineLarge.copyWith(color: AppColors.moss, fontSize: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${listing.cropType.name.replaceAll('_', ' ')}',
                    style: AppTextStyles.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${listing.containerCount} ${listing.containerType.name.replaceAll('_', ' ')} • ${listing.weightKg}kg',
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.stone),
                  ),
                  const SizedBox(height: 40),
                  Text('Timeline', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 16),
                  _buildTimelineItem('Created', listing.createdAt, true),
                  _buildTimelineItem('Matched with Producer', null, listing.status != ListingStatus.OPEN),
                  _buildTimelineItem('Transporter Assigned', null, listing.status == ListingStatus.LOCKED || listing.status == ListingStatus.IN_TRANSIT || listing.status == ListingStatus.DELIVERED || listing.status == ListingStatus.SETTLED),
                  _buildTimelineItem('Picked Up (Gate 1)', null, listing.status == ListingStatus.IN_TRANSIT || listing.status == ListingStatus.DELIVERED || listing.status == ListingStatus.SETTLED),
                  _buildTimelineItem('Delivered (Gate 2)', null, listing.status == ListingStatus.DELIVERED || listing.status == ListingStatus.SETTLED),
                  _buildTimelineItem('Payment Settled', null, listing.status == ListingStatus.SETTLED),
                ],
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime? date, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? AppColors.moss : AppColors.stone,
          ),
          const SizedBox(width: 16),
          Column(
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
            ],
          ),
        ],
      ),
    );
  }
}
