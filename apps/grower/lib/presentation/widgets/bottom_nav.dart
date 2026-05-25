import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    
    int currentIndex = 0;
    if (location.startsWith('/dashboard')) {
      currentIndex = 0;
    } else if (location.startsWith('/agent')) {
      currentIndex = 1;
    } else if (location.startsWith('/listings')) {
      currentIndex = 2;
    } else if (location.startsWith('/earnings')) {
      currentIndex = 3;
    } else if (location.startsWith('/profile')) {
      currentIndex = 4;
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) {
          context.go('/dashboard');
        } else if (index == 1) {
          context.go('/agent');
        } else if (index == 2) {
          context.go('/listings');
        } else if (index == 3) {
          context.go('/earnings');
        } else if (index == 4) {
          context.go('/profile');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI Agent'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Listings'),
        BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Earnings'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}
