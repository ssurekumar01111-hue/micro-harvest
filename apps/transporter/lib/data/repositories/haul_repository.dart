import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/listing_model.dart';
import '../models/handoff_model.dart';

class HaulRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
    final imageHash = sha256.convert(bytes).toString();

    // Upload to Storage
    final ref = _storage.ref().child('handoffs/$handoffId/gate1.jpg');
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    final imageUrl = await ref.getDownloadURL();

    final callable = _functions.httpsCallable('onGate1Confirm');
    await callable.call({
      'handoffId': handoffId,
      'transporterId': transporterId,
      'gps': {
        'latitude': gps.latitude,
        'longitude': gps.longitude,
      },
      'imageUrl': imageUrl,
      'imageHash': imageHash,
    });
  }

  Future<void> confirmGate2({
    required String handoffId,
    required String producerId,
    required GeoPoint gps,
    required File image,
  }) async {
    final bytes = await image.readAsBytes();
    final imageHash = sha256.convert(bytes).toString();

    // Upload to Storage
    final ref = _storage.ref().child('handoffs/$handoffId/gate2.jpg');
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    final imageUrl = await ref.getDownloadURL();

    final callable = _functions.httpsCallable('onGate2Confirm');
    await callable.call({
      'handoffId': handoffId,
      'producerId': producerId,
      'gps': {
        'latitude': gps.latitude,
        'longitude': gps.longitude,
      },
      'imageUrl': imageUrl,
      'imageHash': imageHash,
    });
  }

  Stream<HandoffModel?> getActiveHandoff(String transporterId) {
    return _firestore
        .collection('handoffs')
        .where('transporterId', isEqualTo: transporterId)
        .where('gate2', isNull: true) // Filter out handoffs where gate2 (delivery) is already done
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final handoffs = snapshot.docs.map((doc) => HandoffModel.fromFirestore(doc)).toList();
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
        .where('gate2', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => HandoffModel.fromFirestore(doc)).toList());
  }

  Stream<List<ListingModel>> getIncomingHaulRequests(String transporterId) {
    return _firestore
        .collection('listings')
        .where('status', isEqualTo: ListingStatus.MATCHED.name)
        .where('transporterId', isNull: true)
        .where('matchedTransporterIds', arrayContains: transporterId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ListingModel.fromFirestore(doc)).toList());
  }

  Future<HandoffModel> getHandoff(String handoffId) async {
    final doc = await _firestore.collection('handoffs').doc(handoffId).get();
    if (!doc.exists) {
      throw Exception('Handoff not found');
    }
    return HandoffModel.fromFirestore(doc);
  }

  Future<ListingModel> getListing(String listingId) async {
    final doc = await _firestore.collection('listings').doc(listingId).get();
    if (!doc.exists) {
      throw Exception('Listing not found');
    }
    return ListingModel.fromFirestore(doc);
  }

  Stream<Map<String, dynamic>> getTransporterStats(String transporterId) {
    return _firestore
        .collection('handoffs')
        .where('transporterId', isEqualTo: transporterId)
        .where('gate2', isNotEqualTo: null)
        .snapshots()
        .map((snapshot) {
      double todayEarnings = 0;
      int totalHauls = snapshot.docs.length;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final payment = data['payment'] as Map<String, dynamic>?;
        final gate2 = data['gate2'] as Map<String, dynamic>?;
        
        if (payment != null && gate2 != null) {
          final confirmedAt = (gate2['confirmedAt'] as Timestamp).toDate();
          final fee = (payment['transporterFeeUSD'] ?? 0).toDouble();
          
          if (confirmedAt.isAfter(todayStart)) {
            todayEarnings += fee;
          }
        }
      }

      return {
        'todayEarnings': todayEarnings,
        'totalHauls': totalHauls,
      };
    });
  }
}
