import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/discovery_repository.dart';
import 'data/repositories/handoff_repository.dart';
import 'data/repositories/location_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/screens/phone_otp_screen.dart';
import 'presentation/auth/screens/otp_verify_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/discovery/bloc/discovery_bloc.dart';
import 'presentation/discovery/screens/listing_detail_screen.dart';
import 'presentation/confirm/bloc/confirm_bloc.dart';
import 'presentation/search/bloc/search_bloc.dart';
import 'presentation/search/screens/search_screen.dart';
import 'presentation/main/producer_main_screen.dart';
import 'presentation/main/navigation_provider.dart';

class MicroHarvestProducerApp extends StatelessWidget {
  const MicroHarvestProducerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => DiscoveryRepository()),
        RepositoryProvider(create: (context) => HandoffRepository()),
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
            create: (context) => DiscoveryBloc(
              discoveryRepository: context.read<DiscoveryRepository>(),
              handoffRepository: context.read<HandoffRepository>(),
              authRepository: context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ConfirmBloc(
              handoffRepository: context.read<HandoffRepository>(),
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
          builder: (context, state) => const ProducerMainScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => BlocProvider(
            create: (_) => SearchBloc(),
            child: const SearchScreen(),
          ),
        ),
        GoRoute(
          path: '/listing/:id',
          builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Micro-Harvest Producer',
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
