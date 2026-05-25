import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dart_geohash/dart_geohash.dart';
import '../../../core/constants/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime dt;
    if (date is Timestamp) {
      dt = date.toDate();
    } else if (date is DateTime) {
      dt = date;
    } else {
      return '-';
    }
    return DateFormat('MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: uid == null
          ? const Center(child: Text('Not signed in'))
          : StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.moss));
                }
                
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                if (userData == null) return const Center(child: Text('Profile not found'));

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('handoffs')
                      .where('producerId', isEqualTo: uid)
                      .where('gate2', isNotEqualTo: null)
                      .snapshots(),
                  builder: (context, handoffSnapshot) {
                    final completedHauls = handoffSnapshot.data?.docs.length ?? 0;
                    
                    return CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Container(
                            color: AppColors.wheat,
                            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppColors.bark,
                                  child: Text(
                                    (userData['displayName'] as String? ?? 'P')[0].toUpperCase(),
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.wheat,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  userData['displayName'] ?? 'Producer',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.bark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.bark,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text('PRODUCER',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.wheat,
                                        letterSpacing: 1,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Info cards
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Account Info
                              _ProfileCard(
                                title: 'Account Info',
                                children: [
                                  _ProfileRow('Phone', userData['phone'] ?? FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Not set'),
                                  if (FirebaseAuth.instance.currentUser?.email != null && FirebaseAuth.instance.currentUser!.email!.isNotEmpty)
                                    _ProfileRow('Email', FirebaseAuth.instance.currentUser!.email!),
                                  _ProfileRow('Member since', _formatDate(userData['createdAt'])),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Stats
                              _ProfileCard(
                                title: 'Activity',
                                children: [
                                  _ProfileRow('Completed hauls', '$completedHauls'),
                                  _ProfileRow('Radius', '${userData['radiusMiles'] ?? 50} miles'),
                                ],
                              ),
                              const SizedBox(height: 24),

                              _ProfileCard(
                                title: 'Location',
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          'Lat: ${(userData['geoPoint'] as GeoPoint?)?.latitude.toStringAsFixed(4) ?? 'N/A'}, Lon: ${(userData['geoPoint'] as GeoPoint?)?.longitude.toStringAsFixed(4) ?? 'N/A'}',
                                          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.bark)),
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            final position = await Geolocator.getCurrentPosition();
                                            final geohash = GeoHasher().encode(position.longitude, position.latitude);
                                            await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                              'geoPoint': GeoPoint(position.latitude, position.longitude),
                                              'geohash': geohash,
                                            });
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated successfully')));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating location: $e')));
                                            }
                                          }
                                        },
                                        child: Text('Update', style: GoogleFonts.dmSans(color: AppColors.moss)),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Sign out
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.rust,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (context.mounted) {
                                      context.go('/auth/phone');
                                    }
                                  },
                                  child: Text('Sign Out',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      )),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.stone.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.stone,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final displayValue = (value.isEmpty) ? '-' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 15, color: AppColors.stone)),
          Text(displayValue, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.bark)),
        ],
      ),
    );
  }
}
