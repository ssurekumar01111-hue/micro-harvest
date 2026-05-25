import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/stat_card.dart';
import 'package:admin/core/widgets/data_table_card.dart';
import 'package:admin/core/widgets/status_badge.dart';
import 'package:admin/features/dashboard/bloc/dashboard_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatCurrency(double amount) {
    final formatCurrency = NumberFormat.simpleCurrency(locale: 'en_US');
    return formatCurrency.format(amount);
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is String) {
      try {
        return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(timestamp));
      } catch (e) {
        return 'Invalid Date';
      }
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc()..add(LoadDashboard()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Dashboard',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.bark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is DashboardError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is DashboardLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stat Cards
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 16.0,
                      children: [
                        StatCard(
                          title: 'Total Listings',
                          value: state.totalListings.toString(),
                          subtitle: '${state.activeListings} active / ${state.settledListings} settled',
                          color: AppColors.moss,
                          icon: Icons.list_alt,
                        ),
                        StatCard(
                          title: 'Total Handoffs',
                          value: state.totalHandoffs.toString(),
                          subtitle: 'All time handoffs',
                          color: AppColors.harvest,
                          icon: Icons.compare_arrows,
                        ),
                        StatCard(
                          title: 'Total Revenue',
                          value: _formatCurrency(state.totalRevenueUsd),
                          subtitle: 'Settled payments',
                          color: AppColors.wheat,
                          icon: Icons.attach_money,
                        ),
                        StatCard(
                          title: 'Platform Fees',
                          value: _formatCurrency(state.platformFeesUsd),
                          subtitle: 'Collected fees',
                          color: AppColors.bark,
                          icon: Icons.account_balance_wallet,
                        ),
                        StatCard(
                          title: 'Total Users',
                          value: state.registeredUsers.toString(),
                          subtitle: '${state.totalGrowers} G / ${state.totalProducers} P / ${state.totalTransporters} T',
                          color: AppColors.rust,
                          icon: Icons.people,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent Listings
                    DataTableCard(
                      title: 'Recent Listings',
                      showCheckboxColumn: false,
                      headers: const [
                        'Crop Type',
                        'Weight',
                        'Status',
                        'Grower',
                        'Created'
                      ],
                      rows: state.recentListings.map((listing) {
                        return DataRow(
                          cells: [
                            DataCell(Text(listing['cropType'] ?? 'N/A')),
                            DataCell(Text('${listing['weightKg'] ?? 'N/A'} kg')),
                            DataCell(StatusBadge(status: listing['status'] ?? 'UNKNOWN')),
                            DataCell(Text(listing['growerName'] ?? 'N/A')),
                            DataCell(Text(_formatDateTime(listing['createdAt'] as Timestamp?))),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Recent Handoffs
                    DataTableCard(
                      title: 'Recent Handoffs',
                      showCheckboxColumn: false,
                      headers: const [
                        'Crop',
                        'Route',
                        'Transporter',
                        'Status',
                        'Amount'
                      ],
                      rows: state.recentHandoffs.map((handoff) {
                        return DataRow(
                          cells: [
                            DataCell(Text(handoff['_cropType'] ?? 'N/A')),
                            DataCell(Text(
                                '${handoff['_growerName'] ?? 'N/A'} → ${handoff['_producerName'] ?? 'N/A'}')),
                            DataCell(Text(handoff['_transporterName'] ?? 'N/A')),
                            DataCell(StatusBadge(status: handoff['_status'] ?? 'UNKNOWN')),
                            DataCell(Text(_formatCurrency(
                                (handoff['payment']?['totalUSD'] as num?)?.toDouble() ?? 0.0))),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

