import 'package:equatable/equatable.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/handoff_model.dart';

abstract class DashboardEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {}
class ToggleAvailability extends DashboardEvent {
  final bool isAvailable;
  ToggleAvailability(this.isAvailable);
  @override
  List<Object?> get props => [isAvailable];
}
class RefreshDashboard extends DashboardEvent {}
