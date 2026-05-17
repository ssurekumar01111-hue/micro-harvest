import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/discovery_repository.dart';
import 'data/repositories/handoff_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/screens/phone_otp_screen.dart';
import 'presentation/auth/screens/otp_verify_screen.dart';
import 'presentation/discovery/bloc/discovery_bloc.dart';
import 'presentation/discovery/screens/discovery_screen.dart';
import 'presentation/discovery/screens/listing_detail_screen.dart';
import 'presentation/active/screens/active_hauls_screen.dart';
import 'presentation/confirm/bloc/confirm_bloc.dart';
import 'presentation/confirm/screens/cargo_confirm_screen.dart';

class MicroHarvestProducerApp extends StatelessWidget {
  const MicroHarvestProducerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => DiscoveryRepository()),
        RepositoryProvider(create: (context) => HandoffRepository()),
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

        if (authState is AuthUnauthenticated) {
          return loggingIn ? null : '/auth/phone';
        }
        if (authState is AuthAuthenticated) {
          return loggingIn ? '/dashboard' : null;
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
          path: '/dashboard',
          builder: (context, state) => const DiscoveryScreen(),
        ),
        GoRoute(
          path: '/listing/:id',
          builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/active',
          builder: (context, state) => const ActiveHaulsScreen(),
        ),
        GoRoute(
          path: '/confirm',
          builder: (context, state) {
            final handoffId = state.extra as String? ?? '';
            return CargoConfirmScreen(handoffId: handoffId);
          },
        ),
      ],
    );
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
