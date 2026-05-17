import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/handoff_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'confirm_event.dart';
import 'confirm_state.dart';

class ConfirmBloc extends Bloc<ConfirmEvent, ConfirmState> {
  final HandoffRepository _handoffRepository;
  final AuthRepository _authRepository;

  ConfirmBloc({
    required HandoffRepository handoffRepository,
    required AuthRepository authRepository,
  })  : _handoffRepository = handoffRepository,
        _authRepository = authRepository,
        super(ConfirmInitial()) {
    on<LoadPendingDeliveries>(_onLoadPendingDeliveries);
    on<ConfirmGate2>(_onConfirmGate2);
    on<SettleListing>(_onSettleListing);
  }

  Future<void> _onLoadPendingDeliveries(LoadPendingDeliveries event, Emitter<ConfirmState> emit) async {
    emit(ConfirmLoading());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(ConfirmError('User not found'));
        return;
      }

      await emit.forEach(
        _handoffRepository.getActiveHandoffs(user.uid),
        onData: (handoffs) => ConfirmLoaded(handoffs),
      );
    } catch (e) {
      emit(ConfirmError(e.toString()));
    }
  }

  Future<void> _onConfirmGate2(ConfirmGate2 event, Emitter<ConfirmState> emit) async {
    emit(ConfirmLoading());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(ConfirmError('User not found'));
        return;
      }

      await _handoffRepository.confirmGate2(
        handoffId: event.handoffId,
        producerId: user.uid,
        gps: event.gps,
        image: event.image,
      );
      emit(ConfirmGate2Success());
    } catch (e) {
      emit(ConfirmError(e.toString()));
    }
  }

  Future<void> _onSettleListing(SettleListing event, Emitter<ConfirmState> emit) async {
    emit(ConfirmLoading());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(ConfirmError('User not found'));
        return;
      }

      await _handoffRepository.settleListing(event.handoffId, user.uid);
      emit(SettleSuccess());
    } catch (e) {
      emit(ConfirmError(e.toString()));
    }
  }
}
