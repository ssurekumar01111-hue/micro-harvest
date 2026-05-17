import 'package:cloud_firestore/cloud_firestore.dart';

enum CropType { PINOT_NOIR, CHARDONNAY, RIESLING, CABERNET, MERLOT, SAUVIGNON_BLANC }
enum ContainerType { MACRO_BIN, HALF_BIN, LUG_BOX, BULK_BAG }
enum PerishTier { HOURS_12, HOURS_24, DAYS_3, DAYS_7 }
enum ListingStatus { OPEN, MATCHED, LOCKED, IN_TRANSIT, DELIVERED, SETTLED, EXPIRED, DISPUTED }

class ListingModel {
  final String listingId;
  final String growerId;
  final CropType cropType;
  final ContainerType containerType;
  final int containerCount;
  final double weightKg;
  final PerishTier perishTier;
  final double askingPriceUSD;
  final GeoPoint plotLocation;
  final String geohash;
  final DateTime harvestWindowEnd;
  final ListingStatus status;
  final String? producerId;
  final String? transporterId;
  final String listingSource;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? matchedAt;

  ListingModel({
    required this.listingId,
    required this.growerId,
    required this.cropType,
    required this.containerType,
    required this.containerCount,
    required this.weightKg,
    required this.perishTier,
    required this.askingPriceUSD,
    required this.plotLocation,
    required this.geohash,
    required this.harvestWindowEnd,
    required this.status,
    this.producerId,
    this.transporterId,
    required this.listingSource,
    required this.createdAt,
    required this.updatedAt,
    this.matchedAt,
  });

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListingModel(
      listingId: doc.id,
      growerId: data['growerId'] ?? '',
      cropType: CropType.values.firstWhere((e) => e.name == data['cropType']),
      containerType: ContainerType.values.firstWhere((e) => e.name == data['containerType']),
      containerCount: data['containerCount'] ?? 0,
      weightKg: (data['weightKg'] ?? 0).toDouble(),
      perishTier: PerishTier.values.firstWhere((e) => e.name == data['perishTier']),
      askingPriceUSD: (data['askingPriceUSD'] ?? 0).toDouble(),
      plotLocation: data['plotLocation'] ?? const GeoPoint(0, 0),
      geohash: data['geohash'] ?? '',
      harvestWindowEnd: (data['harvestWindowEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: ListingStatus.values.firstWhere((e) => e.name == data['status']),
      producerId: data['producerId'],
      transporterId: data['transporterId'],
      listingSource: data['listingSource'] ?? 'MANUAL',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchedAt: (data['matchedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'growerId': growerId,
      'cropType': cropType.name,
      'containerType': containerType.name,
      'containerCount': containerCount,
      'weightKg': weightKg,
      'perishTier': perishTier.name,
      'askingPriceUSD': askingPriceUSD,
      'plotLocation': plotLocation,
      'geohash': geohash,
      'harvestWindowEnd': Timestamp.fromDate(harvestWindowEnd),
      'status': status.name,
      'producerId': producerId,
      'transporterId': transporterId,
      'listingSource': listingSource,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'matchedAt': matchedAt != null ? Timestamp.fromDate(matchedAt!) : null,
    };
  }
}
