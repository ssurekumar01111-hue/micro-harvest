import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HandoffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
