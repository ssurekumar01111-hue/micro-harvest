import 'package:equatable/equatable.dart';
import '../../../../data/models/listing_model.dart';
import '../../../../data/models/user_model.dart';

abstract class DashboardState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final UserModel user;
  final List<ListingModel> listings;
  final Map<String, dynamic> stats;

  DashboardLoaded({
    required this.user,
    required this.listings,
    required this.stats,
  });

  @override
  List<Object?> get props => [user, listings, stats];
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
