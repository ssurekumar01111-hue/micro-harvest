import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Stripe.publishableKey = const String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
    await Stripe.instance.applySettings();
  } catch (e) {
    // If it's already initialized, we can safely ignore this error.
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
  }
  runApp(const MicroHarvestProducerApp());
}
