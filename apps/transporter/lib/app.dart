import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/haul_repository.dart';
import 'data/repositories/location_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/screens/phone_otp_screen.dart';
import 'presentation/auth/screens/otp_verify_screen.dart';
import 'presentation/dashboard/bloc/dashboard_bloc.dart';
import 'presentation/dashboard/screens/dashboard_screen.dart';
import 'presentation/haul/bloc/haul_bloc.dart';
import 'presentation/haul/screens/haul_alert_screen.dart';
import 'presentation/gate/bloc/gate_bloc.dart';
import 'presentation/gate/screens/gate1_screen.dart';
import 'presentation/gate/screens/gate2_screen.dart';
import 'presentation/earnings/screens/earnings_screen.dart';

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
              locationRepository: context.read<LocationRepository>(),
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
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/haul/:id',
          builder: (context, state) => HaulAlertScreen(listing: state.extra),
        ),
        GoRoute(
          path: '/gate1/:id',
          builder: (context, state) => Gate1Screen(handoffId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/gate2/:id',
          builder: (context, state) => Gate2Screen(handoffId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/earnings',
          builder: (context, state) => const EarningsScreen(),
        ),
      ],
    );
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
