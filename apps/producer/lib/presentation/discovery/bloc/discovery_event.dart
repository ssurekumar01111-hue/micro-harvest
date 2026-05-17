import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class DiscoveryEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDiscovery extends DiscoveryEvent {
  final GeoPoint location;
  final double radius;
  LoadDiscovery({required this.location, required this.radius});
  @override
  List<Object?> get props => [location, radius];
}

class FilterByCrop extends DiscoveryEvent {
  final String? cropType;
  FilterByCrop(this.cropType);
  @override
  List<Object?> get props => [cropType];
}

class RefreshDiscovery extends DiscoveryEvent {}

class ClaimListing extends DiscoveryEvent {
  final String listingId;
  ClaimListing(this.listingId);
  @override
  List<Object?> get props => [listingId];
}
