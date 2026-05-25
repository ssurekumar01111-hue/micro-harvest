import 'package:cloud_firestore/cloud_firestore.dart';

enum PerishTier { HOURS_12, HOURS_24, DAYS_3, DAYS_7 }
enum ListingStatus { OPEN, MATCHED, LOCKED, IN_TRANSIT, DELIVERED, SETTLED, EXPIRED, DISPUTED }

class ListingModel {
  final String listingId;
  final String growerId;
  final String cropType;
  final String containerType;
  final int containerCount;
  final double weightKg;
  final PerishTier perishTier;
  final double askingPriceUSD;
  final double? askingPricePerTon;
  final GeoPoint plotLocation;
  final String geohash;
  final DateTime harvestWindowEnd;
  final ListingStatus status;
  final String? producerId;
  final String? transporterId;
  final String? growerName;
  final String? pickupAddress;
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
    required this.askingPricePerTon,
    required this.plotLocation,
    required this.geohash,
    required this.harvestWindowEnd,
    required this.status,
    this.producerId,
    this.transporterId,
    this.growerName,
    this.pickupAddress,
    required this.listingSource,
    required this.createdAt,
    required this.updatedAt,
    this.matchedAt,
  });

  static String cropDisplayName(String? cropType) {
    const map = {
      'PINOT_NOIR': 'Pinot Noir',
      'MERLOT': 'Merlot',
      'CABERNET': 'Cabernet',
      'CHARDONNAY': 'Chardonnay',
      'RIESLING': 'Riesling',
      'SAUVIGNON_BLANC': 'Sauvignon Blanc',
      'TOMATO': 'Tomato',
      'POTATO': 'Potato',
      'ONION': 'Onion',
      'MANGO': 'Mango',
      'WHEAT': 'Wheat',
      'RICE': 'Rice',
      'SUGARCANE': 'Sugarcane',
      'COTTON': 'Cotton',
      'SOYBEAN': 'Soybean',
      'CHICKPEA': 'Chickpea',
    };
    return map[cropType] ?? cropType ?? 'Unknown';
  }

  static String containerDisplayName(String? type) {
    const map = {
      'MACRO_BIN': 'Macro Bin',
      'HALF_BIN': 'Half Bin',
      'LUG_BOX': 'Lug Box',
      'BULK_BAG': 'Bulk Bag',
      'CRATE': 'Crate',
      'SACK': 'Sack',
      'QUINTAL': 'Quintal',
      'TROLLEY': 'Trolley',
    };
    return map[type] ?? type ?? 'Unknown';
  }

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Robust enum parsing
    final perishTier = PerishTier.values.asNameMap()[data['perishTier']] ?? PerishTier.HOURS_24;
    final status = ListingStatus.values.asNameMap()[data['status']] ?? ListingStatus.OPEN;

    return ListingModel(
      listingId: doc.id,
      growerId: data['growerId'] ?? '',
      cropType: data['cropType'] ?? 'UNKNOWN',
      containerType: data['containerType'] ?? 'UNKNOWN',
      containerCount: data['containerCount'] ?? 0,
      weightKg: (data['weightKg'] ?? 0).toDouble(),
      perishTier: perishTier,
      askingPriceUSD: (data['askingPriceUSD'] ?? 0).toDouble(),
      askingPricePerTon: (data['askingPricePerTon'] ?? data['askingPriceUSD'])?.toDouble(),
      plotLocation: data['plotLocation'] ?? const GeoPoint(0, 0),
      geohash: data['geohash'] ?? '',
      harvestWindowEnd: (data['harvestWindowEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: status,
      producerId: data['producerId'],
      transporterId: data['transporterId'],
      growerName: data['growerName'],
      pickupAddress: data['pickupAddress'],
      listingSource: data['listingSource'] ?? 'MANUAL',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      matchedAt: (data['matchedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'growerId': growerId,
      'cropType': cropType,
      'containerType': containerType,
      'containerCount': containerCount,
      'weightKg': weightKg,
      'perishTier': perishTier.name,
      'askingPriceUSD': askingPriceUSD,
      'askingPricePerTon': askingPricePerTon,
      'plotLocation': plotLocation,
      'geohash': geohash,
      'harvestWindowEnd': Timestamp.fromDate(harvestWindowEnd),
      'status': status.name,
      'producerId': producerId,
      'transporterId': transporterId,
      'growerName': growerName,
      'pickupAddress': pickupAddress,
      'listingSource': listingSource,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'matchedAt': matchedAt != null ? Timestamp.fromDate(matchedAt!) : null,
    };
  }
}
