import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import '../../../../data/models/listing_model.dart';
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

      final activeStream = _haulRepository.getActiveHandoff(user.uid);
      final pendingStream = _haulRepository.getIncomingHaulRequests(user.uid);
      final statsStream = _haulRepository.getTransporterStats(user.uid);

      await emit.forEach(
        Rx.combineLatest3(
          activeStream,
          pendingStream,
          statsStream,
          (active, List<ListingModel> pending, Map<String, dynamic> stats) => (active, pending, stats),
        ),
        onData: (data) {
          final active = data.$1;
          final pending = data.$2;
          final stats = data.$3;

          return DashboardLoaded(
            user: user,
            isAvailable: user.availabilityStatus == 'AVAILABLE',
            activeHandoff: active,
            pendingHauls: pending,
            todayEarnings: stats['todayEarnings'] ?? 0.0,
            totalHauls: stats['totalHauls'] ?? 0,
            rating: 5.0,
          );
        },
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
