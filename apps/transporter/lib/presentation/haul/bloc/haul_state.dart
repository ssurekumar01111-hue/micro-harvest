import 'package:equatable/equatable.dart';
import '../../../../data/models/listing_model.dart';

abstract class HaulState extends Equatable {
  @override
  List<Object?> get props => [];
}

class HaulInitial extends HaulState {}
class HaulLoading extends HaulState {}

class HaulLoaded extends HaulState {
  final ListingModel listing;
  HaulLoaded(this.listing);
  @override
  List<Object?> get props => [listing];
}

class HaulAlertsLoaded extends HaulState {
  final List<ListingModel> hauls;
  HaulAlertsLoaded(this.hauls);
  @override
  List<Object?> get props => [hauls];
}

class HaulAccepting extends HaulState {}

class HaulAccepted extends HaulState {
  final String handoffId;
  HaulAccepted(this.handoffId);
  @override
  List<Object?> get props => [handoffId];
}

class HaulError extends HaulState {
  final String message;
  HaulError(this.message);
  @override
  List<Object?> get props => [message];
}
