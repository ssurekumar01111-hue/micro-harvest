import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'users_event.dart';
part 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final FirebaseFirestore _firestore;

  UsersBloc({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        super(UsersInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<FilterUsers>(_onFilterUsers);
    on<SuspendUser>(_onSuspendUser);
    on<ReactivateUser>(_onReactivateUser);
    on<_UsersUpdated>(_onUsersUpdated);
  }

  void _onLoadUsers(LoadUsers event, Emitter<UsersState> emit) async {
    emit(UsersLoading());
    try {
      _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        final users = snapshot.docs.map((doc) => doc.data()).toList().cast<Map<String, dynamic>>();
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        add(_UsersUpdated(users: users, lastDoc: lastDoc));
      });
    } catch (e) {
      emit(UsersError(message: e.toString()));
    }
  }

  void _onUsersUpdated(_UsersUpdated event, Emitter<UsersState> emit) {
    if (state is UsersLoaded) {
      final currentState = state as UsersLoaded;
      emit(currentState.copyWith(
          users: event.users, lastDocument: event.lastDoc));
    } else {
      emit(UsersLoaded(users: event.users, lastDocument: event.lastDoc));
    }
  }

  void _onFilterUsers(FilterUsers event, Emitter<UsersState> emit) async {
    emit(UsersLoading());
    try {
      Query query = _firestore.collection('users');

      if (event.role != null && event.role != 'ALL') {
        query = query.where('role', isEqualTo: event.role);
      }

      query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        final users = snapshot.docs.map((doc) => doc.data()).toList().cast<Map<String, dynamic>>();
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        add(_UsersUpdated(users: users, lastDoc: lastDoc));
      });
    } catch (e) {
      emit(UsersError(message: e.toString()));
    }
  }

  void _onSuspendUser(SuspendUser event, Emitter<UsersState> emit) async {
    try {
      await _firestore.collection('users').doc(event.uid).update({
        'suspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      emit(UsersError(message: 'Failed to suspend user: ${e.toString()}'));
    }
  }

  void _onReactivateUser(ReactivateUser event, Emitter<UsersState> emit) async {
    try {
      await _firestore.collection('users').doc(event.uid).update({
        'suspended': false,
        'suspendedAt': FieldValue.delete(),
      });
    } catch (e) {
      emit(UsersError(message: 'Failed to reactivate user: ${e.toString()}'));
    }
  }
}
