part of 'listings_bloc.dart';

sealed class ListingsState extends Equatable {
  const ListingsState();

  @override
  List<Object> get props => [];
}

final class ListingsInitial extends ListingsState {}

final class ListingsLoading extends ListingsState {}

final class ListingsLoaded extends ListingsState {
  final List<Map<String, dynamic>> listings;
  final DocumentSnapshot? lastDocument;
  final bool isLoadingMore;
  final Map<String, dynamic>? selectedListing;

  const ListingsLoaded({
    required this.listings,
    this.lastDocument,
    this.isLoadingMore = false,
    this.selectedListing,
  });

  ListingsLoaded copyWith({
    List<Map<String, dynamic>>? listings,
    DocumentSnapshot? lastDocument,
    bool? isLoadingMore,
    Map<String, dynamic>? selectedListing,
  }) {
    return ListingsLoaded(
      listings: listings ?? this.listings,
      lastDocument: lastDocument ?? this.lastDocument,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedListing: selectedListing ?? this.selectedListing,
    );
  }

  @override
  List<Object> get props => [
        listings,
        lastDocument ?? Object(),
        isLoadingMore,
        selectedListing ?? Object(),
      ];
}

final class ListingsError extends ListingsState {
  final String message;

  const ListingsError({required this.message});

  @override
  List<Object> get props => [message];
}