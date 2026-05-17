import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/listing_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'status_badge.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;

  const ListingCard({super.key, required this.listing, this.onTap});

  String get _cropEmoji {
    switch (listing.cropType) {
      case CropType.PINOT_NOIR:
      case CropType.CABERNET:
      case CropType.MERLOT:
        return '🍇';
      case CropType.CHARDONNAY:
      case CropType.SAUVIGNON_BLANC:
      case CropType.RIESLING:
        return '🥂';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.cream2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_cropEmoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${listing.cropType.name.replaceAll('_', ' ')}',
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.containerCount} ${listing.containerType.name.replaceAll('_', ' ')} • ${listing.weightKg}kg',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: listing.status),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(listing.askingPriceUSD),
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 16, color: AppColors.moss),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
