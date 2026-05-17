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
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 0) {
          context.go('/dashboard');
        } else if (index == 1) {
          context.go('/agent');
        } else if (index == 2) {
          context.go('/listings');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), label: 'AI Agent'),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Listings'),
      ],
    );
  }
}
