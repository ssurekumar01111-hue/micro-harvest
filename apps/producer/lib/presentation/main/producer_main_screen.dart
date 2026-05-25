import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../discovery/screens/discovery_screen.dart';
import '../search/bloc/search_bloc.dart';
import '../search/screens/search_screen.dart';
import '../active/screens/active_hauls_screen.dart';
import '../purchases/screens/purchases_screen.dart';
import '../profile/screens/profile_screen.dart';
import 'navigation_provider.dart';

class ProducerMainScreen extends StatefulWidget {
  const ProducerMainScreen({super.key});

  @override
  State<ProducerMainScreen> createState() => _ProducerMainScreenState();
}

class _ProducerMainScreenState extends State<ProducerMainScreen> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DiscoveryScreen(),
      BlocProvider(
        create: (_) => SearchBloc(),
        child: const SearchScreen(),
      ),
      ActiveHaulsScreen(
        onGoToDiscover: () => context.read<NavigationProvider>().setIndex(0),
      ),
      const PurchasesScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<NavigationProvider>().currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.read<NavigationProvider>().setIndex(index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.moss,
        unselectedItemColor: AppColors.stone,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_search_outlined),
            activeIcon: Icon(Icons.manage_search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Active',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Purchases',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
