import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../data/repositories/agent_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../core/sync/sync_engine.dart';
import 'agent_event.dart';
import 'agent_state.dart';

class AgentBloc extends Bloc<AgentEvent, AgentState> {
  final AgentRepository _agentRepository;
  final AuthRepository _authRepository;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AgentBloc({
    required AgentRepository agentRepository,
    required AuthRepository authRepository,
  })  : _agentRepository = agentRepository,
        _authRepository = authRepository,
        super(AgentInitial()) {
    on<ProcessListing>(_onProcessListing);
    on<SendConversationMessage>(_onSendConversationMessage);
    on<ConfirmListing>(_onConfirmListing);
    on<ResetAgent>(_onResetAgent);
    on<StartAgent>(_onStartAgent);
  }

  void _onStartAgent(StartAgent event, Emitter<AgentState> emit) {
    // FIX 2: Generate conversationId once on start
    final String newConversationId = const Uuid().v4();
    
    emit(ConversationActive(
      messages: const [
        {
          'role': 'assistant',
          'content': "Hello! I'm your Harvest Agent. Tell me what you have "
              "ready — crop type, quantity, and your asking price. "
              "You can speak or type in English."
        }
      ],
      conversationId: newConversationId,
      extractedData: const {},
      missingFields: const ["cropType", "containerType", "containerCount", "weightKg", "perishTier"],
    ));
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
        harvestWindowEnd: DateTime.now().add(const Duration(days: 1)),
      );

