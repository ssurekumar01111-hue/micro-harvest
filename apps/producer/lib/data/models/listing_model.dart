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
    this.askingPricePerTon,
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

  factory ListingModel.fromMap(Map<String, dynamic> data, String id) {
    return ListingModel(
      listingId: id,
      growerId: data['growerId'] ?? '',
      cropType: data['cropType'] ?? 'UNKNOWN',
      containerType: data['containerType'] ?? 'UNKNOWN',
      containerCount: data['containerCount'] ?? 0,
      weightKg: (data['weightKg'] ?? 0).toDouble(),
      perishTier: PerishTier.values.firstWhere(
        (e) => e.name == data['perishTier'],
        orElse: () => PerishTier.HOURS_12,
      ),
      askingPriceUSD: (data['askingPriceUSD'] ?? 0).toDouble(),
      askingPricePerTon: (data['askingPricePerTon'] ?? data['askingPriceUSD'])?.toDouble(),
      plotLocation: _parseGeoPoint(data['plotLocation'] ?? data['location']),
      geohash: data['geohash'] ?? '',
      harvestWindowEnd: _parseDateTime(data['harvestWindowEnd']),
      status: ListingStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ListingStatus.OPEN,
      ),
      producerId: data['producerId'],
      transporterId: data['transporterId'],
      listingSource: data['listingSource'] ?? 'MANUAL',
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      matchedAt: data['matchedAt'] != null ? _parseDateTime(data['matchedAt']) : null,
    );
  }

  static GeoPoint _parseGeoPoint(dynamic data) {
    if (data is GeoPoint) return data;
    if (data is Map) {
      return GeoPoint(
        (data['lat'] ?? data['latitude'] ?? 0).toDouble(),
        (data['lon'] ?? data['longitude'] ?? 0).toDouble(),
      );
    }
    return const GeoPoint(0, 0);
  }

  static DateTime _parseDateTime(dynamic data) {
    if (data is Timestamp) return data.toDate();
    if (data is String) return DateTime.parse(data);
    if (data is int) return DateTime.fromMillisecondsSinceEpoch(data);
    return DateTime.now();
  }

  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    return ListingModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
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
      'listingSource': listingSource,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'matchedAt': matchedAt != null ? Timestamp.fromDate(matchedAt!) : null,
    };
  }
}
