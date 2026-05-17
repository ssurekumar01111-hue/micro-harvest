import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/agent_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'agent_event.dart';
import 'agent_state.dart';

class AgentBloc extends Bloc<AgentEvent, AgentState> {
  final AgentRepository _agentRepository;
  final AuthRepository _authRepository;

  AgentBloc({
    required AgentRepository agentRepository,
    required AuthRepository authRepository,
  })  : _agentRepository = agentRepository,
        _authRepository = authRepository,
        super(AgentInitial()) {
    on<ProcessListing>(_onProcessListing);
  }

  Future<void> _onProcessListing(ProcessListing event, Emitter<AgentState> emit) async {
    emit(AgentLoading());
    try {
      final userModel = await _authRepository.getCurrentUserModel();
      if (userModel == null) {
        emit(AgentError('User not found'));
        return;
      }

      final result = await _agentRepository.processListing(
        rawInput: event.rawInput,
        growerId: userModel.uid,
        plotLocation: event.plotLocation,
        harvestWindowEnd: DateTime.now().add(const Duration(days: 3)), // Default
      );

      if (result['success'] == true) {
        emit(AgentSuccess(
          listingId: result['listingId'] ?? '',
          summary: result['summary'] ?? '',
        ));
      } else {
        emit(AgentError(result['message'] ?? 'Failed to process listing'));
      }
    } catch (e) {
      emit(AgentError(e.toString()));
    }
  }
}
