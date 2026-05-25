import 'package:cloud_firestore/cloud_firestore.dart';

enum PerishTier { hours12, hours24, days3, days7 }
enum ListingStatus { open, matched, locked, inTransit, delivered, settled, expired, disputed }

class ListingModel {
  final String listingId;
  final String growerId;
  final String cropType;
  final String containerType;
  final int containerCount;
  final double weightKg;
  final PerishTier perishTier;
  final double? askingPricePerTon;
  final GeoPoint plotLocation;
  final String geohash;
  final DateTime harvestWindowEnd;
  final ListingStatus status;
  final String? producerId;
  final String? transporterId;
  final String listingSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  ListingModel({
    required this.listingId,
    required this.growerId,
    required this.cropType,
    required this.containerType,
    required this.containerCount,
    required this.weightKg,
    required this.perishTier,
    required this.askingPricePerTon,
    required this.plotLocation,
    required this.geohash,
    required this.harvestWindowEnd,
    required this.status,
    this.producerId,
    this.transporterId,
    required this.listingSource,
    required this.createdAt,
    required this.updatedAt,
  });

  static const List<String> cropTypes = [
    'PINOT_NOIR',
    'MERLOT',
    'CABERNET',
    'CHARDONNAY',
    'RIESLING',
    'SAUVIGNON_BLANC',
    'TOMATO',
    'POTATO',
    'ONION',
    'MANGO',
    'WHEAT',
    'RICE',
    'SUGARCANE',
    'COTTON',
    'SOYBEAN',
    'CHICKPEA',
  ];

  static const List<String> containerTypes = [
    'MACRO_BIN',
    'HALF_BIN',
    'LUG_BOX',
    'BULK_BAG',
    'CRATE',
    'SACK',
    'QUINTAL',
    'TROLLEY',
  ];

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
    return ListingModel(
      listingId: doc.id,
      growerId: data['growerId'] ?? '',
      cropType: data['cropType'] ?? 'UNKNOWN',
      containerType: data['containerType'] ?? 'UNKNOWN',
      containerCount: data['containerCount'] ?? 0,
      weightKg: (data['weightKg'] ?? 0).toDouble(),
      perishTier: PerishTier.values.firstWhere(
        (e) => e.name.replaceAll('_', '').toUpperCase() == (data['perishTier'] as String).replaceAll('_', '').toUpperCase(),
        orElse: () => PerishTier.hours24,
      ),
      askingPricePerTon: (data['askingPricePerTon'] ?? data['askingPriceUSD'])?.toDouble(),
      plotLocation: data['plotLocation'],
      geohash: data['geohash'] ?? '',
      harvestWindowEnd: (data['harvestWindowEnd'] as Timestamp).toDate(),
      status: ListingStatus.values.firstWhere(
        (e) => e.name.replaceAll('_', '').toUpperCase() == (data['status'] as String).replaceAll('_', '').toUpperCase(),
        orElse: () => ListingStatus.open,
      ),
      producerId: data['producerId'],
      transporterId: data['transporterId'],
      listingSource: data['listingSource'] ?? 'MANUAL',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'growerId': growerId,
      'cropType': cropType,
      'containerType': containerType,
      'containerCount': containerCount,
      'weightKg': weightKg,
      'perishTier': perishTier.name.toUpperCase(),
      'askingPricePerTon': askingPricePerTon,
      'plotLocation': plotLocation,
      'geohash': geohash,
      'harvestWindowEnd': Timestamp.fromDate(harvestWindowEnd),
      'status': status.name.toUpperCase(),
      'producerId': producerId,
      'transporterId': transporterId,
      'listingSource': listingSource,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
