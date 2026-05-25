import 'package:cloud_firestore/cloud_firestore.dart';

class HandoffModel {
  final String handoffId;
  final String listingId;
  final String growerId;
  final String producerId;
  final String transporterId;
  final String contractHash;
  final Map<String, dynamic>? gate1;
  final Map<String, dynamic>? gate2;
  final HandoffPayment? payment;
  final String? disputeStatus;
  final double weightKg;

  HandoffModel({
    required this.handoffId,
    required this.listingId,
    required this.growerId,
    required this.producerId,
    required this.transporterId,
    required this.contractHash,
    this.gate1,
    this.gate2,
    this.payment,
    this.disputeStatus,
    required this.weightKg,
  });

  factory HandoffModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HandoffModel(
      handoffId: doc.id,
      listingId: data['listingId'] ?? '',
      growerId: data['growerId'] ?? '',
      producerId: data['producerId'] ?? '',
      transporterId: data['transporterId'] ?? '',
      contractHash: data['contractHash'] ?? '',
      gate1: data['gate1'],
      gate2: data['gate2'],
      payment: data['payment'] != null ? HandoffPayment.fromMap(data['payment']) : null,
      disputeStatus: data['disputeStatus'],
      weightKg: (data['weightKg'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'growerId': growerId,
      'producerId': producerId,
      'transporterId': transporterId,
      'contractHash': contractHash,
      'gate1': gate1,
      'gate2': gate2,
      'payment': payment?.toMap(),
      'disputeStatus': disputeStatus,
      'weightKg': weightKg,
    };
  }
}

class HandoffPayment {
  final double totalUSD;
  final double growerShareUSD;
  final double transporterFeeUSD;
  final double platformFeeUSD;
  final String? stripePaymentId;
  final String? stripeClientSecret;
  final DateTime? releasedAt;

  HandoffPayment({
    required this.totalUSD,
    required this.growerShareUSD,
    required this.transporterFeeUSD,
    required this.platformFeeUSD,
    this.stripePaymentId,
    this.stripeClientSecret,
    this.releasedAt,
  });

  factory HandoffPayment.fromMap(Map<String, dynamic> map) {
    return HandoffPayment(
      totalUSD: (map['totalUSD'] ?? 0).toDouble(),
      growerShareUSD: (map['growerShareUSD'] ?? 0).toDouble(),
      transporterFeeUSD: (map['transporterFeeUSD'] ?? 0).toDouble(),
      platformFeeUSD: (map['platformFeeUSD'] ?? 0).toDouble(),
      stripePaymentId: map['stripePaymentId'],
      stripeClientSecret: map['stripeClientSecret'],
      releasedAt: (map['releasedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalUSD': totalUSD,
      'growerShareUSD': growerShareUSD,
      'transporterFeeUSD': transporterFeeUSD,
      'platformFeeUSD': platformFeeUSD,
      'stripePaymentId': stripePaymentId,
      'stripeClientSecret': stripeClientSecret,
      'releasedAt': releasedAt != null ? Timestamp.fromDate(releasedAt!) : null,
    };
  }
}
