import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(LoadDashboard());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is DashboardLoaded) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ready to Haul', style: AppTextStyles.headlineLarge),
                        const CircleAvatar(
                          backgroundColor: AppColors.harvest,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Availability Toggle Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available for Hauls',
                                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "You'll receive haul alerts",
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cream2),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: state.isAvailable,
                            onChanged: (val) {
                              context.read<DashboardBloc>().add(ToggleAvailability(val));
                            },
                            activeTrackColor: AppColors.moss,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Today', '\$${state.todayEarnings.toStringAsFixed(0)}'),
                        _buildStat('Total Hauls', state.totalHauls.toString()),
                        _buildStat('Rating', state.rating.toString()),
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (state.activeHandoff != null) ...[
                      Text('Active Haul', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 16),
                      _buildActiveHaulCard(state.activeHandoff!),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Text('No active hauls. Stay available to receive alerts!'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text('Error loading dashboard'));
        },
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.headlineLarge.copyWith(fontSize: 24)),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone)),
      ],
    );
  }

  Widget _buildActiveHaulCard(dynamic handoff) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.harvest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('IN TRANSIT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Text('02:45 remaining', style: TextStyle(color: AppColors.stone, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppColors.bark, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pinot Noir · 2000kg', style: AppTextStyles.titleLarge.copyWith(fontSize: 18)),
                      const Text('From Valley Estates to Central Winery', style: TextStyle(color: AppColors.stone)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Navigate to gate confirm screen
              },
              child: const Text('Confirm Delivery'),
            ),
          ],
        ),
      ),
    );
  }
}
