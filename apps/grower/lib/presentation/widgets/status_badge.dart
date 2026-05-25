import 'package:flutter/material.dart';
import '../../data/models/listing_model.dart';

class StatusBadge extends StatelessWidget {
  final ListingStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ListingStatus.open:
        color = Colors.blue;
        break;
      case ListingStatus.matched:
        color = Colors.orange;
        break;
      case ListingStatus.locked:
        color = Colors.purple;
        break;
      case ListingStatus.inTransit:
        color = Colors.amber;
        break;
      case ListingStatus.delivered:
        color = Colors.teal;
        break;
      case ListingStatus.settled:
        color = Colors.green;
        break;
      case ListingStatus.expired:
        color = Colors.grey;
        break;
      case ListingStatus.disputed:
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status == ListingStatus.settled ? 'COMPLETED' : status.name.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
