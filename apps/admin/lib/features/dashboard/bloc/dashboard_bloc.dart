import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseFirestore _firestore;
  final Map<String, String> _cropTypeCache = {};
  final Map<String, String> _userNameCache = {};

  DashboardBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
  }

  String _getStatus(Map<String, dynamic> handoff) {
    final payment = handoff['payment'] as Map<String, dynamic>?;
    final releasedAt = payment?['releasedAt'];
    final gate2 = handoff['gate2'];
    final gate1 = handoff['gate1'];

    if (releasedAt != null) return 'SETTLED';
    if (gate2 != null) return 'DELIVERED';
    if (gate1 != null) return 'IN_TRANSIT';
    return 'PENDING';
  }

  Future<void> _enrichHandoff(Map<String, dynamic> handoff) async {
    // Crop Type
    final listingId = handoff['listingId'] as String?;
    if (listingId != null) {
      if (_cropTypeCache.containsKey(listingId)) {
        handoff['_cropType'] = _cropTypeCache[listingId];
      } else {
        try {
          final doc = await _firestore.collection('listings').doc(listingId).get();
          final cropType = doc.data()?['cropType'] as String?;
          _cropTypeCache[listingId] = cropType ?? 'N/A';
          handoff['_cropType'] = _cropTypeCache[listingId];
        } catch (_) {
          handoff['_cropType'] = 'N/A';
        }
      }
    }

    // Names
    await _enrichName(handoff, 'growerId', '_growerName');
    await _enrichName(handoff, 'producerId', '_producerName');
    await _enrichName(handoff, 'transporterId', '_transporterName');
    
    // Status
    handoff['_status'] = _getStatus(handoff);
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

  Future<void> _onLoadDashboard(
      LoadDashboard event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      // ... (previous stats fetching code)
      final totalListingsSnapshot = await _firestore.collection('listings').count().get();
      final totalListings = (totalListingsSnapshot.count ?? 0).toInt();

      final activeListingsSnapshot = await _firestore
          .collection('listings')
          .where('status', whereIn: ['OPEN', 'MATCHED', 'LOCKED', 'IN_TRANSIT'])
          .count()
          .get();
      final activeListings = (activeListingsSnapshot.count ?? 0).toInt();

      final settledListingsSnapshot = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'SETTLED')
          .count()
          .get();
      final settledListings = (settledListingsSnapshot.count ?? 0).toInt();

      final totalHandoffsSnapshot = await _firestore.collection('handoffs').count().get();
      final totalHandoffs = (totalHandoffsSnapshot.count ?? 0).toInt();

      final settledHandoffsSnapshot = await _firestore
          .collection('handoffs')
          .get();
      
      double totalRevenueUsd = 0.0;
      double platformFeesUsd = 0.0;
      for (var doc in settledHandoffsSnapshot.docs) {
        final data = doc.data();
        final payment = data['payment'] as Map<String, dynamic>?;
        if (payment?['releasedAt'] != null) {
          totalRevenueUsd += (payment?['totalUSD'] as num?)?.toDouble() ?? 0.0;
          platformFeesUsd += (payment?['platformFeeUSD'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final growersSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'GROWER').count().get();
      final producersSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'PRODUCER').count().get();
      final transportersSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'TRANSPORTER').count().get();
      final usersSnapshot = await _firestore.collection('users').count().get();

      final totalGrowers = (growersSnapshot.count ?? 0).toInt();
      final totalProducers = (producersSnapshot.count ?? 0).toInt();
      final totalTransporters = (transportersSnapshot.count ?? 0).toInt();
      final registeredUsers = (usersSnapshot.count ?? 0).toInt();

      // Fetch Recent Listings
      final recentListingsSnapshot = await _firestore
          .collection('listings')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      final recentListings = recentListingsSnapshot.docs.map((doc) => doc.data()).toList();

      // Fetch Recent Handoffs and ENRICH
      final recentHandoffsSnapshot = await _firestore
          .collection('handoffs')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();
      final recentHandoffs = recentHandoffsSnapshot.docs.map((doc) => doc.data()).toList();
      
      for (var handoff in recentHandoffs) {
        await _enrichHandoff(handoff);
      }

      emit(DashboardLoaded(
        totalListings: totalListings,
        activeListings: activeListings,
        settledListings: settledListings,
        totalHandoffs: totalHandoffs,
        totalGrowers: totalGrowers,
        totalProducers: totalProducers,
        totalTransporters: totalTransporters,
        totalRevenueUsd: totalRevenueUsd,
        platformFeesUsd: platformFeesUsd,
        registeredUsers: registeredUsers,
        recentListings: recentListings,
        recentHandoffs: recentHandoffs,
      ));
    } catch (e) {
      emit(DashboardError(message: e.toString()));
    }
  }
}

