part of 'disputes_bloc.dart';

sealed class DisputesState extends Equatable {
  const DisputesState();

  @override
  List<Object> get props => [];
}

final class DisputesInitial extends DisputesState {}

final class DisputesLoading extends DisputesState {}

final class DisputesLoaded extends DisputesState {
  final List<Map<String, dynamic>> disputes;
  final DocumentSnapshot? lastDocument;
  final String selectedFilterStatus; // ALL, OPEN, RESOLVED, DISMISSED

  const DisputesLoaded({
    required this.disputes,
    this.lastDocument,
    this.selectedFilterStatus = 'ALL',
  });

  DisputesLoaded copyWith({
    List<Map<String, dynamic>>? disputes,
    DocumentSnapshot? lastDocument,
    String? selectedFilterStatus,
  }) {
    return DisputesLoaded(
      disputes: disputes ?? this.disputes,
      lastDocument: lastDocument ?? this.lastDocument,
      selectedFilterStatus: selectedFilterStatus ?? this.selectedFilterStatus,
    );
  }

  @override
  List<Object> get props => [disputes, lastDocument ?? Object(), selectedFilterStatus];
}

final class DisputesError extends DisputesState {
  final String message;

  const DisputesError({required this.message});

  @override
  List<Object> get props => [message];
}