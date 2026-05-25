import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { GROWER, PRODUCER, TRANSPORTER }

class UserModel {
  final String uid;
  final UserRole role;
  final String displayName;
  final String phone;
  final GeoPoint geoPoint;
  final String geohash;
  final double radiusMiles;
  final List<String> cropInterests;
  final String? stripeAcctId;
  final bool verified;
  final bool onboardingComplete;
  final DateTime createdAt;
  final List<String> fcmTokens;

  UserModel({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.phone,
    required this.geoPoint,
    required this.geohash,
    required this.radiusMiles,
    required this.cropInterests,
    this.stripeAcctId,
    required this.verified,
    this.onboardingComplete = false,
    required this.createdAt,
    required this.fcmTokens,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      role: UserRole.values.firstWhere((e) => e.name == data['role']),
      displayName: data['displayName'] ?? '',
      phone: data['phone'] ?? '',
      geoPoint: data['geoPoint'] ?? const GeoPoint(0, 0),
      geohash: data['geohash'] ?? '',
      radiusMiles: (data['radiusMiles'] ?? 0).toDouble(),
      cropInterests: List<String>.from(data['cropInterests'] ?? []),
      stripeAcctId: data['stripeAcctId'],
      verified: data['verified'] ?? false,
      onboardingComplete: data['onboardingComplete'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.name,
      'displayName': displayName,
      'phone': phone,
      'geoPoint': geoPoint,
      'geohash': geohash,
      'radiusMiles': radiusMiles,
      'cropInterests': cropInterests,
      'stripeAcctId': stripeAcctId,
      'verified': verified,
      'onboardingComplete': onboardingComplete,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmTokens': fcmTokens,
    };
  }
}
