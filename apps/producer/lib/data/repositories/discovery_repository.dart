import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';

class DiscoveryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ListingModel>> getNearbyListings({
    required GeoPoint producerLocation,
    required double radiusMiles,
    String? cropTypeFilter,
  }) {
    // Note: True geo-queries should use geohash, but for this MVP 
    // we'll filter OPEN status and sort by date.
    Query query = _firestore.collection('listings')
        .where('status', isEqualTo: ListingStatus.OPEN.name);

    if (cropTypeFilter != null && cropTypeFilter != 'All') {
      query = query.where('cropType', isEqualTo: cropTypeFilter);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ListingModel.fromFirestore(doc)).toList();
    });
  }
}
