import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        bottomNavigationBar: const BottomNav(),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.cream,
          elevation: 0,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Error loading profile or profile not found'));
            }

            final user = UserModel.fromFirestore(snapshot.data!);
            final initial = user.displayName.isNotEmpty
                ? user.displayName.substring(0, 1).toUpperCase()
                : '?';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      user.profileImageUrl != null
                          ? CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(user.profileImageUrl!),
                            )
                          : CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.moss,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName.isEmpty ? 'Unknown User' : user.displayName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (user.farmName != null && user.farmName!.isNotEmpty)
                              Text(
                                user.farmName!,
                                style: const TextStyle(color: AppColors.stone),
                              ),
                            Text(
                              user.phone,
                              style: const TextStyle(color: AppColors.stone, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.moss),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => OnboardingScreen(initialUser: user),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Earned', '\$${user.totalEarned.toStringAsFixed(0)}'),
                      _buildStatColumn('Hauled', '${user.totalHauled}'),
                      _buildStatColumn('Active', 'AVAILABLE'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Location Card
                  _buildCard(
                    context,
                    title: 'Farm Location',
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.moss, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Lat: ${user.geoPoint.latitude.toStringAsFixed(2)}, Lng: ${user.geoPoint.longitude.toStringAsFixed(2)}",
                            style: const TextStyle(color: AppColors.bark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Alert radius: ${user.radiusMiles.toInt()} miles",
                        style: const TextStyle(color: AppColors.stone, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Crops Card
                  _buildCard(
                    context,
                    title: 'Crop Interests',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: user.cropInterests.map((crop) {
                          return Chip(
                            label: Text(crop, style: const TextStyle(fontSize: 12)),
                            backgroundColor: AppColors.moss.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                      if (user.harvestSize != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Typical harvest: ${user.harvestSize}",
                          style: const TextStyle(color: AppColors.stone, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Info Card
                  _buildCard(
                    context,
                    title: 'Account Info',
                    children: [
                      _buildInfoRow('Member Since', DateFormat.yMMMd().format(user.createdAt)),
                      _buildInfoRow('Verification Status', user.verified ? 'Verified' : 'Pending'),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // App Settings Card
                  _buildCard(
                    context,
                    title: 'App Settings',
                    children: [
                      SwitchListTile(
                        title: const Text('Notifications'),
                        value: true, // Placeholder for SharedPreferences
                        onChanged: (val) {},
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.moss,
                      ),
                      SwitchListTile(
                        title: const Text('Dark Mode'),
                        value: false, // Placeholder
                        onChanged: (val) {},
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: AppColors.moss,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Sign Out Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        await context.read<AuthRepository>().signOut();
                        if (context.mounted) {
                          context.go('/auth/phone');
                        }
                      },
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.stone)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.moss,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.stone,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
