import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/features/analytics/bloc/analytics_bloc.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnalyticsBloc()..add(LoadAnalytics()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Analytics',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.bark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<AnalyticsBloc>().add(RefreshAnalytics());
              },
            ),
          ],
        ),
        body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
          builder: (context, state) {
            if (state is AnalyticsLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is AnalyticsError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is AnalyticsLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Charts Grid
                    Wrap(
                      spacing: 16.0,
                      runSpacing: 16.0,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 900 
                              ? (MediaQuery.of(context).size.width - 64) / 2 
                              : MediaQuery.of(context).size.width - 32,
                          child: _buildChartCard(
                            context,
                            'Listings Created — Last 30 Days',
                            _buildLineChart(state.listingsCreatedLast30Days),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 900 
                              ? (MediaQuery.of(context).size.width - 64) / 2 
                              : MediaQuery.of(context).size.width - 32,
                          child: _buildChartCard(
                            context,
                            'Revenue by Crop Type (Top 5)',
                            _buildBarChartRevenue(state.revenueByCropType),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 900 
                              ? (MediaQuery.of(context).size.width - 64) / 2 
                              : MediaQuery.of(context).size.width - 32,
                          child: _buildChartCard(
                            context,
                            'Users by Role',
                            _buildPieChartUsers(state.usersByRole),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width > 900 
                              ? (MediaQuery.of(context).size.width - 64) / 2 
                              : MediaQuery.of(context).size.width - 32,
                          child: _buildChartCard(
                            context,
                            'Handoffs by Status',
                            _buildBarChartHandoffs(state.handoffsByStatus),
                          ),
                        ),
                      ],
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

  Widget _buildChartCard(BuildContext context, String title, Widget chart) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<String, int> data) {
    final List<FlSpot> spots = [];
    final List<String> xTitles = [];
    final sortedKeys = data.keys.toList()..sort();

    for (int i = 0; i < sortedKeys.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[sortedKeys[i]]!.toDouble()));
      xTitles.add(sortedKeys[i]);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.stone.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (value) => FlLine(
            color: AppColors.stone.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 5 == 0 && value.toInt() < xTitles.length) {
                  final dateStr = xTitles[value.toInt()];
                  String formatted = dateStr;
                  try {
                    formatted = DateFormat('MMM dd').format(DateTime.parse(dateStr));
                  } catch (e) {
                    // Ignore, show raw string
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(formatted,
                        style: GoogleFonts.dmSans(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(),
                    style: GoogleFonts.dmSans(fontSize: 10));
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppColors.stone.withValues(alpha: 0.5), width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [AppColors.moss, AppColors.moss.withValues(alpha: 0.5)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.moss.withValues(alpha: 0.3),
                  AppColors.moss.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartRevenue(Map<String, double> data) {
    final List<BarChartGroupData> barGroups = [];
    final List<String> cropLabels = data.keys.toList();

    for (int i = 0; i < cropLabels.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[cropLabels[i]]!,
              color: AppColors.harvest,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(cropLabels[value.toInt()],
                      style: GoogleFonts.dmSans(fontSize: 10)),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(NumberFormat.compactSimpleCurrency().format(value),
                    style: GoogleFonts.dmSans(fontSize: 10));
              },
              reservedSize: 40,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.stone.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppColors.stone.withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }

  Widget _buildPieChartUsers(Map<String, int> data) {
    int totalUsers = data.values.fold(0, (sum, count) => sum + count);
    final List<PieChartSectionData> sections = [];
    final Map<String, Color> roleColors = {
      'GROWER': AppColors.moss,
      'PRODUCER': AppColors.wheat,
      'TRANSPORTER': AppColors.harvest,
      'ADMIN': AppColors.rust,
      'UNKNOWN': AppColors.stone,
    };

    data.forEach((role, count) {
      final double percentage = (count / totalUsers) * 100;
      sections.add(
        PieChartSectionData(
          color: roleColors[role] ?? AppColors.stone,
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: Text(role, style: GoogleFonts.dmSans(fontSize: 10)),
          badgePositionPercentageOffset: 1.1,
        ),
      );
    });

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        startDegreeOffset: -90,
      ),
    );
  }

  Widget _buildBarChartHandoffs(Map<String, int> data) {
    final List<BarChartGroupData> barGroups = [];
    final List<String> statusLabels = data.keys.toList();
    final Map<String, Color> statusColors = {
      'OPEN': AppColors.moss,
      'MATCHED': AppColors.wheat,
      'IN_TRANSIT': AppColors.harvest,
      'SETTLED': AppColors.moss.withValues(alpha: 0.7),
      'DISPUTED': AppColors.rust,
      'UNKNOWN': AppColors.stone,
    };

    for (int i = 0; i < statusLabels.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: data[statusLabels[i]]!.toDouble(),
              color: statusColors[statusLabels[i]] ?? AppColors.stone,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(statusLabels[value.toInt()],
                      style: GoogleFonts.dmSans(fontSize: 10)),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(),
                    style: GoogleFonts.dmSans(fontSize: 10));
              },
              reservedSize: 40,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.stone.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: AppColors.stone.withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }
}

