import 'package:equatable/equatable.dart';
import '../../../../data/models/listing_model.dart';

abstract class HaulEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadAvailableHauls extends HaulEvent {}
class AcceptHaul extends HaulEvent {
  final String listingId;
  AcceptHaul(this.listingId);
  @override
  List<Object?> get props => [listingId];
}
class DeclineHaul extends HaulEvent {}

class FetchHaulDetails extends HaulEvent {
  final String listingId;
  FetchHaulDetails(this.listingId);
  @override
  List<Object?> get props => [listingId];
}

class HaulAlertReceived extends HaulEvent {
  final ListingModel listing;
  HaulAlertReceived(this.listing);
  @override
  List<Object?> get props => [listing];
}
