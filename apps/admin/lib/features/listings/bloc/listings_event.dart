part of 'listings_bloc.dart';

sealed class ListingsEvent extends Equatable {
  const ListingsEvent();

  @override
  List<Object> get props => [];
}

class LoadListings extends ListingsEvent {}

class FilterListings extends ListingsEvent {
  final String? status;
  final String? cropType;
  final String? query; // for grower name

  const FilterListings({this.status, this.cropType, this.query});

  @override
  List<Object> get props => [status ?? '', cropType ?? '', query ?? ''];
}

class ForceExpireListing extends ListingsEvent {
  final String listingId;

  const ForceExpireListing({required this.listingId});

  @override
  List<Object> get props => [listingId];
}

class LoadNextPage extends ListingsEvent {}

class SelectListing extends ListingsEvent {
  final Map<String, dynamic>? listing;

  const SelectListing({this.listing});

  @override
  List<Object> get props => [listing ?? {}];
}

// Internal event to update state from stream
class _ListingsUpdated extends ListingsEvent {
  final List<Map<String, dynamic>> listings;
  final DocumentSnapshot? lastDoc;

  const _ListingsUpdated({required this.listings, this.lastDoc});

  @override
  List<Object> get props => [listings, lastDoc ?? Object()];
}

