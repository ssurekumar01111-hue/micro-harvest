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
    } else if (location.startsWith('/active')) {
      currentIndex = 1;
    } else if (location.startsWith('/confirm')) {
      currentIndex = 2;
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) {
          context.go('/dashboard');
        } else if (index == 1) {
          context.go('/active');
        } else if (index == 2) {
          context.go('/confirm');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Discover'),
        BottomNavigationBarItem(icon: Icon(Icons.local_shipping_outlined), label: 'Active'),
        BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Confirm'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}
