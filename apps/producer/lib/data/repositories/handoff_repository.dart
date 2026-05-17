import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class HandoffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<void> claimListing(String listingId, String producerId) async {
    await _firestore.collection('listings').doc(listingId).update({
      'producerId': producerId,
      // The Cloud Function onProducerClaim will handle status transition to MATCHED
    });
  }

  Future<void> confirmGate2({
    required String handoffId,
    required String producerId,
    required GeoPoint gps,
    required File image,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final callable = _functions.httpsCallable('onGate2Confirm');
    await callable.call({
      'handoffId': handoffId,
      'producerId': producerId,
      'gps': {
        'latitude': gps.latitude,
        'longitude': gps.longitude,
      },
      'imageBase64': base64Image,
    });
  }

  Future<void> settleListing(String handoffId, String producerId) async {
    final callable = _functions.httpsCallable('onProducerSettle');
    await callable.call({
      'handoffId': handoffId,
      'producerId': producerId,
    });
  }

  Stream<List<Map<String, dynamic>>> getActiveHandoffs(String producerId) {
    return _firestore
        .collection('handoffs')
        .where('producerId', isEqualTo: producerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
