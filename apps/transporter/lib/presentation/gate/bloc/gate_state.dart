import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/models/handoff_model.dart';

abstract class GateState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GateInitial extends GateState {}
class GateLoading extends GateState {}

class GateLoaded extends GateState {
  final HandoffModel handoff;
  final GeoPoint currentGPS;
  GateLoaded({required this.handoff, required this.currentGPS});
  @override
  List<Object?> get props => [handoff, currentGPS];
}

class GateConfirming extends GateState {}
class GateConfirmed extends GateState {}

class GateError extends GateState {
  final String message;
  final bool isGPSError;
  GateError(this.message, {this.isGPSError = false});
  @override
  List<Object?> get props => [message, isGPSError];
}
