import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/elastic_listing.dart';

part 'elastic_monitor_event.dart';
part 'elastic_monitor_state.dart';

class ElasticMonitorBloc extends Bloc<ElasticMonitorEvent, ElasticMonitorState> {
  final FirebaseFunctions _functions;

  ElasticMonitorBloc({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-south1'),
        super(ElasticMonitorInitial()) {
    on<LoadElasticStats>(_onLoadElasticStats);
    on<RunTestSearch>(_onRunTestSearch);
    on<RefreshStats>(_onRefreshStats);
  }

  Future<void> _onLoadElasticStats(
      LoadElasticStats event, Emitter<ElasticMonitorState> emit) async {
    emit(ElasticMonitorLoading());
    try {
      final HttpsCallable callable = _functions.httpsCallable('getElasticStats');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;
      final indexHealth = {
        'totalDocuments': data['listingsIndexed'] ?? 0,
        'usersIndexed': data['usersIndexed'] ?? 0,
        'lastIndexedAt': DateTime.now().toIso8601String(),
        'responseTimeMs': 0,
        'isHealthy': data['clusterHealth'] == 'green' || data['clusterHealth'] == 'yellow',
        'status': data['clusterHealth'] ?? 'unknown',
      };

      emit(ElasticMonitorLoaded(indexHealth: indexHealth));
    } catch (e) {
      emit(ElasticMonitorError(message: e.toString()));
    }
  }

  Future<void> _onRunTestSearch(
      RunTestSearch event, Emitter<ElasticMonitorState> emit) async {
    if (state is! ElasticMonitorLoaded) return;
    final currentState = state as ElasticMonitorLoaded;

    emit(currentState.copyWith(isSearching: true));
    try {
      final HttpsCallable callable = _functions.httpsCallable('searchListings');
      final result = await callable.call({
        'cropType': event.query.isEmpty ? null : event.query.toUpperCase(),
        'radiusMiles': event.radius,
        'lat': event.latitude,
        'lon': event.longitude,
      });

      final data = result.data as Map<String, dynamic>;
      final rawHits = data['hits'] as List<dynamic>? ?? [];
      final searchResults = rawHits
          .map((hit) => ElasticListing.fromJson(Map<String, dynamic>.from(hit)))
          .toList();

      final searchTimeMs = 0; // Backend doesn't return responseTimeMs yet
      final totalResults = searchResults.length;

      emit(currentState.copyWith(
        isSearching: false,
        searchResults: searchResults,
        searchTimeMs: searchTimeMs,
        totalSearchResults: totalResults,
      ));
    } catch (e) {
      emit(ElasticMonitorError(message: e.toString()));
    }
  }

  void _onRefreshStats(RefreshStats event, Emitter<ElasticMonitorState> emit) {
    add(LoadElasticStats()); // Simply re-load stats
  }
}

