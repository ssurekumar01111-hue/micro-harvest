import 'package:equatable/equatable.dart';
import '../../../../data/models/listing_model.dart';

abstract class ListingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ListingsInitial extends ListingsState {}
class ListingsLoading extends ListingsState {}

class ListingsLoaded extends ListingsState {
  final List<ListingModel> listings;
  final ListingStatus? filteredStatus;
  ListingsLoaded({required this.listings, this.filteredStatus});
  @override
  List<Object?> get props => [listings, filteredStatus];
}

class ListingsError extends ListingsState {
  final String message;
  ListingsError(this.message);
  @override
  List<Object?> get props => [message];
}
