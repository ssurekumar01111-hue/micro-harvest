import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/listing_model.dart';

class ListingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ListingModel>> getGrowerListings(String growerId) {
    return _firestore
        .collection('listings')
        .where('growerId', isEqualTo: growerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ListingModel.fromFirestore(doc)).toList();
    });
  }

  Future<ListingModel> getListingById(String listingId) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (doc.exists) {
      return ListingModel.fromFirestore(doc);
    }
    throw Exception('Listing not found');
  }
}
