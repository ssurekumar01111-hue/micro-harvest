part of 'elastic_monitor_bloc.dart';

sealed class ElasticMonitorEvent extends Equatable {
  const ElasticMonitorEvent();

  @override
  List<Object> get props => [];
}

class LoadElasticStats extends ElasticMonitorEvent {}

class RunTestSearch extends ElasticMonitorEvent {
  final String query;
  final double radius;
  final double latitude;
  final double longitude;

  const RunTestSearch({
    required this.query,
    required this.radius,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object> get props => [query, radius, latitude, longitude];
}

class RefreshStats extends ElasticMonitorEvent {}

