import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/listing_card.dart';
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
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<DashboardBloc>().add(RefreshDashboard());
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good Morning,',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.stone),
                                ),
                                Text(
                                  state.user.displayName,
                                  style: AppTextStyles.headlineLarge,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.wheat,
                              backgroundImage: state.user.profileImageUrl != null
                                  ? NetworkImage(state.user.profileImageUrl!)
                                  : null,
                              child: state.user.profileImageUrl == null
                                  ? Text(
                                      state.user.displayName.isNotEmpty
                                          ? state.user.displayName[0].toUpperCase()
                                          : 'G',
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: AppColors.bark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Active Listings',
                              value: state.stats['activeListings'].toString(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Total Earned',
                              value: NumberFormat.compactCurrency(symbol: '\$').format(state.stats['totalEarned']),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Total Hauled',
                              value: state.stats['totalHauled'].toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // AI Agent Input Box
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.bark,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ready to list?',
                              style: AppTextStyles.titleLarge.copyWith(color: AppColors.wheat),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tell the AI agent what you have ready to harvest.',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cream2),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => context.go('/agent'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.moss,
                              ),
                              child: const Text('Open AI Agent'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Listings', style: AppTextStyles.titleLarge),
                          TextButton(
                            onPressed: () => context.go('/listings'),
                            child: const Text('See All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.listings.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text('No listings yet. Start by talking to the agent!'),
                          ),
                        )
                      else
                        ...state.listings.take(5).map((l) => ListingCard(
                              listing: l,
                              onTap: () => context.push('/listings/${l.listingId}'),
                            )),
                    ],
                  ),
                ),
              ),
            );
          } else if (state is DashboardError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox();
        },
      ),
    );
  }
}
