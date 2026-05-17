import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
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
                CircleAvatar(
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
                const SizedBox(height: 16),
                Text(
                  user.displayName.isEmpty ? 'Unknown User' : user.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontFamily: 'Playfair Display',
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.phone,
                  style: const TextStyle(color: AppColors.stone),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.moss.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    user.role.name,
                    style: const TextStyle(
                      color: AppColors.moss,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Account Info Card
                _buildCard(
                  context,
                  title: 'Account Info',
                  children: [
                    _buildInfoRow('Phone', user.phone),
                    _buildInfoRow(
                      'Member Since',
                      DateFormat.yMMMd().format(user.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                      activeColor: AppColors.moss,
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: false, // Placeholder
                      onChanged: (val) {},
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.moss,
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
            color: Colors.black.withOpacity(0.05),
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
}
