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
  final Map<String, dynamic>? payment;
  final String? disputeStatus;

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
      payment: data['payment'],
      disputeStatus: data['disputeStatus'],
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
      'payment': payment,
      'disputeStatus': disputeStatus,
    };
  }
}
