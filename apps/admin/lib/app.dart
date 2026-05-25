import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin/features/auth/screens/login_screen.dart';
import 'package:admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:admin/features/listings/screens/listings_screen.dart';
import 'package:admin/features/users/screens/users_screen.dart';
import 'package:admin/features/handoffs/screens/handoffs_screen.dart';
import 'package:admin/features/disputes/screens/disputes_screen.dart';
import 'package:admin/features/analytics/screens/analytics_screen.dart';
import 'package:admin/features/elastic_monitor/screens/elastic_monitor_screen.dart';
import 'package:admin/core/widgets/admin_sidebar.dart';
import 'package:admin/auth_listenable.dart';

import 'package:admin/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:admin/features/listings/bloc/listings_bloc.dart';
import 'package:admin/features/users/bloc/users_bloc.dart';
import 'package:admin/features/handoffs/bloc/handoffs_bloc.dart';
import 'package:admin/features/disputes/bloc/disputes_bloc.dart';
import 'package:admin/features/analytics/bloc/analytics_bloc.dart';

/// Private navigator key for the shell route
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthListenable(FirebaseAuth.instance),
  redirect: (context, state) {
    final bool loggedIn = FirebaseAuth.instance.currentUser != null;
    final bool loggingIn = state.matchedLocation == '/login';

    if (!loggedIn) {
      return loggingIn ? null : '/login';
    }

    if (loggingIn) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => DashboardBloc()..add(LoadDashboard())),
          BlocProvider(create: (context) => ListingsBloc()..add(LoadListings())),
          BlocProvider(create: (context) => UsersBloc()..add(LoadUsers())),
          BlocProvider(create: (context) => HandoffsBloc()..add(LoadHandoffs())),
          BlocProvider(create: (context) => DisputesBloc()..add(LoadDisputes())),
          BlocProvider(create: (context) => AnalyticsBloc()..add(LoadAnalytics())),
        ],
        child: AdminShell(child: child),
      ),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/listings',
          builder: (context, state) => const ListingsScreen(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: '/handoffs',
          builder: (context, state) => const HandoffsScreen(),
        ),
        GoRoute(
          path: '/disputes',
          builder: (context, state) => const DisputesScreen(),
        ),
        GoRoute(
          path: '/analytics',
          builder: (context, state) => const AnalyticsScreen(),
        ),
        GoRoute(
          path: '/elastic-monitor',
          builder: (context, state) => const ElasticMonitorScreen(),
        ),
      ],
    ),
  ],
);

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
