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
