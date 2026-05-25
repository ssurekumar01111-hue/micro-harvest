import 'package:equatable/equatable.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/handoff_model.dart';

import '../../../../data/models/listing_model.dart';

abstract class DashboardState extends Equatable {
  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}
class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final UserModel user;
  final bool isAvailable;
  final HandoffModel? activeHandoff;
  final List<ListingModel> pendingHauls;
  final double todayEarnings;
  final int totalHauls;
  final double rating;

  DashboardLoaded({
    required this.user,
    required this.isAvailable,
    this.activeHandoff,
    this.pendingHauls = const [],
    required this.todayEarnings,
    required this.totalHauls,
    required this.rating,
  });

  @override
  List<Object?> get props => [user, isAvailable, activeHandoff, pendingHauls, todayEarnings, totalHauls, rating];
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
  @override
  List<Object?> get props => [message];
}
