import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/haul_repository.dart';
import '../../../../data/repositories/location_repository.dart';
import 'haul_event.dart';
import 'haul_state.dart';

class HaulBloc extends Bloc<HaulEvent, HaulState> {
  final AuthRepository _authRepository;
  final HaulRepository _haulRepository;
  final LocationRepository _locationRepository;

  HaulBloc({
    required AuthRepository authRepository,
    required HaulRepository haulRepository,
    required LocationRepository locationRepository,
  })  : _authRepository = authRepository,
        _haulRepository = haulRepository,
        _locationRepository = locationRepository,
        super(HaulInitial()) {
    on<LoadAvailableHauls>(_onLoadAvailableHauls);
    on<AcceptHaul>(_onAcceptHaul);
  }

  Future<void> _onLoadAvailableHauls(LoadAvailableHauls event, Emitter<HaulState> emit) async {
    emit(HaulLoading());
    try {
      final location = await _locationRepository.getCurrentLocation();
      await emit.forEach(
        _haulRepository.getAvailableHauls(transporterLocation: location, radiusMiles: 50),
        onData: (hauls) => HaulAlertsLoaded(hauls),
      );
    } catch (e) {
      emit(HaulError(e.toString()));
    }
  }

  Future<void> _onAcceptHaul(AcceptHaul event, Emitter<HaulState> emit) async {
    emit(HaulAccepting());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(HaulError('User not found'));
        return;
      }

      await _haulRepository.acceptHaul(event.listingId, user.uid);
      // The actual handoffId will be in the new handoff document created by the CF
      emit(HaulAccepted('')); // Simplified
    } catch (e) {
      emit(HaulError(e.toString()));
    }
  }
}
