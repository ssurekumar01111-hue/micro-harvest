part of 'analytics_bloc.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();

  @override
  List<Object> get props => [];
}

class LoadAnalytics extends AnalyticsEvent {}

class RefreshAnalytics extends AnalyticsEvent {}

