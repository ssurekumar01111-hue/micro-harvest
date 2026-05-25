import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'analytics_event.dart';
part 'analytics_state.dart';

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final FirebaseFirestore _firestore;

  AnalyticsBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(AnalyticsInitial()) {
    on<LoadAnalytics>(_onLoadAnalytics);
    on<RefreshAnalytics>(_onRefreshAnalytics);
  }

  Future<void> _onLoadAnalytics(
      LoadAnalytics event, Emitter<AnalyticsState> emit) async {
    emit(AnalyticsLoading());
    try {
      // Listings Created — Last 30 Days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final listingsSnapshot = await _firestore
          .collection('listings')
          .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('createdAt')
          .get();

      final Map<String, int> listingsByDay = {};
      for (var doc in listingsSnapshot.docs) {
        final date = (doc.data()['createdAt'] as Timestamp).toDate();
        final formattedDate = '${date.year}-${date.month}-${date.day}';
        listingsByDay[formattedDate] = (listingsByDay[formattedDate] ?? 0) + 1;
      }

      // Revenue by Crop Type (Top 5)
      final settledHandoffsSnapshot = await _firestore
          .collection('handoffs')
          .get(); // We filter in memory for settled/released payments

      final Map<String, double> revenueByCrop = {};
      for (var doc in settledHandoffsSnapshot.docs) {
        final data = doc.data();
        final payment = data['payment'] as Map<String, dynamic>?;
        if (payment?['releasedAt'] != null) {
          final cropType = data['cropType'] ?? 'UNKNOWN';
          final amount = (payment?['totalUSD'] as num?)?.toDouble() ?? 0.0;
          revenueByCrop[cropType] = (revenueByCrop[cropType] ?? 0.0) + amount;
        }
      }
      final top5RevenueCrops = revenueByCrop.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5Revenue = top5RevenueCrops.take(5).toList();

      // Users by Role
      final usersSnapshot = await _firestore.collection('users').get();
      final Map<String, int> usersByRole = {};
      for (var doc in usersSnapshot.docs) {
        final role = doc.data()['role'] ?? 'UNKNOWN';
        usersByRole[role] = (usersByRole[role] ?? 0) + 1;
      }

      // Handoffs by Status
      final handoffsStatusSnapshot = await _firestore.collection('handoffs').get();
      final Map<String, int> handoffsByStatus = {};
      for (var doc in handoffsStatusSnapshot.docs) {
        final status = doc.data()['status'] ?? 'UNKNOWN';
        handoffsByStatus[status] = (handoffsByStatus[status] ?? 0) + 1;
      }

      emit(AnalyticsLoaded(
        listingsCreatedLast30Days: listingsByDay,
        revenueByCropType: Map.fromEntries(top5Revenue),
        usersByRole: usersByRole,
        handoffsByStatus: handoffsByStatus,
      ));
    } catch (e) {
      emit(AnalyticsError(message: e.toString()));
    }
  }

  void _onRefreshAnalytics(
      RefreshAnalytics event, Emitter<AnalyticsState> emit) {
    add(LoadAnalytics()); // Simply re-load all analytics data
  }
}

