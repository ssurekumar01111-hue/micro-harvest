import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _userData;
  int _totalHauls = 0;
  double _totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('ProfileScreen: User not authenticated, redirecting to auth.');
      if (mounted) context.go('/auth/phone');
      return;
    }

    debugPrint('ProfileScreen: Loading data for user ID: ${user.uid}');

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10)); // Add timeout

      if (!userDoc.exists) {
        throw Exception('User profile not found in Firestore.');
      }

      final handoffsQuery = await FirebaseFirestore.instance
          .collection('handoffs')
          .where('transporterId', isEqualTo: user.uid)
          .where('gate2', isNotEqualTo: null)
          .get()
          .timeout(const Duration(seconds: 10));

      double earnings = 0;
      for (var doc in handoffsQuery.docs) {
        earnings += (doc.data()['payment']?['transporterShare'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _userData = userDoc.data();
          _totalHauls = handoffsQuery.docs.length;
          _totalEarnings = earnings;
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('ProfileScreen: Timeout error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Loading profile timed out. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error loading profile data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load profile: ${e.toString()}. Tap to retry.';
          _isLoading = false;
        });
      }
    }
  }

  String _maskPhone(String? phone) {
    if (phone == null || phone.length < 10) return phone ?? 'N/A';
    return '${phone.substring(0, 3)} ****${phone.substring(phone.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          title: const Text('My Profile'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.bark,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.bark),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadProfileData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = _userData?['displayName'] ?? 'Transporter';
    final initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    final createdAt = (_userData?['createdAt'] as Timestamp?)?.toDate();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.bark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.bark,
              child: Text(initials, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(name, style: AppTextStyles.headlineLarge),
            Text('Member since ${createdAt != null ? DateFormat('MMMM yyyy').format(createdAt) : 'Unknown'}', 
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
            const SizedBox(height: 32),
            Row(
              children: [
                _buildStatCard('Completed', _totalHauls.toString(), Icons.local_shipping),
                const SizedBox(width: 16),
                _buildStatCard('Earnings', NumberFormat.simpleCurrency().format(_totalEarnings), Icons.payments),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoTile('Phone Number', _maskPhone(_userData?['phone'] ?? FirebaseAuth.instance.currentUser?.phoneNumber), Icons.phone),
            if (FirebaseAuth.instance.currentUser?.email != null && FirebaseAuth.instance.currentUser!.email!.isNotEmpty)
              _buildInfoTile('Email', FirebaseAuth.instance.currentUser!.email!, Icons.email),
            _buildInfoTile('Vehicle Type', _userData?['vehicleType'] ?? 'Not specified', Icons.directions_car),
            _buildInfoTile('Operating Radius', '${(_userData?['radiusMiles'] ?? 50).toInt()} km', Icons.radar),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AuthRepository>().signOut();
                  if (context.mounted) context.go('/auth/phone');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.moss, size: 24),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.headlineLarge.copyWith(fontSize: 20)),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.moss.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.moss, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.stone)),
              Text(value, style: AppTextStyles.titleLarge.copyWith(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
