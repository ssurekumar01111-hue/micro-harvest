import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/features/elastic_monitor/bloc/elastic_monitor_bloc.dart';
import 'package:admin/features/elastic_monitor/models/elastic_listing.dart';

class ElasticMonitorScreen extends StatefulWidget {
  const ElasticMonitorScreen({super.key});

  @override
  State<ElasticMonitorScreen> createState() => _ElasticMonitorScreenState();
}

class _ElasticMonitorScreenState extends State<ElasticMonitorScreen> {
  final _queryController = TextEditingController();
  double _radius = 50.0;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime date;
    if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return 'N/A';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ElasticMonitorBloc()..add(LoadElasticStats()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Elastic Monitor',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.bark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: BlocBuilder<ElasticMonitorBloc, ElasticMonitorState>(
          builder: (context, state) {
            if (state is ElasticMonitorLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ElasticMonitorError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${state.message}', style: const TextStyle(color: AppColors.rust)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<ElasticMonitorBloc>().add(LoadElasticStats()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            } else if (state is ElasticMonitorLoaded) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel: Index Health
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Index Health', style: Theme.of(context).textTheme.headlineSmall),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: state.indexHealth['isHealthy'] == true ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              _buildInfoRow('Index Name', 'micro-harvest-listings'),
                              _buildInfoRow('Total Listings', state.indexHealth['totalDocuments'].toString()),
                              _buildInfoRow('Total Users', state.indexHealth['usersIndexed'].toString()),
                              _buildInfoRow('Cluster Status', (state.indexHealth['status'] as String).toUpperCase()),
                              _buildInfoRow('Last Indexed', _formatDateTime(state.indexHealth['lastIndexedAt'])),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.read<ElasticMonitorBloc>().add(RefreshStats()),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right Panel: Live Search Test
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Live Search Test', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _queryController,
                                decoration: const InputDecoration(
                                  labelText: 'Search Query',
                                  hintText: 'Enter crop type or leave blank',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text('Radius: ${_radius.toInt()} miles', style: GoogleFonts.dmSans()),
                                  Expanded(
                                    child: Slider(
                                      value: _radius,
                                      min: 10,
                                      max: 100,
                                      divisions: 9,
                                      activeColor: AppColors.moss,
                                      onChanged: (value) {
                                        setState(() {
                                          _radius = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: state.isSearching
                                      ? null
                                      : () {
                                          context.read<ElasticMonitorBloc>().add(
                                                RunTestSearch(
                                                  query: _queryController.text,
                                                  radius: _radius,
                                                  latitude: 25.485, // Banda
                                                  longitude: 80.343,
                                                ),
                                              );
                                        },
                                  child: state.isSearching
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Run Search'),
                                ),
                              ),
                              const Divider(height: 48),
                              if (state.searchResults.isNotEmpty || state.searchTimeMs > 0) ...[
                                Text(
                                  '${state.totalSearchResults} results returned in ${state.searchTimeMs}ms',
                                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.stone),
                                ),
                                const SizedBox(height: 16),
                                ...state.searchResults.map((result) => _buildResultCard(result as ElasticListing)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(color: AppColors.stone)),
          Text(value, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.bark)),
        ],
      ),
    );
  }

  Widget _buildResultCard(ElasticListing listing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cream.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  listing.cropType.toUpperCase(),
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: AppColors.moss),
                ),
                Text(
                  '${listing.weightKg.toStringAsFixed(0)} kg',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Urgency: ${listing.urgency}', style: GoogleFonts.dmSans(fontSize: 12)),
                Text('\$${listing.askingPricePerTon.toStringAsFixed(0)}/ton', style: GoogleFonts.dmSans(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${listing.location['lat']}, ${listing.location['lon']}',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.stone),
            ),
          ],
        ),
      ),
    );
  }
}

