abstract class SearchEvent {}

class SearchQuerySubmitted extends SearchEvent {
  final String message;
  SearchQuerySubmitted(this.message);
}

class SearchCleared extends SearchEvent {}
