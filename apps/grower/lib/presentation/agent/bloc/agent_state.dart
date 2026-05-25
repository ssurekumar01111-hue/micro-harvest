import 'package:equatable/equatable.dart';

abstract class AgentState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AgentInitial extends AgentState {}
class AgentLoading extends AgentState {}

class ConversationThinking extends AgentState {
  final List<Map<String, dynamic>> messages;
  final String conversationId;
  ConversationThinking(this.messages, {required this.conversationId});
  @override
  List<Object?> get props => [messages, conversationId];
}

class ConversationActive extends AgentState {
  final List<Map<String, dynamic>> messages;
  final String conversationId;
  final Map<String, dynamic> extractedData;
  final List<String> missingFields;
  final Map<String, dynamic>? reasoning;
  
  ConversationActive({
    required this.messages,
    required this.conversationId,
    required this.extractedData,
    required this.missingFields,
    this.reasoning,
  });

  @override
  List<Object?> get props => [messages, conversationId, extractedData, missingFields, reasoning];
}

class AgentNeedsReview extends AgentState {
  final Map<String, dynamic> extractedData;
  final Map<String, dynamic> assumptions;
  final String summary;
  final Map<String, dynamic>? reasoning;

  AgentNeedsReview({
    required this.extractedData,
    required this.assumptions,
    required this.summary,
    this.reasoning,
  });
  @override
  List<Object?> get props => [extractedData, assumptions, summary, reasoning];
}

class AgentSuccess extends AgentState {
  final String listingId;
  final String summary;
  final List<String> matchedTransporters;
  
  AgentSuccess({
    required this.listingId, 
    required this.summary,
    this.matchedTransporters = const [],
  });

  @override
  List<Object?> get props => [listingId, summary, matchedTransporters];
}

class AgentOfflineQueued extends AgentState {
  final String message;
  AgentOfflineQueued({required this.message});
  @override
  List<Object?> get props => [message];
}

class AgentError extends AgentState {
  final String message;
  AgentError(this.message);
  @override
  List<Object?> get props => [message];
}
