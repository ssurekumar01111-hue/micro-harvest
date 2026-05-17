import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/listing_model.dart';
import '../models/handoff_model.dart';

class HaulRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Stream<List<ListingModel>> getAvailableHauls({
    required GeoPoint transporterLocation,
    required double radiusMiles,
  }) {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: ListingStatus.MATCHED.name)
        .where('transporterId', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ListingModel.fromFirestore(doc)).toList());
  }

  Future<void> acceptHaul(String listingId, String transporterId) async {
    final callable = _functions.httpsCallable('onTransporterAccept');
    await callable.call({
      'listingId': listingId,
      'transporterId': transporterId,
    });
  }

  Future<void> confirmGate1({
    required String handoffId,
    required String transporterId,
    required GeoPoint gps,
    required File image,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final callable = _functions.httpsCallable('onGate1Confirm');
    await callable.call({
      'handoffId': handoffId,
      'transporterId': transporterId,
      'gps': {
        'latitude': gps.latitude,
        'longitude': gps.longitude,
      },
      'imageBase64': base64Image,
    });
  }

  Future<void> confirmGate2({
    required String handoffId,
    required String transporterId,
    required GeoPoint gps,
    required File image,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final callable = _functions.httpsCallable('onGate2Confirm');
    await callable.call({
      'handoffId': handoffId,
      'transporterId': transporterId,
      'gps': {
        'latitude': gps.latitude,
        'longitude': gps.longitude,
      },
      'imageBase64': base64Image,
    });
  }

  Stream<HandoffModel?> getActiveHandoff(String transporterId) {
    return _firestore
        .collection('handoffs')
        .where('transporterId', isEqualTo: transporterId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      // Filter for LOCKED or IN_TRANSIT in app logic or better query
      final handoffs = snapshot.docs.map((doc) => HandoffModel.fromFirestore(doc)).toList();
      // Simplified: just return the first one for now
      return handoffs.first;
    });
  }

  Future<void> updateAvailability(String transporterId, bool isAvailable) async {
    await _firestore.collection('users').doc(transporterId).update({
      'availabilityStatus': isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
    });
  }

  Stream<List<HandoffModel>> getHaulHistory(String transporterId) {
    return _firestore
        .collection('handoffs')
        .where('transporterId', isEqualTo: transporterId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => HandoffModel.fromFirestore(doc)).toList());
  }
}
