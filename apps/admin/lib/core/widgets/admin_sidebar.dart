import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:admin/core/constants/app_colors.dart';

class AdminSidebar extends StatefulWidget {
  const AdminSidebar({super.key});

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  bool _isCollapsed = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isCollapsed ? 70 : 240,
      color: AppColors.bark,
      child: ClipRect(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Align(
              alignment: _isCollapsed ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                  _isCollapsed ? Icons.menu : Icons.menu_open,
                  color: AppColors.wheat,
                ),
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              ),
            ),
            _buildLogo(),
            Expanded(
              child: ListView(
                children: [
                  _buildSidebarItem(Icons.dashboard, 'Dashboard', '/dashboard'),
                  _buildSidebarItem(Icons.list_alt, 'Listings', '/listings'),
                  _buildSidebarItem(Icons.people, 'Users', '/users'),
                  _buildSidebarItem(Icons.compare_arrows, 'Handoffs', '/handoffs'),
                  _buildSidebarItem(Icons.warning, 'Disputes', '/disputes'),
                  _buildSidebarItem(Icons.analytics, 'Analytics', '/analytics'),
                  _buildSidebarItem(Icons.search, 'Elastic Monitor', '/elastic-monitor'),
                ],
              ),
            ),
            _buildUserInfo(),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: 240,
          child: _isCollapsed
              ? const Center(
                  child: Icon(
                    Icons.agriculture,
                    color: AppColors.wheat,
                    size: 30,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.agriculture,
                      color: AppColors.wheat,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Micro-Harvest',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.wheat,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, String route) {
    final String location = GoRouterState.of(context).matchedLocation;
    final bool isActive = location == route;
    
    return Tooltip(
      message: _isCollapsed ? title : '',
      child: InkWell(
        onTap: () {
          if (!isActive) GoRouter.of(context).go(route);
        },
        child: Container(
          height: 50,
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.moss.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? const Border(left: BorderSide(color: AppColors.moss, width: 4))
                : null,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 240, // Fixed width for content to prevent inner overflow
              child: Row(
                mainAxisAlignment: _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 24 : 16),
                    child: Icon(
                      icon,
                      color: isActive ? AppColors.moss : AppColors.stone,
                      size: 22,
                    ),
                  ),
                  if (!_isCollapsed)
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: isActive ? AppColors.moss : AppColors.stone,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    if (_isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Icon(Icons.person, color: AppColors.stone, size: 20),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Divider(color: AppColors.stone.withValues(alpha: 0.3)),
          Text(
            currentUser?.email ?? 'admin@microharvest.com',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: AppColors.stone,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: _isCollapsed ? 54 : 224,
          child: _isCollapsed
              ? Center(
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.rust),
                    onPressed: _logout,
                    tooltip: 'Logout',
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rust,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    onPressed: _logout,
                  ),
                ),
        ),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      GoRouter.of(context).go('/login');
    }
  }
}

