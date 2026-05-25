part of 'disputes_bloc.dart';

sealed class DisputesEvent extends Equatable {
  const DisputesEvent();

  @override
  List<Object> get props => [];
}

class LoadDisputes extends DisputesEvent {}

class FilterDisputes extends DisputesEvent {
  final String? status;

  const FilterDisputes({this.status});

  @override
  List<Object> get props => [status ?? ''];
}

class ResolveDispute extends DisputesEvent {
  final String disputeId;
  final String adminNote;

  const ResolveDispute({required this.disputeId, required this.adminNote});

  @override
  List<Object> get props => [disputeId, adminNote];
}

class DismissDispute extends DisputesEvent {
  final String disputeId;
  final String adminNote;

  const DismissDispute({required this.disputeId, required this.adminNote});

  @override
  List<Object> get props => [disputeId, adminNote];
}

// Internal event to update state from stream
class _DisputesUpdated extends DisputesEvent {
  final List<Map<String, dynamic>> disputes;
  final DocumentSnapshot? lastDoc;

  const _DisputesUpdated({required this.disputes, this.lastDoc});

  @override
  List<Object> get props => [disputes, lastDoc ?? Object()];
}

