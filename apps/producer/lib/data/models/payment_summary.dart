class PaymentSummary {
  final double totalAmountUsd;
  final double growerShare;
  final double transporterShare;
  final double platformFee;

  PaymentSummary({
    required this.totalAmountUsd,
    required this.growerShare,
    required this.transporterShare,
    required this.platformFee,
  });

  factory PaymentSummary.calculate({
    required double weightKg,
    required double askingPricePerTon,
  }) {
    final totalUsd = (weightKg / 1000) * askingPricePerTon;
    return PaymentSummary(
      totalAmountUsd: totalUsd,
      growerShare: totalUsd * 0.80,
      transporterShare: totalUsd * 0.15,
      platformFee: totalUsd * 0.05,
    );
  }

  factory PaymentSummary.fromMap(Map<String, dynamic> map) {
    return PaymentSummary(
      totalAmountUsd: (map['totalAmountUsd'] as num).toDouble(),
      growerShare: (map['growerShare'] as num).toDouble(),
      transporterShare: (map['transporterShare'] as num).toDouble(),
      platformFee: (map['platformFee'] as num).toDouble(),
    );
  }
}
