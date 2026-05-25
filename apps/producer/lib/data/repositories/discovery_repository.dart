import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/listing_model.dart';

class DiscoveryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<List<ListingModel>> getNearbyListings(
    double lat, 
    double lon, {
    String? cropType,
    double radiusMiles = 50.0,
  }) async {
    try {
      final callable = _functions.httpsCallable('searchListings');
      final response = await callable.call({
        'lat': lat,
        'lon': lon,
        'radiusMiles': radiusMiles,
        if (cropType != null) 'cropType': cropType,
      });

      final data = response.data as Map<String, dynamic>;
      final hits = data['hits'] as List;

      return hits.map<ListingModel>((hit) {
        final hitMap = hit as Map<String, dynamic>;
        // Map fields from Elasticsearch format to ListingModel
        // ES format: { id, cropType, weightKg, urgency, askingPricePerTon, location: { lat, lon }, growerId, createdAt }
        return ListingModel(
          listingId: hitMap['id'],
          growerId: hitMap['growerId'],
          cropType: _parseCropType(hitMap['cropType']),
          weightKg: (hitMap['weightKg'] as num).toDouble(),
          containerType: 'BULK_BAG', // Default or map if available
          containerCount: 0, // Not currently indexed in search hit
          perishTier: _parsePerishTier(hitMap['urgency']),
          askingPriceUSD: (hitMap['askingPricePerTon'] as num?)?.toDouble() ?? 0.0,
          plotLocation: GeoPoint(
            hitMap['location']['lat'] as double,
            hitMap['location']['lon'] as double,
          ),
          geohash: '', // Not in search hit
          harvestWindowEnd: DateTime.now().add(const Duration(days: 7)), // Placeholder
          status: ListingStatus.OPEN,
          listingSource: 'ELASTICSEARCH',
          createdAt: DateTime.parse(hitMap['createdAt']),
          updatedAt: DateTime.parse(hitMap['createdAt']),
        );
      }).toList();
    } catch (e) {
      // Search failed, falling back to Firestore
      var query = _firestore
          .collection('listings')
          .where('status', isEqualTo: ListingStatus.OPEN.name);
      
      if (cropType != null) {
        query = query.where('cropType', isEqualTo: cropType);
      }

      final snapshot = await query.limit(20).get();
      return snapshot.docs
          .map((doc) => ListingModel.fromFirestore(doc))
          .toList();
    }
  }

  String _parseCropType(String value) {
    return ListingModel.cropTypes.contains(value) ? value : 'PINOT_NOIR';
  }

  PerishTier _parsePerishTier(String value) {
    return PerishTier.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PerishTier.HOURS_24,
    );
  }

  Future<void> claimListing(String listingId, String producerId) async {
    await _firestore.collection('listings').doc(listingId).update({
      'producerId': producerId,
      'status': 'MATCHED',
      'updatedAt': FieldValue.serverTimestamp(),
      'matchedAt': FieldValue.serverTimestamp(),
    });
  }
}
