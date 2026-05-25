part of 'elastic_monitor_bloc.dart';

sealed class ElasticMonitorState extends Equatable {
  const ElasticMonitorState();

  @override
  List<Object> get props => [];
}

final class ElasticMonitorInitial extends ElasticMonitorState {}

final class ElasticMonitorLoading extends ElasticMonitorState {}

final class ElasticMonitorLoaded extends ElasticMonitorState {
  final Map<String, dynamic> indexHealth;
  final List<dynamic> searchResults;
  final int searchTimeMs;
  final int totalSearchResults;
  final bool isSearching;

  const ElasticMonitorLoaded({
    required this.indexHealth,
    this.searchResults = const [],
    this.searchTimeMs = 0,
    this.totalSearchResults = 0,
    this.isSearching = false,
  });

  ElasticMonitorLoaded copyWith({
    Map<String, dynamic>? indexHealth,
    List<dynamic>? searchResults,
    int? searchTimeMs,
    int? totalSearchResults,
    bool? isSearching,
  }) {
    return ElasticMonitorLoaded(
      indexHealth: indexHealth ?? this.indexHealth,
      searchResults: searchResults ?? this.searchResults,
      searchTimeMs: searchTimeMs ?? this.searchTimeMs,
      totalSearchResults: totalSearchResults ?? this.totalSearchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object> get props => [
        indexHealth,
        searchResults,
        searchTimeMs,
        totalSearchResults,
        isSearching,
      ];
}

final class ElasticMonitorError extends ElasticMonitorState {
  final String message;

  const ElasticMonitorError({required this.message});

  @override
  List<Object> get props => [message];
}

