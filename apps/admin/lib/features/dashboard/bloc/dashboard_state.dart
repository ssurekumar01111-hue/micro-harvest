part of 'dashboard_bloc.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object> get props => [];
}

final class DashboardInitial extends DashboardState {}

final class DashboardLoading extends DashboardState {}

final class DashboardLoaded extends DashboardState {
  final int totalListings;
  final int activeListings;
  final int settledListings;
  final int totalHandoffs;
  final int totalGrowers;
  final int totalProducers;
  final int totalTransporters;
  final double totalRevenueUsd;
  final double platformFeesUsd;
  final int registeredUsers;
  final List<Map<String, dynamic>> recentListings;
  final List<Map<String, dynamic>> recentHandoffs;

  const DashboardLoaded({
    required this.totalListings,
    required this.activeListings,
    required this.settledListings,
    required this.totalHandoffs,
    required this.totalGrowers,
    required this.totalProducers,
    required this.totalTransporters,
    required this.totalRevenueUsd,
    required this.platformFeesUsd,
    required this.registeredUsers,
    required this.recentListings,
    required this.recentHandoffs,
  });

  @override
  List<Object> get props => [
        totalListings,
        activeListings,
        settledListings,
        totalHandoffs,
        totalGrowers,
        totalProducers,
        totalTransporters,
        totalRevenueUsd,
        platformFeesUsd,
        registeredUsers,
        recentListings,
        recentHandoffs,
      ];
}

final class DashboardError extends DashboardState {
  final String message;

  const DashboardError({required this.message});

  @override
  List<Object> get props => [message];
}
