import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../dashboard/bloc/dashboard_bloc.dart';
import '../../dashboard/bloc/dashboard_state.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/bottom_nav.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.bark, AppColors.soil],
                  ),
                ),
                child: Column(
                  children: [
                    Text('Total Earnings', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.wheat)),
                    const SizedBox(height: 8),
                    Text('\$12,450.00', style: AppTextStyles.displayLarge.copyWith(color: Colors.white, fontSize: 48)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('May 2026', style: TextStyle(color: Colors.white)),
                          Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.cream2,
                        child: Text('🍇'),
                      ),
                      title: Text('Valley Estates', style: AppTextStyles.titleLarge.copyWith(fontSize: 16)),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
                      trailing: Text('+\$450.00', style: AppTextStyles.titleLarge.copyWith(fontSize: 16, color: AppColors.moss)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
