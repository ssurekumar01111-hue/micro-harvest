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
  final String? stripeAcctId;
  final bool verified;
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
    this.stripeAcctId,
    required this.verified,
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
      geoPoint: data['geoPoint'],
      geohash: data['geohash'] ?? '',
      radiusMiles: (data['radiusMiles'] ?? 0).toDouble(),
      stripeAcctId: data['stripeAcctId'],
      verified: data['verified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
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
      'stripeAcctId': stripeAcctId,
      'verified': verified,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmTokens': fcmTokens,
    };
  }
}
