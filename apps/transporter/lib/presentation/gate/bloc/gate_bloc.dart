import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/haul_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'gate_event.dart';
import 'gate_state.dart';

class GateBloc extends Bloc<GateEvent, GateState> {
  final HaulRepository _haulRepository;
  final AuthRepository _authRepository;

  GateBloc({
    required HaulRepository haulRepository,
    required AuthRepository authRepository,
  })  : _haulRepository = haulRepository,
        _authRepository = authRepository,
        super(GateInitial()) {
    on<LoadGateDetails>(_onLoadGateDetails);
    on<ConfirmGate1>(_onConfirmGate1);
    on<ConfirmGate2>(_onConfirmGate2);
  }

  Future<void> _onLoadGateDetails(LoadGateDetails event, Emitter<GateState> emit) async {
    emit(GateLoading());
    try {
      // Logic for loading gate details can be added here
    } catch (e) {
      emit(GateError(e.toString()));
    }
  }

  Future<void> _onConfirmGate1(ConfirmGate1 event, Emitter<GateState> emit) async {
    emit(GateConfirming());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(GateError('User not found'));
        return;
      }

      await _haulRepository.confirmGate1(
        handoffId: event.handoffId,
        transporterId: user.uid,
        gps: event.gps,
        image: event.image,
      );
      emit(GateConfirmed());
    } catch (e) {
      emit(GateError(e.toString()));
    }
  }

  Future<void> _onConfirmGate2(ConfirmGate2 event, Emitter<GateState> emit) async {
    emit(GateConfirming());
    try {
      await _haulRepository.confirmGate2(
        handoffId: event.handoffId,
        producerId: event.producerId,
        gps: event.gps,
        image: event.image,
      );
      emit(GateConfirmed());
    } catch (e) {
      emit(GateError(e.toString()));
    }
  }
}
