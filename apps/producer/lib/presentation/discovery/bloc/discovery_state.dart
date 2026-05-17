import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/listing_model.dart';

abstract class DiscoveryState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DiscoveryInitial extends DiscoveryState {}
class DiscoveryLoading extends DiscoveryState {}

class DiscoveryLoaded extends DiscoveryState {
  final List<ListingModel> listings;
  final GeoPoint producerLocation;
  final String? activeFilter;

  DiscoveryLoaded({
    required this.listings,
    required this.producerLocation,
    this.activeFilter,
  });

  @override
  List<Object?> get props => [listings, producerLocation, activeFilter];
}

class DiscoveryClaiming extends DiscoveryState {}

class DiscoveryClaimed extends DiscoveryState {
  final String listingId;
  DiscoveryClaimed(this.listingId);
  @override
  List<Object?> get props => [listingId];
}

class DiscoveryError extends DiscoveryState {
  final String message;
  DiscoveryError(this.message);
  @override
  List<Object?> get props => [message];
}
