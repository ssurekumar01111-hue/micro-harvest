import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class GateEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGateDetails extends GateEvent {
  final String handoffId;
  LoadGateDetails(this.handoffId);
  @override
  List<Object?> get props => [handoffId];
}

class ConfirmGate1 extends GateEvent {
  final String handoffId;
  final GeoPoint gps;
  final File image;
  ConfirmGate1({required this.handoffId, required this.gps, required this.image});
  @override
  List<Object?> get props => [handoffId, gps, image];
}

class ConfirmGate2 extends GateEvent {
  final String handoffId;
  final String producerId;
  final GeoPoint gps;
  final File image;
  ConfirmGate2({required this.handoffId, required this.producerId, required this.gps, required this.image});
  @override
  List<Object?> get props => [handoffId, producerId, gps, image];
}
