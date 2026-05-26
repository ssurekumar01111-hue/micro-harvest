class ElasticListing {
  final String id;
  final String cropType;
  final double weightKg;
  final String urgency;
  final double askingPricePerTon;
  final Map<String, dynamic> location;
  final String growerId;
  final dynamic createdAt;
  final double? distance;

  ElasticListing({
    required this.id,
    required this.cropType,
    required this.weightKg,
    required this.urgency,
    required this.askingPricePerTon,
    required this.location,
    required this.growerId,
    required this.createdAt,
    this.distance,
  });

  factory ElasticListing.fromJson(Map<String, dynamic> json) {
    return ElasticListing(
      id: json['id'] as String? ?? 'N/A',
      cropType: json['cropType'] as String? ?? 'UNKNOWN',
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      urgency: json['urgency'] as String? ?? 'N/A',
      askingPricePerTon: (json['askingPricePerTon'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] != null 
        ? json['location'] as Map<String, dynamic> 
        : {},
      growerId: json['growerId'] as String? ?? 'N/A',
      createdAt: json['createdAt'],
      distance: (json['distance'] as num?)?.toDouble(),
    );
  }
}