      if (result['success'] == true) {
        emit(AgentNeedsReview(
          extractedData: Map<String, dynamic>.from(result['extractedData']),
          assumptions: Map<String, dynamic>.from(result['assumptions']),
          summary: result['summary'] ?? '',
        ));
      } else {
        emit(AgentError(result['message'] ?? 'Failed to process listing'));
      }
    } catch (e) {
      emit(AgentError(e.toString()));
    }
  }

  Future<void> _onSendConversationMessage(SendConversationMessage event, Emitter<AgentState> emit) async {
    if (state is! ConversationActive && state is! ConversationThinking) return;
    
    final List<Map<String, dynamic>> currentMessages = state is ConversationActive 
        ? List.from((state as ConversationActive).messages) 
        : List.from((state as ConversationThinking).messages);
    
    final String conversationId = state is ConversationActive 
        ? (state as ConversationActive).conversationId 
        : (state as ConversationThinking).conversationId;

    final Map<String, dynamic> currentExtractedData = state is ConversationActive
        ? (state as ConversationActive).extractedData
        : {};

    currentMessages.add({'role': 'user', 'content': event.message});
    emit(ConversationThinking(currentMessages, conversationId: conversationId));

    try {
      final userModel = await _authRepository.getCurrentUserModel();
      if (userModel == null) {
        emit(AgentError('User not found'));
        return;
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none);

      if (!isOnline) {
        await SyncEngine().queueAction('CONVERSATION_TURN', {
          'conversationId': conversationId,
          'message': event.message,
          'growerId': userModel.uid,
          'plotLocation': {
            'latitude': event.plotLocation.latitude,
            'longitude': event.plotLocation.longitude,
          },
          'timestamp': DateTime.now().toIso8601String(),
        });

        emit(ConversationActive(
          conversationId: conversationId,
          messages: [
            ...currentMessages,
            const {
              'role': 'assistant',
              'content': "You're offline. Your message has been saved and will be processed when you reconnect."
            }
          ],
          extractedData: currentExtractedData,
          missingFields: const [],
        ));
        return;
      }

      final result = await _agentRepository.processConversationTurn(
        conversationId: conversationId,
        message: event.message,
        growerId: userModel.uid,
        plotLocation: event.plotLocation,
      );

      if (result['success'] == true) {
        final aiResponse = result['aiResponse'];
        currentMessages.add({'role': 'assistant', 'content': aiResponse});

        if (result['needsReview'] == true) {
          emit(AgentNeedsReview(
            extractedData: Map<String, dynamic>.from(result['extractedData']),
            assumptions: const {}, 
            summary: aiResponse,
            reasoning: result['reasoning'] != null ? Map<String, dynamic>.from(result['reasoning']) : null,
          ));
        } else {
          emit(ConversationActive(
            messages: currentMessages,
            conversationId: conversationId,
            extractedData: Map<String, dynamic>.from(result['extractedData']),
            missingFields: List<String>.from(result['missingFields']),
            reasoning: result['reasoning'] != null ? Map<String, dynamic>.from(result['reasoning']) : null,
          ));
        }
      } else {
        emit(AgentError(result['message'] ?? 'Failed to process conversation'));
      }
    } catch (e) {
      // If function call fails, queue it
      final userModel = await _authRepository.getCurrentUserModel();
      if (userModel != null) {
        await SyncEngine().queueAction('CONVERSATION_TURN', {
          'conversationId': conversationId,
          'message': event.message,
          'growerId': userModel.uid,
          'plotLocation': {
            'latitude': event.plotLocation.latitude,
            'longitude': event.plotLocation.longitude,
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      emit(ConversationActive(
        conversationId: conversationId,
        messages: [
          ...currentMessages,
          const {
            'role': 'assistant',
            'content': "Could not connect. Your message is saved and will sync automatically."
          }
        ],
        extractedData: currentExtractedData,
        missingFields: const [],
      ));
    }
  }

  Future<void> _onConfirmListing(ConfirmListing event, Emitter<AgentState> emit) async {
    final prevState = state;
    if (prevState is! AgentNeedsReview) return;
    
    emit(AgentLoading());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) throw Exception('User not authenticated');

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none);

      if (!isOnline) {
        await SyncEngine().queueAction('CREATE_LISTING', {
          'growerId': user.uid,
          'growerName': user.displayName,
          'extractedData': event.extractedData,
          'plotLocation': {
            'latitude': event.plotLocation.latitude,
            'longitude': event.plotLocation.longitude,
          },
          'timestamp': DateTime.now().toIso8601String(),
        });

        emit(AgentOfflineQueued(
          message: 'Your listing has been saved offline and will be created automatically when you reconnect.',
        ));
        return;
      }

      final data = event.extractedData;
      final geohash = GeoHasher().encode(event.plotLocation.longitude, event.plotLocation.latitude);

      final listingRef = _firestore.collection('listings').doc();
      await listingRef.set({
        'listingId': listingRef.id,
        'growerId': user.uid,
        'growerName': user.displayName,
        'pickupAddress': 'Near ${event.plotLocation.latitude.toStringAsFixed(3)}, ${event.plotLocation.longitude.toStringAsFixed(3)}',
        'cropType': data['cropType'],
        'containerType': data['containerType'],
        'containerCount': data['containerCount'],
        'weightKg': data['weightKg'],
        'perishTier': data['perishTier'],
        'askingPricePerTon': data['askingPricePerTon'],
        'plotLocation': event.plotLocation,
        'geohash': geohash,
        'harvestWindowEnd': DateTime.now().add(Duration(hours: data['harvestWindowHours'] ?? 24)),
        'status': 'OPEN',
        'producerId': null,
        'transporterId': null,
        'listingSource': 'AGENT',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch matched transporters from agentLog
      List<String> transporterNames = [];
      try {
        final agentLogQuery = await _firestore
            .collection('agentLogs')
            .where('growerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        
        if (agentLogQuery.docs.isNotEmpty) {
          final logData = agentLogQuery.docs.first.data();
          final List<dynamic> transporterIds = logData['matchedTransporterIds'] ?? [];
          
          for (var id in transporterIds) {
            final userDoc = await _firestore.collection('users').doc(id).get();
            if (userDoc.exists) {
              transporterNames.add(userDoc.data()?['displayName'] ?? 'Unknown');
            }
          }
        }
      } catch (e) {
        debugPrint('[AgentBloc] Error fetching matched transporters: $e');
      }

      emit(AgentSuccess(
        listingId: listingRef.id,
        summary: 'Your listing is now live! Producers nearby have been notified.',
        matchedTransporters: transporterNames,
      ));
    } catch (e) {
      emit(AgentError(e.toString()));
    }
  }

  void _onResetAgent(ResetAgent event, Emitter<AgentState> emit) {
    add(StartAgent());
  }
}
