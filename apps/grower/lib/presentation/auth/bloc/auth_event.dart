import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class PhoneOTPRequested extends AuthEvent {
  final String phoneNumber;
  PhoneOTPRequested(this.phoneNumber);
}

class OTPVerified extends AuthEvent {
  final String verificationId;
  final String smsCode;
  OTPVerified(this.verificationId, this.smsCode);
}

class GoogleSignInRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}
