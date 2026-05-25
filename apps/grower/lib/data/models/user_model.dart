import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { grower, producer, transporter }

class UserModel {
  final String uid;
  final UserRole role;
  final String displayName;
  final String? farmName;
  final String phone;
  final String email;
  final GeoPoint geoPoint;
  final String geohash;
  final double radiusMiles;
  final List<String> cropInterests;
  final String? harvestSize;
  final String? stripeAcctId;
  final bool verified;
  final DateTime createdAt;
  final List<String> fcmTokens;
  final String availabilityStatus;
  final double totalEarned;
  final int totalHauled;
  final String? profileImageUrl;

  UserModel({
    required this.uid,
    required this.role,
    required this.displayName,
    this.farmName,
    required this.phone,
    required this.email,
    required this.geoPoint,
    required this.geohash,
    required this.radiusMiles,
    required this.cropInterests,
    this.harvestSize,
    this.stripeAcctId,
    required this.verified,
    required this.createdAt,
    required this.fcmTokens,
    this.availabilityStatus = 'AVAILABLE',
    this.totalEarned = 0.0,
    this.totalHauled = 0,
    this.profileImageUrl,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      role: UserRole.values.firstWhere(
        (e) => e.name.toUpperCase() == (data['role'] as String).toUpperCase(),
        orElse: () => UserRole.grower,
      ),
      displayName: data['displayName'] ?? '',
      farmName: data['farmName'],
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      geoPoint: data['geoPoint'] ?? const GeoPoint(0, 0),
      geohash: data['geohash'] ?? '',
      radiusMiles: (data['radiusMiles'] ?? 0).toDouble(),
      cropInterests: List<String>.from(data['cropInterests'] ?? []),
      harvestSize: data['harvestSize'],
      stripeAcctId: data['stripeAcctId'],
      verified: data['verified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      availabilityStatus: data['availabilityStatus'] ?? 'AVAILABLE',
      totalEarned: (data['totalEarned'] ?? 0.0).toDouble(),
      totalHauled: data['totalHauled'] ?? 0,
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'role': role.name.toUpperCase(),
      'displayName': displayName,
      'farmName': farmName,
      'phone': phone,
      'email': email,
      'geoPoint': geoPoint,
      'geohash': geohash,
      'radiusMiles': radiusMiles,
      'cropInterests': cropInterests,
      'harvestSize': harvestSize,
      'stripeAcctId': stripeAcctId,
      'verified': verified,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmTokens': fcmTokens,
      'availabilityStatus': availabilityStatus,
      'totalEarned': totalEarned,
      'totalHauled': totalHauled,
      'profileImageUrl': profileImageUrl,
    };
  }
}
