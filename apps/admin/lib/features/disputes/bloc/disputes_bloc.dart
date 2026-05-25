import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'disputes_event.dart';
part 'disputes_state.dart';

class DisputesBloc extends Bloc<DisputesEvent, DisputesState> {
  final FirebaseFirestore _firestore;
  final int _pageSize = 20;
  final Map<String, Map<String, dynamic>> _handoffCache = {};

  DisputesBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(DisputesInitial()) {
    on<LoadDisputes>(_onLoadDisputes);
    on<FilterDisputes>(_onFilterDisputes);
    on<ResolveDispute>(_onResolveDispute);
    on<DismissDispute>(_onDismissDispute);
    on<_DisputesUpdated>(_onDisputesUpdated);
  }

  Future<void> _enrichAndEmit(QuerySnapshot snapshot) async {
    final rawDisputes = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id};
    }).toList();

    final enrichedDisputes = await Future.wait(rawDisputes.map((dispute) async {
      final enriched = Map<String, dynamic>.from(dispute);
      final handoffId = dispute['handoffId'] as String?;
      
      if (handoffId != null) {
        if (_handoffCache.containsKey(handoffId)) {
          enriched['_handoff'] = _handoffCache[handoffId];
        } else {
          try {
            final doc = await _firestore.collection('handoffs').doc(handoffId).get();
            final data = doc.data();
            if (data != null) {
              // We could further enrich with cropType and names if they are not in handoff doc
              // but for now let's assume they are either there or we show IDs.
              _handoffCache[handoffId] = data;
              enriched['_handoff'] = data;
            }
          } catch (_) {}
        }
      }
      return enriched;
    }));

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    add(_DisputesUpdated(disputes: enrichedDisputes, lastDoc: lastDoc));
  }

  void _onLoadDisputes(LoadDisputes event, Emitter<DisputesState> emit) async {
    emit(DisputesLoading());
    try {
      _firestore
          .collection('disputes')
          .orderBy('raisedAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(DisputesError(message: e.toString()));
    }
  }

  void _onDisputesUpdated(_DisputesUpdated event, Emitter<DisputesState> emit) {
    if (state is DisputesLoaded) {
      final currentState = state as DisputesLoaded;
      emit(currentState.copyWith(
          disputes: event.disputes, lastDocument: event.lastDoc));
    } else {
      emit(DisputesLoaded(disputes: event.disputes, lastDocument: event.lastDoc));
    }
  }

  void _onFilterDisputes(FilterDisputes event, Emitter<DisputesState> emit) async {
    emit(DisputesLoading());
    try {
      Query query = _firestore.collection('disputes');

      if (event.status != null && event.status != 'ALL') {
        query = query.where('status', isEqualTo: event.status);
      }

      query
          .orderBy('raisedAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(DisputesError(message: e.toString()));
    }
  }

  void _onResolveDispute(ResolveDispute event, Emitter<DisputesState> emit) async {
    try {
      await _firestore.collection('disputes').doc(event.disputeId).update({
        'status': 'RESOLVED',
        'adminNote': event.adminNote,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      emit(DisputesError(
          message: 'Failed to resolve dispute: ${e.toString()}'));
    }
  }

  void _onDismissDispute(DismissDispute event, Emitter<DisputesState> emit) async {
    try {
      await _firestore.collection('disputes').doc(event.disputeId).update({
        'status': 'DISMISSED',
        'adminNote': event.adminNote,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      emit(DisputesError(
          message: 'Failed to dismiss dispute: ${e.toString()}'));
    }
  }
}
