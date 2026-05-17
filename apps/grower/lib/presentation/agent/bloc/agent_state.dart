import 'package:equatable/equatable.dart';

abstract class AgentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AgentInitial extends AgentState {}
class AgentLoading extends AgentState {}

class AgentSuccess extends AgentState {
  final String listingId;
  final String summary;
  AgentSuccess({required this.listingId, required this.summary});
  @override
  List<Object?> get props => [listingId, summary];
}

class AgentError extends AgentState {
  final String message;
  AgentError(this.message);
  @override
  List<Object?> get props => [message];
}
