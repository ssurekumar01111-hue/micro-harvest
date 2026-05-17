import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<GeoPoint> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition();
    return GeoPoint(position.latitude, position.longitude);
  }

  Stream<GeoPoint> locationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).map((position) => GeoPoint(position.latitude, position.longitude));
  }

  Future<void> broadcastLocation(String transporterId, GeoPoint location) async {
    await _firestore.collection('users').doc(transporterId).update({
      'geoPoint': location,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
