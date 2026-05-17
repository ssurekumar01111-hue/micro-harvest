import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/listing_repository.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AuthRepository _authRepository;
  final ListingRepository _listingRepository;

  DashboardBloc({
    required AuthRepository authRepository,
    required ListingRepository listingRepository,
  })  : _authRepository = authRepository,
        _listingRepository = listingRepository,
        super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final userModel = await _authRepository.getCurrentUserModel();
      if (userModel == null) {
        emit(DashboardError('User not found'));
        return;
      }

      await emit.forEach(
        _listingRepository.getGrowerListings(userModel.uid),
        onData: (listings) {
          final stats = {
            'activeListings': listings.where((l) => l.status.name == 'OPEN' || l.status.name == 'MATCHED').length,
            'totalEarned': listings
                .where((l) => l.status.name == 'SETTLED')
                .fold(0.0, (sum, l) => sum + l.askingPriceUSD),
            'totalHauled': listings.where((l) => l.status.name == 'SETTLED' || l.status.name == 'DELIVERED').length,
          };
          return DashboardLoaded(
            user: userModel,
            listings: listings,
            stats: stats,
          );
        },
      );
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onRefreshDashboard(RefreshDashboard event, Emitter<DashboardState> emit) async {
    add(LoadDashboard());
  }
}
