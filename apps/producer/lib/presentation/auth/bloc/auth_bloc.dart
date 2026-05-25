import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<InternalAuthCodeSent>(_onInternalAuthCodeSent);
    on<InternalAuthError>(_onInternalAuthError);
    on<HandleLoginSuccess>(_onHandleLoginSuccess);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final userStream = _authRepository.authStateChanges;
    await emit.forEach(
      userStream,
      onData: (user) {
        if (user != null) {
          add(HandleLoginSuccess(user));
          return state; 
        }
        return AuthUnauthenticated();
      },
    );
  }

  Future<void> _onHandleLoginSuccess(HandleLoginSuccess event, Emitter<AuthState> emit) async {
    final user = event.user;
    final userModel = await _authRepository.getUserFromFirestore(user.uid);
    if (userModel == null) {
      await _authRepository.saveUserToFirestore(user);
    }

    await _authRepository.saveFCMToken(user.uid);

    final isRegistered = await _authRepository.isUserRegistered(user.uid);
    if (isRegistered) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthNewUser(user));
    }
  }

  Future<void> _onPhoneOTPRequested(PhoneOTPRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithPhone(
        phoneNumber: event.phoneNumber,
        codeSent: (verificationId, resendToken) => add(InternalAuthCodeSent(verificationId)),
        verificationFailed: (e) => add(InternalAuthError(e.message ?? 'Verification failed')),
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
      final user = userCredential.user;
      if (user != null) {
        await _authRepository.saveUserToFirestore(user);
        add(HandleLoginSuccess(user));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(GoogleSignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _authRepository.signInWithGoogle();
      final user = userCredential?.user;
      if (user != null) {
        await _authRepository.saveUserToFirestore(user);
        add(HandleLoginSuccess(user));
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

  void _onInternalAuthCodeSent(InternalAuthCodeSent event, Emitter<AuthState> emit) {
    emit(AuthCodeSent(event.verificationId));
  }

  void _onInternalAuthError(InternalAuthError event, Emitter<AuthState> emit) {
    emit(AuthError(event.message));
  }
}
