import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'listings_event.dart';
part 'listings_state.dart';

class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  final FirebaseFirestore _firestore;
  final int _pageSize = 20;
  final Map<String, String> _userNameCache = {};

  ListingsBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(ListingsInitial()) {
    on<LoadListings>(_onLoadListings);
    on<FilterListings>(_onFilterListings);
    on<ForceExpireListing>(_onForceExpireListing);
    on<LoadNextPage>(_onLoadNextPage);
    on<SelectListing>(_onSelectListing);
    on<_ListingsUpdated>(_onListingsUpdated);
  }

  Future<void> _enrichAndEmit(QuerySnapshot snapshot) async {
    final rawListings = snapshot.docs.map<Map<String, dynamic>>((doc) {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      return {...d, 'id': doc.id};
    }).toList();

    final enrichedListings = await Future.wait(rawListings.map((listing) async {
      final enriched = Map<String, dynamic>.from(listing);
      await _enrichName(enriched, 'growerId', 'growerName');
      await _enrichName(enriched, 'producerId', 'producerName');
      return enriched;
    }));

    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    add(_ListingsUpdated(listings: enrichedListings, lastDoc: lastDoc));
  }

  Future<void> _enrichName(Map<String, dynamic> data, String idKey, String nameKey) async {
    final id = data[idKey] as String?;
    if (id == null) {
      data[nameKey] = 'N/A';
      return;
    }

    if (_userNameCache.containsKey(id)) {
      data[nameKey] = _userNameCache[id];
    } else {
      try {
        final doc = await _firestore.collection('users').doc(id).get();
        final name = doc.data()?['displayName'] as String?;
        _userNameCache[id] = name ?? (id.length > 6 ? id.substring(id.length - 6) : id);
        data[nameKey] = _userNameCache[id];
      } catch (_) {
        data[nameKey] = id.length > 6 ? id.substring(id.length - 6) : id;
      }
    }
  }

  void _onLoadListings(LoadListings event, Emitter<ListingsState> emit) async {
    emit(ListingsLoading());
    try {
      _firestore
          .collection('listings')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  void _onListingsUpdated(_ListingsUpdated event, Emitter<ListingsState> emit) {
    if (state is ListingsLoaded) {
      final currentState = state as ListingsLoaded;
      emit(currentState.copyWith(
          listings: event.listings, lastDocument: event.lastDoc));
    } else {
      emit(ListingsLoaded(listings: event.listings, lastDocument: event.lastDoc));
    }
  }

  void _onFilterListings(FilterListings event, Emitter<ListingsState> emit) async {
    emit(ListingsLoading());
    try {
      Query query = _firestore.collection('listings');

      if (event.status != null && event.status != 'ALL') {
        query = query.where('status', isEqualTo: event.status);
      }
      if (event.cropType != null && event.cropType != 'ALL') {
        query = query.where('cropType', isEqualTo: event.cropType);
      }

      query
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots()
          .listen((snapshot) {
        _enrichAndEmit(snapshot);
      });
    } catch (e) {
      emit(ListingsError(message: e.toString()));
    }
  }

  void _onForceExpireListing(ForceExpireListing event, Emitter<ListingsState> emit) async {
    try {
      await _firestore
          .collection('listings')
          .doc(event.listingId)
          .update({'status': 'EXPIRED', 'expiredAt': FieldValue.serverTimestamp()});
    } catch (e) {
      emit(ListingsError(message: 'Failed to expire listing: ${e.toString()}'));
    }
  }

  void _onLoadNextPage(LoadNextPage event, Emitter<ListingsState> emit) async {
    if (state is! ListingsLoaded) return;

    final currentState = state as ListingsLoaded;
    if (currentState.lastDocument == null) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      Query query = _firestore.collection('listings');

      final newSnapshot = await query
          .orderBy('createdAt', descending: true)
          .startAfterDocument(currentState.lastDocument!)
          .limit(_pageSize)
          .get();

      final newListingsRaw = newSnapshot.docs.map<Map<String, dynamic>>((doc) {
        final d = doc.data() as Map<String, dynamic>? ?? {};
        return {...d, 'id': doc.id};
      }).toList();

      final newListings = await Future.wait(newListingsRaw.map((listing) async {
        final enriched = Map<String, dynamic>.from(listing);
        await _enrichName(enriched, 'growerId', 'growerName');
        await _enrichName(enriched, 'producerId', 'producerName');
        return enriched;
      }));

      final newLastDoc = newSnapshot.docs.isNotEmpty ? newSnapshot.docs.last : null;

      emit(currentState.copyWith(
        listings: List<Map<String, dynamic>>.from(currentState.listings)..addAll(newListings),
        lastDocument: newLastDoc,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(ListingsError(message: 'Failed to load next page: ${e.toString()}'));
    }
  }

  void _onSelectListing(SelectListing event, Emitter<ListingsState> emit) {
    if (state is ListingsLoaded) {
      emit((state as ListingsLoaded).copyWith(selectedListing: event.listing));
    }
  }
}
