import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/listing_repository.dart';
import 'data/repositories/agent_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/screens/phone_otp_screen.dart';
import 'presentation/auth/screens/otp_verify_screen.dart';
import 'presentation/dashboard/bloc/dashboard_bloc.dart';
import 'presentation/dashboard/screens/dashboard_screen.dart';
import 'presentation/agent/bloc/agent_bloc.dart';
import 'presentation/agent/screens/agent_screen.dart';
import 'presentation/listings/bloc/listings_bloc.dart';
import 'presentation/listings/screens/listings_screen.dart';
import 'presentation/listings/screens/listing_detail_screen.dart';

class MicroHarvestApp extends StatelessWidget {
  const MicroHarvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => ListingRepository()),
        RepositoryProvider(create: (context) => AgentRepository()),
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
              listingRepository: context.read<ListingRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => AgentBloc(
              agentRepository: context.read<AgentRepository>(),
              authRepository: context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ListingsBloc(
              listingRepository: context.read<ListingRepository>(),
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
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/agent',
          builder: (context, state) => const AgentScreen(),
        ),
        GoRoute(
          path: '/listings',
          builder: (context, state) => const ListingsScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => ListingDetailScreen(
                listingId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Micro-Harvest Grower',
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
