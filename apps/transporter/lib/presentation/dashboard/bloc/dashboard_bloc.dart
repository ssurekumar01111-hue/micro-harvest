import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/haul_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AuthRepository _authRepository;
  final HaulRepository _haulRepository;

  DashboardBloc({
    required AuthRepository authRepository,
    required HaulRepository haulRepository,
  })  : _authRepository = authRepository,
        _haulRepository = haulRepository,
        super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<ToggleAvailability>(_onToggleAvailability);
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(DashboardError('User not found'));
        return;
      }

      await emit.forEach(
        _haulRepository.getActiveHandoff(user.uid),
        onData: (activeHandoff) => DashboardLoaded(
          user: user,
          isAvailable: user.availabilityStatus == 'AVAILABLE',
          activeHandoff: activeHandoff,
          todayEarnings: 0.0, // Mock
          totalHauls: 0, // Mock
          rating: 5.0, // Mock
        ),
      );
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onToggleAvailability(ToggleAvailability event, Emitter<DashboardState> emit) async {
    final currentState = state;
    if (currentState is DashboardLoaded) {
      try {
        await _haulRepository.updateAvailability(currentState.user.uid, event.isAvailable);
        // The listener in _onLoadDashboard will re-emit if user doc updates or we can just reload
        add(LoadDashboard());
      } catch (e) {
        emit(DashboardError(e.toString()));
      }
    }
  }
}
