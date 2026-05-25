import 'package:admin/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:admin/app.dart';
import 'package:admin/features/auth/bloc/auth_bloc.dart';
import 'package:admin/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    BlocProvider<AuthBloc>(
      create: (context) => AuthBloc(),
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Micro-Harvest Admin',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
