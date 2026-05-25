import 'package:flutter/material.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class ActiveHaulCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onTap;

  const ActiveHaulCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ListingModel.cropDisplayName(listing.cropType),
                    style: AppTextStyles.titleLarge,
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${listing.weightKg.toStringAsFixed(0)} kg • ${listing.containerCount} ${ListingModel.containerDisplayName(listing.containerType)}',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
              ),
              const SizedBox(height: 16),
              _buildProgressIndicator(),
              if (listing.transporterId != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.local_shipping, size: 16, color: AppColors.moss),
                    const SizedBox(width: 8),
                    Text(
                      'Transporter Assigned',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.moss, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label = listing.status.name;
    
    switch (listing.status) {
      case ListingStatus.MATCHED:
        color = AppColors.wheat;
        break;
      case ListingStatus.LOCKED:
        color = AppColors.harvest;
        break;
      case ListingStatus.IN_TRANSIT:
        color = AppColors.moss;
        break;
      case ListingStatus.DELIVERED:
        color = Colors.orange;
        label = 'PROCESSING PAYMENT';
        break;
      case ListingStatus.SETTLED:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      default:
        color = AppColors.stone;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    int step = 0;
    if (listing.status == ListingStatus.MATCHED) step = 1;
    if (listing.transporterId != null) step = 2;
    if (listing.status == ListingStatus.IN_TRANSIT) step = 3;
    if (listing.status == ListingStatus.DELIVERED) step = 4;
    if (listing.status == ListingStatus.SETTLED) step = 5;

    return Column(
      children: [
        Row(
          children: List.generate(5, (index) {
            final isActive = index < step;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.moss : AppColors.stone.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _progressLabel('Claimed', step >= 1),
            _progressLabel('Assigned', step >= 2),
            _progressLabel('Transit', step >= 3),
            _progressLabel('Arrived', step >= 4),
            _progressLabel('Paid', step >= 5),
          ],
        ),
      ],
    );
  }

  Widget _progressLabel(String label, bool active) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: active ? AppColors.moss : AppColors.stone.withValues(alpha: 0.5),
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
