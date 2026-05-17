import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ConfirmEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPendingDeliveries extends ConfirmEvent {}

class ConfirmGate2 extends ConfirmEvent {
  final String handoffId;
  final GeoPoint gps;
  final File image;
  ConfirmGate2({required this.handoffId, required this.gps, required this.image});
  @override
  List<Object?> get props => [handoffId, gps, image];
}

class SettleListing extends ConfirmEvent {
  final String handoffId;
  SettleListing(this.handoffId);
  @override
  List<Object?> get props => [handoffId];
}
