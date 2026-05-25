import 'package:producer/data/models/listing_model.dart';

abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {
  final String naturalReply;
  SearchLoading({required this.naturalReply});
}

class SearchLoaded extends SearchState {
  final List<ListingModel> listings;
  final String naturalReply;
  final String resultSummary;
  final int totalResults;
  SearchLoaded({
    required this.listings,
    required this.naturalReply,
    required this.resultSummary,
    required this.totalResults,
  });
}

class SearchEmpty extends SearchState {
  final String naturalReply;
  final String resultSummary;
  SearchEmpty({
    required this.naturalReply,
    required this.resultSummary,
  });
}

class SearchError extends SearchState {
  final String message;
  SearchError({required this.message});
}
