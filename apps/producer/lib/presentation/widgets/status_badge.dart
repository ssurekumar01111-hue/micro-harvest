import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final ListingStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ListingStatus.OPEN: color = AppColors.moss; break;
      case ListingStatus.MATCHED: color = AppColors.wheat; break;
      case ListingStatus.LOCKED: color = AppColors.rust; break;
      case ListingStatus.IN_TRANSIT: color = AppColors.harvest; break;
      case ListingStatus.DELIVERED: color = AppColors.moss2; break;
      case ListingStatus.SETTLED: color = AppColors.soil; break;
      case ListingStatus.EXPIRED: color = AppColors.stone; break;
      case ListingStatus.DISPUTED: color = AppColors.rust; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.name,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
