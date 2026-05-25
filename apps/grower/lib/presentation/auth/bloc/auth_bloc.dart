import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<PhoneOTPRequested>(_onPhoneOTPRequested);
    on<OTPVerified>(_onOTPVerified);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<_InternalAuthCodeSent>(_onInternalAuthCodeSent);
    on<_InternalAuthError>(_onInternalAuthError);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _handleLoginSuccess(user, emit);
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _handleLoginSuccess(User user, Emitter<AuthState> emit) async {
    final userModel = await _authRepository.getUserFromFirestore(user.uid);
    if (userModel == null) {
      await _authRepository.saveUserToFirestore(user);
    }

    await _authRepository.saveFCMToken(user.uid);

    final isRegistered = await _authRepository.isUserRegistered(user.uid);
    if (isRegistered) {
      final updatedUserModel = await _authRepository.getCurrentUserModel();
      if (updatedUserModel != null) {
        emit(AuthExistingUser(updatedUserModel));
        return;
      }
    }
    emit(AuthNewUser(user));
  }

  Future<void> _onPhoneOTPRequested(PhoneOTPRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithPhone(
        phoneNumber: event.phoneNumber,
        codeSent: (verificationId, resendToken) {
          add(_InternalAuthCodeSent(verificationId));
        },
        verificationFailed: (e) {
          add(_InternalAuthError(e.message ?? 'Verification failed'));
        },
      );
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onOTPVerified(OTPVerified event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authRepository.verifyOTP(
        verificationId: event.verificationId,
        smsCode: event.smsCode,
      );
      if (userCredential.user != null) {
        await _handleLoginSuccess(userCredential.user!, emit);
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(GoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authRepository.signInWithGoogle();
      if (userCredential?.user != null) {
        await _handleLoginSuccess(userCredential!.user!, emit);
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOutRequested(SignOutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

  // Internal events to handle callbacks
  void _onInternalAuthCodeSent(_InternalAuthCodeSent event, Emitter<AuthState> emit) {
    emit(AuthCodeSent(event.verificationId));
  }

  void _onInternalAuthError(_InternalAuthError event, Emitter<AuthState> emit) {
    emit(AuthError(event.message));
  }
}

// Internal events definitions (I'll just add them to auth_event.dart or here)
class _InternalAuthCodeSent extends AuthEvent {
  final String verificationId;
  _InternalAuthCodeSent(this.verificationId);
}

class _InternalAuthError extends AuthEvent {
  final String message;
  _InternalAuthError(this.message);
}
