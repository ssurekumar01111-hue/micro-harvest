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
      case 'PINOT_NOIR':
      case 'CABERNET':
      case 'MERLOT':
        return '🍇';
      case 'CHARDONNAY':
      case 'SAUVIGNON_BLANC':
      case 'RIESLING':
        return '🥂';
      case 'TOMATO':
        return '🍅';
      case 'POTATO':
        return '🥔';
      case 'ONION':
        return '🧅';
      case 'MANGO':
        return '🥭';
      case 'WHEAT':
      case 'RICE':
        return '🌾';
      case 'SUGARCANE':
        return '🎋';
      case 'COTTON':
        return '☁️';
      case 'SOYBEAN':
      case 'CHICKPEA':
        return '🫘';
      default:
        return '🌱';
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
                      ListingModel.cropDisplayName(listing.cropType),
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
                  Builder(
                    builder: (context) {
                      final pricePerTon = (listing.askingPricePerTon != null && listing.askingPricePerTon! > 0)
                          ? listing.askingPricePerTon!
                          : (listing.weightKg > 0 ? listing.askingPriceUSD / (listing.weightKg / 1000) : 0.0);

                      final weightTons = listing.weightKg / 1000;
                      final totalPrice = pricePerTon * weightTons;

                      if (pricePerTon <= 0) {
                        return Text(
                          'Price TBD',
                          style: AppTextStyles.titleLarge.copyWith(fontSize: 16, color: AppColors.stone),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${totalPrice.toStringAsFixed(0)} total',
                            style: AppTextStyles.titleLarge.copyWith(fontSize: 16, color: AppColors.moss),
                          ),
                          Text(
                            '\$${pricePerTon.toStringAsFixed(0)}/ton',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone, fontSize: 12),
                          ),
                        ],
                      );
                    },
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
