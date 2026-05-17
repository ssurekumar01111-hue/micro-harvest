import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/listings_bloc.dart';
import '../bloc/listings_event.dart';
import '../bloc/listings_state.dart';
import '../../../data/models/listing_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/bottom_nav.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key});

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  ListingStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    context.read<ListingsBloc>().add(LoadListings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const BottomNav(),
      appBar: AppBar(
        title: Text('My Harvests', style: AppTextStyles.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BlocBuilder<ListingsBloc, ListingsState>(
        builder: (context, state) {
          if (state is ListingsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ListingsLoaded) {
            final filteredListings = _selectedStatus == null
                ? state.listings
                : state.listings.where((l) => l.status == _selectedStatus).toList();

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedStatus == null,
                        onSelected: (val) => setState(() => _selectedStatus = null),
                        selectedColor: AppColors.moss,
                        labelStyle: TextStyle(color: _selectedStatus == null ? Colors.white : AppColors.bark),
                      ),
                      const SizedBox(width: 8),
                      ...ListingStatus.values.map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(status.name),
                          selected: _selectedStatus == status,
                          onSelected: (val) => setState(() => _selectedStatus = status),
                          selectedColor: AppColors.moss,
                          labelStyle: TextStyle(color: _selectedStatus == status ? Colors.white : AppColors.bark),
                        ),
                      )),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredListings.length,
                    itemBuilder: (context, index) {
                      return ListingCard(
                        listing: filteredListings[index],
                        onTap: () => context.push('/listings/${filteredListings[index].listingId}'),
                      );
                    },
                  ),
                ),
              ],
            );
          } else if (state is ListingsError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox();
        },
      ),
    );
  }
}
