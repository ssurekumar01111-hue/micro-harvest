import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/repositories/listing_repository.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'listings_event.dart';
import 'listings_state.dart';

class ListingsBloc extends Bloc<ListingsEvent, ListingsState> {
  final ListingRepository _listingRepository;
  final AuthRepository _authRepository;

  ListingsBloc({
    required ListingRepository listingRepository,
    required AuthRepository authRepository,
  })  : _listingRepository = listingRepository,
        _authRepository = authRepository,
        super(ListingsInitial()) {
    on<LoadListings>(_onLoadListings);
  }

  Future<void> _onLoadListings(LoadListings event, Emitter<ListingsState> emit) async {
    emit(ListingsLoading());
    try {
      final userModel = await _authRepository.getCurrentUserModel();
      if (userModel == null) {
        emit(ListingsError('User not found'));
        return;
      }

      await emit.forEach(
        _listingRepository.getGrowerListings(userModel.uid),
        onData: (listings) => ListingsLoaded(listings: listings),
      );
    } catch (e) {
      emit(ListingsError(e.toString()));
    }
  }
}
