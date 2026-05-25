import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'handoffs_event.dart';
part 'handoffs_state.dart';

class HandoffsBloc extends Bloc<HandoffsEvent, HandoffsState> {
  final FirebaseFirestore _firestore;
  final int _pageSize = 20;

  final Map<String, String> _cropTypeCache = {};
  final Map<String, String> _userNameCache = {};

  HandoffsBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(HandoffsInitial()) {
    on<LoadHandoffs>(_onLoadHandoffs);
    on<FilterHandoffs>(_onFilterHandoffs);
    on<ExpandHandoff>(_onExpandHandoff);
    on<_HandoffsUpdated>(_onHandoffsUpdated);
  }

  Future<void> _enrichAndEmit(QuerySnapshot snapshot) async {
    final rawHandoffs = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('id')) {
        data['id'] = doc.id;
      }
      return data;
    }).toList();

    final enrichedHandoffs = await Future.wait(rawHandoffs.map((handoff) async {
      final enriched = Map<String, dynamic>.from(handoff);
      
      // Fetch Crop Type
      final listingId = handoff['listingId'] as String?;
      if (listingId != null) {
        if (_cropTypeCache.containsKey(listingId)) {
          enriched['_cropType'] = _cropTypeCache[listingId];
        } else {
          try {
            final doc = await _firestore.collection('listings').doc(listingId).get();
            final cropType = doc.data()?['cropType'] as String?;
            _cropTypeCache[listingId] = cropType ?? (listingId.length > 6 ? listingId.substring(listingId.length - 6) : listingId);
            enriched['_cropType'] = _cropTypeCache[listingId];
          } catch (_) {
            enriched['_cropType'] = listingId.length > 6 ? listingId.substring(listingId.length - 6) : listingId;
          }
        }
      }

      // Fetch Names
      await _enrichName(enriched, 'growerId', '_growerName');
      await _enrichName(enriched, 'producerId', '_producerName');
      await _enrichName(enriched, 'transporterId', '_transporterName');

      return enriched;
    }));

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    add(_HandoffsUpdated(handoffs: enrichedHandoffs, lastDoc: lastDoc));
  }

  Future<void> _enrichName(Map<String, dynamic> handoff, String idKey, String nameKey) async {
    final id = handoff[idKey] as String?;
    if (id == null) {
      handoff[nameKey] = 'N/A';
      return;
    }

    if (_userNameCache.containsKey(id)) {
      handoff[nameKey] = _userNameCache[id];
    } else {
      try {
        final doc = await _firestore.collection('users').doc(id).get();
        final name = doc.data()?['displayName'] as String?;
        _userNameCache[id] = name ?? (id.length > 6 ? id.substring(id.length - 6) : id);
        handoff[nameKey] = _userNameCache[id];
      } catch (_) {
        handoff[nameKey] = id.length > 6 ? id.substring(id.length - 6) : id;
      }
    }
  }

  void _onLoadHandoffs(LoadHandoffs event, Emitter<HandoffsState> emit) async {
    emit(HandoffsLoading());
    try {
      _firestore
          .collection('handoffs')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(HandoffsError(message: e.toString()));
    }
  }

  void _onHandoffsUpdated(_HandoffsUpdated event, Emitter<HandoffsState> emit) {
    if (state is HandoffsLoaded) {
      final currentState = state as HandoffsLoaded;
      emit(currentState.copyWith(
          handoffs: event.handoffs, lastDocument: event.lastDoc));
    } else {
      emit(HandoffsLoaded(handoffs: event.handoffs, lastDocument: event.lastDoc));
    }
  }

  void _onFilterHandoffs(FilterHandoffs event, Emitter<HandoffsState> emit) async {
    emit(HandoffsLoading());
    try {
      Query query = _firestore.collection('handoffs');

      if (event.status != null && event.status != 'ALL') {
        query = query.where('status', isEqualTo: event.status);
      }

      query
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(HandoffsError(message: e.toString()));
    }
  }

  void _onExpandHandoff(ExpandHandoff event, Emitter<HandoffsState> emit) {
    if (state is HandoffsLoaded) {
      final currentState = state as HandoffsLoaded;
      emit(currentState.copyWith(expandedHandoffId: event.handoffId));
    }
  }
}
