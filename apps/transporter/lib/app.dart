import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/haul_repository.dart';
import 'data/repositories/location_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/screens/phone_otp_screen.dart';
import 'presentation/auth/screens/otp_verify_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/dashboard/bloc/dashboard_bloc.dart';
import 'presentation/haul/bloc/haul_bloc.dart';
import 'presentation/haul/screens/haul_alert_screen.dart';
import 'presentation/gate/bloc/gate_bloc.dart';
import 'presentation/gate/screens/gate1_screen.dart';
import 'presentation/gate/screens/gate2_screen.dart';
import 'presentation/main/transporter_main_screen.dart';
import 'data/models/listing_model.dart';

class MicroHarvestTransporterApp extends StatelessWidget {
  const MicroHarvestTransporterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => HaulRepository()),
        RepositoryProvider(create: (context) => LocationRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(AppStarted()),
          ),
          BlocProvider(
            create: (context) => DashboardBloc(
              authRepository: context.read<AuthRepository>(),
              haulRepository: context.read<HaulRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => HaulBloc(
              authRepository: context.read<AuthRepository>(),
              haulRepository: context.read<HaulRepository>(),
              locationRepository: context.read<LocationRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => GateBloc(
              haulRepository: context.read<HaulRepository>(),
              authRepository: context.read<AuthRepository>(),
            ),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: GoRouterRefreshStream(context.read<AuthBloc>().stream),
      redirect: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final bool loggingIn = state.matchedLocation.startsWith('/auth');
        final bool onboarding = state.matchedLocation == '/onboarding';

        if (authState is AuthUnauthenticated) {
          return loggingIn ? null : '/auth/phone';
        }
        if (authState is AuthNewUser) {
          return onboarding ? null : '/onboarding';
        }
        if (authState is AuthAuthenticated) {
          return (loggingIn || onboarding) ? '/dashboard' : null;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/auth/phone',
          builder: (context, state) => const PhoneOTPScreen(),
        ),
        GoRoute(
          path: '/auth/otp',
          builder: (context, state) {
            final verificationId = state.extra as String;
            return OTPVerifyScreen(verificationId: verificationId);
          },
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const TransporterMainScreen(initialIndex: 0),
        ),
        GoRoute(
          path: '/hauls',
          builder: (context, state) => const TransporterMainScreen(initialIndex: 1),
        ),
        GoRoute(
          path: '/earnings',
          builder: (context, state) => const TransporterMainScreen(initialIndex: 2),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const TransporterMainScreen(initialIndex: 3),
        ),
        GoRoute(
          path: '/haul/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final extra = state.extra;
            if (extra is ListingModel) {
              return HaulAlertScreen(listing: extra);
            }
            return HaulAlertScreen(listing: id);
          },
        ),
        GoRoute(
          path: '/gate1/:id',
          builder: (context, state) => Gate1Screen(handoffId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/gate2/:id',
          builder: (context, state) => Gate2Screen(handoffId: state.pathParameters['id']!),
        ),
      ],
    );

    _setupPermissions();
  }

  Future<void> _setupPermissions() async {
    // 1. Notification Permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Wait a moment for the notification dialog to resolve
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Location Permission (requested AFTER notification)
    if (mounted) {
      await context.read<LocationRepository>().requestPermission();
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && mounted) {
      context.read<AuthRepository>().saveFCMToken(uid);
    }

    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final listingId = message.data['listingId'];
      if (listingId != null) {
        _router.push('/haul/$listingId');
      }
    });

    // Background tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final listingId = message.data['listingId'];
      if (listingId != null) {
        _router.push('/haul/$listingId');
      }
    });

    // Terminated state
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data['listingId'] != null) {
      _router.push('/haul/${initial.data['listingId']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Micro-Harvest Transporter',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
