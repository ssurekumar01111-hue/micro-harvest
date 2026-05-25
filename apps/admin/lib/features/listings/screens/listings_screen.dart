import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:admin/core/constants/app_colors.dart';
import 'package:admin/core/widgets/data_table_card.dart';
import 'package:admin/core/widgets/status_badge.dart';
import 'package:admin/core/widgets/confirm_dialog.dart';
import 'package:admin/features/listings/bloc/listings_bloc.dart';
import 'package:admin/features/listings/widgets/listing_detail_drawer.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  String? _selectedStatusFilter;
  String? _selectedCropTypeFilter;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _listingStatuses = [
    'ALL',
    'OPEN',
    'MATCHED',
    'IN_TRANSIT',
    'SETTLED',
    'DISPUTED',
    'EXPIRED'
  ];
  final List<String> _cropTypes = [
    'ALL',
    'CORN',
    'WHEAT',
    'SOYBEAN',
    'RICE',
    'BARLEY'
  ]; // Example crop types

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  void _applyFilters() {
    context.read<ListingsBloc>().add(
          FilterListings(
            status: _selectedStatusFilter,
            cropType: _selectedCropTypeFilter,
            query: _searchController.text,
          ),
        );
  }

  void _clearFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedCropTypeFilter = null;
      _searchController.clear();
    });
    context.read<ListingsBloc>().add(LoadListings());
  }

  void _forceExpireListing(BuildContext context, String listingId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ConfirmDialog(
          title: 'Confirm Expiration',
          message: 'Are you sure you want to force expire this listing?',
          onConfirm: () {
            context
                .read<ListingsBloc>()
                .add(ForceExpireListing(listingId: listingId));
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ListingsBloc()..add(LoadListings()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Listings',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.bark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ),
        body: BlocBuilder<ListingsBloc, ListingsState>(
          builder: (context, state) {
            if (state is ListingsLoading && state is! ListingsLoaded) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ListingsError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is ListingsLoaded) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter Bar
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Wrap(
                                spacing: 16.0,
                                runSpacing: 16.0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  DropdownButton<String>(
                                    value: _selectedStatusFilter,
                                    hint: const Text('Status'),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedStatusFilter = newValue;
                                      });
                                    },
                                    items: _listingStatuses
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                  DropdownButton<String>(
                                    value: _selectedCropTypeFilter,
                                    hint: const Text('Crop Type'),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedCropTypeFilter = newValue;
                                      });
                                    },
                                    items: _cropTypes
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: const InputDecoration(
                                        labelText: 'Search Grower',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _applyFilters,
                                    child: const Text('Apply Filters'),
                                  ),
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear Filters'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Listings Data Table
                        Expanded(
                          child: DataTableCard(
                            title: 'All Listings',
                            showCheckboxColumn: false,
                            expand: true,
                            headers: const [
                              'ID',
                              'Crop',
                              'Weight(kg)',
                              'Containers',
                              'Status',
                              'Grower',
                              'Producer',
                              'Price/ton',
                              'Created',
                              'Actions'
                            ],
                            rows: state.listings.map((listing) {
                              final String listingId = listing['id'] ?? 'N/A';
                              final String status = listing['status'] ?? 'UNKNOWN';
                              final bool canExpire = status == 'OPEN' || status == 'MATCHED';
                              final containerType = listing['containerType'] ?? 'N/A';
                              final containerCount = listing['containerCount'] ?? listing['containers'] ?? 'N/A';

                              return DataRow(
                                cells: [
                                  DataCell(Text(listingId.length >= 8
                                      ? listingId.substring(listingId.length - 8)
                                      : listingId)),
                                  DataCell(Text(listing['cropType'] ?? 'N/A')),
                                  DataCell(Text('${listing['weightKg'] ?? 'N/A'} kg')),
                                  DataCell(Text('$containerType ($containerCount)')),
                                  DataCell(StatusBadge(status: status)),
                                  DataCell(Text(listing['growerName'] ?? 'N/A')),
                                  DataCell(Text(listing['producerName'] ?? 'N/A')),
                                  DataCell(Text(listing['askingPriceUSD'] != null 
                                      ? '\$${listing['askingPriceUSD'].toStringAsFixed(2)}' 
                                      : (listing['pricePerTon'] != null ? '\$${listing['pricePerTon'].toStringAsFixed(2)}' : 'TBD'))),
                                  DataCell(Text(_formatDateTime(listing['createdAt'] as Timestamp?))),
                                  DataCell(Row(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          context
                                              .read<ListingsBloc>()
                                              .add(SelectListing(listing: listing));
                                        },
                                        child: const Text('Details'),
                                      ),
                                      if (canExpire)
                                        IconButton(
                                          icon: const Icon(Icons.timer_off, color: AppColors.rust),
                                          onPressed: () => _forceExpireListing(context, listingId),
                                          tooltip: 'Force Expire',
                                        ),
                                    ],
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: state.isLoadingMore
                                    ? null
                                    : () => context.read<ListingsBloc>().add(LoadNextPage()),
                                child: state.isLoadingMore
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Load More'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: state.selectedListing != null ? 400 : 0,
                    child: state.selectedListing != null
                        ? ListingDetailDrawer(listing: state.selectedListing!)
                        : const SizedBox.shrink(),
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
}

