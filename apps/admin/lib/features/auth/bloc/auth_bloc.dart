import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuth _firebaseAuth;
  static const String ADMIN_EMAIL = "admin@microharvest.com"; // Hardcoded admin email

  AuthBloc({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  void _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    final user = _firebaseAuth.currentUser;
    if (user != null && user.email == ADMIN_EMAIL) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  void _onLoginRequested(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists && userDoc.data()?['role'] == 'ADMIN') {
          emit(AuthAuthenticated(user: userCredential.user!));
        } else {
          await _firebaseAuth.signOut();
          emit(const AuthError(message: 'Access denied. Admin accounts only.'));
        }
      }
    } on FirebaseAuthException catch (e) {
      emit(AuthError(message: e.message ?? 'An unknown error occurred.'));
    } catch (e) {
      emit(AuthError(message: 'Access denied: $e'));
    }
  }

  void _onLogoutRequested(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _firebaseAuth.signOut();
    emit(AuthUnauthenticated());
  }
}

