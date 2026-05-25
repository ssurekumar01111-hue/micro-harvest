part of 'analytics_bloc.dart';

sealed class AnalyticsState extends Equatable {
  const AnalyticsState();

  @override
  List<Object> get props => [];
}

final class AnalyticsInitial extends AnalyticsState {}

final class AnalyticsLoading extends AnalyticsState {}

final class AnalyticsLoaded extends AnalyticsState {
  final Map<String, int> listingsCreatedLast30Days;
  final Map<String, double> revenueByCropType;
  final Map<String, int> usersByRole;
  final Map<String, int> handoffsByStatus;

  const AnalyticsLoaded({
    required this.listingsCreatedLast30Days,
    required this.revenueByCropType,
    required this.usersByRole,
    required this.handoffsByStatus,
  });

  @override
  List<Object> get props => [
        listingsCreatedLast30Days,
        revenueByCropType,
        usersByRole,
        handoffsByStatus,
      ];
}

final class AnalyticsError extends AnalyticsState {
  final String message;

  const AnalyticsError({required this.message});

  @override
  List<Object> get props => [message];
}

