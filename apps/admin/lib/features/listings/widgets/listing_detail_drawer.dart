import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/status_badge.dart';
import 'package:admin/features/listings/bloc/listings_bloc.dart';

class ListingDetailDrawer extends StatelessWidget {
  final Map<String, dynamic> listing;

  const ListingDetailDrawer({super.key, required this.listing});

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  String _formatCurrency(double amount) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_US');
    return formatCurrency.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Listing Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  context.read<ListingsBloc>().add(const SelectListing(listing: null));
                },
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Listing ID:', listing['id'] ?? 'N/A'),
                  _buildDetailRow('Crop Type:', listing['cropType'] ?? 'N/A'),
                  _buildDetailRow('Weight:', '${listing['weightKg'] ?? 'N/A'} kg'),
                  _buildDetailRow('Containers:', listing['containers']?.toString() ?? 'N/A'),
                  _buildDetailRow(
                    'Status:',
                    StatusBadge(status: listing['status'] ?? 'N/A'),
                  ),
                  _buildDetailRow('Grower Name:', listing['growerName'] ?? 'N/A'),
                  _buildDetailRow('Producer Name:', listing['producerName'] ?? 'N/A'),
                  _buildDetailRow('Price/Ton:', _formatCurrency((listing['pricePerTon'] as num?)?.toDouble() ?? 0.0)),
                  _buildDetailRow('Created At:', _formatDateTime(listing['createdAt'] as Timestamp?)),
                  _buildDetailRow('Expires At:', _formatDateTime(listing['expiresAt'] as Timestamp?)),
                  _buildDetailRow('Gate 1 Time:', _formatDateTime(listing['gate1Time'] as Timestamp?)),
                  _buildDetailRow('Gate 2 Time:', _formatDateTime(listing['gate2Time'] as Timestamp?)),
                  _buildDetailRow('Pickup Lat:', listing['pickupLat']?.toString() ?? 'N/A'),
                  _buildDetailRow('Pickup Lng:', listing['pickupLng']?.toString() ?? 'N/A'),
                  _buildDetailRow('Pickup Address:', listing['pickupAddress'] ?? 'N/A'),
                  _buildDetailRow('Destination Lat:', listing['destinationLat']?.toString() ?? 'N/A'),
                  _buildDetailRow('Destination Lng:', listing['destinationLng']?.toString() ?? 'N/A'),
                  _buildDetailRow('Destination Address:', listing['destinationAddress'] ?? 'N/A'),
                  _buildDetailRow('Matched Handoff ID:', listing['matchedHandoffId'] ?? 'N/A'),
                  // Add more fields as needed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.bold,
                color: AppColors.bark,
              ),
            ),
          ),
          Expanded(
            child: value is Widget
                ? value
                : Text(
                    value.toString(),
                    style: GoogleFonts.dmSans(
                      color: AppColors.bark.withValues(alpha: 0.8),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

