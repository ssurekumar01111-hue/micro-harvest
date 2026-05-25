part of 'handoffs_bloc.dart';

sealed class HandoffsEvent extends Equatable {
  const HandoffsEvent();

  @override
  List<Object> get props => [];
}

class LoadHandoffs extends HandoffsEvent {}

class FilterHandoffs extends HandoffsEvent {
  final String? status;

  const FilterHandoffs({this.status});

  @override
  List<Object> get props => [status ?? ''];
}

class ExpandHandoff extends HandoffsEvent {
  final String? handoffId; // Null to collapse

  const ExpandHandoff({this.handoffId});

  @override
  List<Object> get props => [handoffId ?? ''];
}

// Internal event to update state from stream
class _HandoffsUpdated extends HandoffsEvent {
  final List<Map<String, dynamic>> handoffs;
  final DocumentSnapshot? lastDoc;

  const _HandoffsUpdated({required this.handoffs, this.lastDoc});

  @override
  List<Object> get props => [handoffs, lastDoc ?? Object()];
}

