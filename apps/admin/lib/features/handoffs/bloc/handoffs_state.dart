part of 'handoffs_bloc.dart';

sealed class HandoffsState extends Equatable {
  const HandoffsState();

  @override
  List<Object> get props => [];
}

final class HandoffsInitial extends HandoffsState {}

final class HandoffsLoading extends HandoffsState {}

final class HandoffsLoaded extends HandoffsState {
  final List<Map<String, dynamic>> handoffs;
  final DocumentSnapshot? lastDocument;
  final String? expandedHandoffId;

  const HandoffsLoaded({
    required this.handoffs,
    this.lastDocument,
    this.expandedHandoffId,
  });

  HandoffsLoaded copyWith({
    List<Map<String, dynamic>>? handoffs,
    DocumentSnapshot? lastDocument,
    String? expandedHandoffId,
  }) {
    return HandoffsLoaded(
      handoffs: handoffs ?? this.handoffs,
      lastDocument: lastDocument ?? this.lastDocument,
      expandedHandoffId: expandedHandoffId ?? this.expandedHandoffId,
    );
  }

  @override
  List<Object> get props =>
      [handoffs, lastDocument ?? Object(), expandedHandoffId ?? ''];
}

final class HandoffsError extends HandoffsState {
  final String message;

  const HandoffsError({required this.message});

  @override
  List<Object> get props => [message];
}