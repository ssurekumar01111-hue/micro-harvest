import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

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
                      listing.cropType.name.replaceAll('_', ' '),
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${listing.weightKg}kg • 12 miles away',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.rust.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('URGENT', style: TextStyle(color: AppColors.rust, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${(listing.askingPriceUSD / (listing.weightKg / 1000)).toStringAsFixed(0)}/t',
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
