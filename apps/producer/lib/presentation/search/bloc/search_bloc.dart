import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:producer/data/models/listing_model.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchInitial()) {
    on<SearchQuerySubmitted>(_onQuerySubmitted);
    on<SearchCleared>(_onSearchCleared);
  }

  Future<void> _onQuerySubmitted(
    SearchQuerySubmitted event,
    Emitter<SearchState> emit,
  ) async {
    try {
      // Get producer location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      emit(SearchLoading(
        naturalReply: "Searching listings...",
      ));

      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('producerSearch');

      final result = await callable.call({
        'message': event.message,
        'producerLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });

      final data = result.data as Map<String, dynamic>;
      final listingsRaw = data['listings'] as List<dynamic>;

      final listings = listingsRaw
        .map((l) => ListingModel.fromMap(
          Map<String, dynamic>.from(l as Map),
          l['listingId'] as String,
        ))
        .toList();

      if (listings.isEmpty) {
        emit(SearchEmpty(
          naturalReply: data['naturalReply'] as String,
          resultSummary: data['resultSummary'] as String,
        ));
      } else {
        emit(SearchLoaded(
          listings: listings,
          naturalReply: data['naturalReply'] as String,
          resultSummary: data['resultSummary'] as String,
          totalResults: data['totalResults'] as int,
        ));
      }
    } catch (e) {
      emit(SearchError(
        message: 'Search failed. Please try again.',
      ));
    }
  }

  void _onSearchCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) {
    emit(SearchInitial());
  }
}
