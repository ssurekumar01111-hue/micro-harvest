import 'package:equatable/equatable.dart';
import '../../../../data/models/listing_model.dart';

abstract class ListingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadListings extends ListingsEvent {}

class FilterListings extends ListingsEvent {
  final ListingStatus? status;
  FilterListings(this.status);
  @override
  List<Object?> get props => [status];
}
