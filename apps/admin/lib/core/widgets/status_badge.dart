import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin/core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return AppColors.moss; // Green
      case 'MATCHED':
      case 'DELIVERED':
        return Colors.blue;
      case 'LOCKED':
        return AppColors.harvest; // Orange
      case 'IN_TRANSIT':
        return Colors.purple;
      case 'SETTLED':
        return AppColors.stone; // Grey
      case 'EXPIRED':
      case 'DISPUTED':
        return AppColors.rust; // Red
      default:
        return AppColors.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

