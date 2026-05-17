import 'package:equatable/equatable.dart';

abstract class ConfirmState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConfirmInitial extends ConfirmState {}
class ConfirmLoading extends ConfirmState {}

class ConfirmLoaded extends ConfirmState {
  final List<Map<String, dynamic>> handoffs;
  ConfirmLoaded(this.handoffs);
  @override
  List<Object?> get props => [handoffs];
}

class ConfirmGate2Success extends ConfirmState {}
class SettleSuccess extends ConfirmState {}

class ConfirmError extends ConfirmState {
  final String message;
  ConfirmError(this.message);
  @override
  List<Object?> get props => [message];
}
