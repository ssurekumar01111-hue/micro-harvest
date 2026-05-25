import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/repositories/discovery_repository.dart';
import '../../../../data/repositories/handoff_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'discovery_event.dart';
import 'discovery_state.dart';

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final DiscoveryRepository _discoveryRepository;
  final HandoffRepository _handoffRepository;
  final AuthRepository _authRepository;

  GeoPoint? _lastLocation;
  String? _activeFilter;

  DiscoveryBloc({
    required DiscoveryRepository discoveryRepository,
    required HandoffRepository handoffRepository,
    required AuthRepository authRepository,
  })  : _discoveryRepository = discoveryRepository,
        _handoffRepository = handoffRepository,
        _authRepository = authRepository,
        super(DiscoveryInitial()) {
    on<LoadDiscovery>(_onLoadDiscovery);
    on<FilterByCrop>(_onFilterByCrop);
    on<ClaimListing>(_onClaimListing);
  }

  Future<void> _onLoadDiscovery(LoadDiscovery event, Emitter<DiscoveryState> emit) async {
    _lastLocation = event.location;
    await _subscribeToListings(emit);
  }

  Future<void> _onFilterByCrop(FilterByCrop event, Emitter<DiscoveryState> emit) async {
    _activeFilter = event.cropType;
    await _subscribeToListings(emit);
  }

  Future<void> _subscribeToListings(Emitter<DiscoveryState> emit) async {
    if (_lastLocation == null) return;
    emit(DiscoveryLoading());
    try {
      final listings = await _discoveryRepository.getNearbyListings(
        _lastLocation!.latitude,
        _lastLocation!.longitude,
      );
      emit(DiscoveryLoaded(
        listings: listings,
        producerLocation: _lastLocation!,
        activeFilter: _activeFilter,
      ));
    } catch (e) {
      emit(DiscoveryError(e.toString()));
    }
  }

  Future<void> _onClaimListing(ClaimListing event, Emitter<DiscoveryState> emit) async {
    emit(DiscoveryClaiming());
    try {
      final user = await _authRepository.getCurrentUserModel();
      if (user == null) {
        emit(DiscoveryError('User not found'));
        return;
      }

      await _handoffRepository.claimListing(event.listingId, user.uid);
      emit(DiscoveryClaimed(event.listingId));
    } catch (e) {
      emit(DiscoveryError(e.toString()));
    }
  }
}
