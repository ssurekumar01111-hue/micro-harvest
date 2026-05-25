import 'package:geolocator/geolocator.dart';
import 'package:dart_geohash/dart_geohash.dart';

class LocationRepository {
  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
  }

  Future<Position> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permissions are denied or service is disabled');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String computeGeohash(double lat, double lng) {
    return GeoHasher().encode(lng, lat, precision: 9);
  }

  double calculateDistance(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return Geolocator.distanceBetween(
      lat1, lng1, lat2, lng2,
    ) / 1609.34; // Convert to miles
  }
}
