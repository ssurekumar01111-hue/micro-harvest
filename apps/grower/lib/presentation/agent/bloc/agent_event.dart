import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class AgentEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProcessListing extends AgentEvent {
  final String rawInput;
  final GeoPoint plotLocation;
  ProcessListing(this.rawInput, this.plotLocation);
  @override
  List<Object?> get props => [rawInput, plotLocation];
}

class SendConversationMessage extends AgentEvent {
  final String message;
  final GeoPoint plotLocation;
  SendConversationMessage(this.message, this.plotLocation);
  @override
  List<Object?> get props => [message, plotLocation];
}

class ConfirmListing extends AgentEvent {
  final Map<String, dynamic> extractedData;
  final GeoPoint plotLocation;
  ConfirmListing(this.extractedData, this.plotLocation);
  @override
  List<Object?> get props => [extractedData, plotLocation];
}

class ResetAgent extends AgentEvent {}

class StartAgent extends AgentEvent {}
