import 'dart:ui';

import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../models/category_place_models.dart';

class CategoryWithPlacesScreen extends StatefulWidget {
  const CategoryWithPlacesScreen({
    Key? key,
    this.initialCategoryIndex = 0,
    this.categories,
  }) : super(key: key);

  final int initialCategoryIndex;
  final List<CategoryModel>? categories;

  @override
  State<CategoryWithPlacesScreen> createState() => _CategoryWithPlacesScreenState();
}

class _CategoryWithPlacesScreenState extends State<CategoryWithPlacesScreen> {
  int _activeCategoryIndex = 0;
  late final List<CategoryModel> _categories;

  @override
  void initState() {
    super.initState();
    _categories = widget.categories ?? CategoryRepository.loadMock();
    if (_categories.isNotEmpty) {
      _activeCategoryIndex = widget.initialCategoryIndex.clamp(0, _categories.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final chipSize = width < 360 ? 64.0 : 72.0;
    if (_categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: SafeArea(
          child: Center(
            child: Text('No categories available.', style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    final activeCategory = _categories[_activeCategoryIndex];
    final places = activeCategory.places;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: 'Search destination',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: chipSize + 8,
                      child: SingleChildScrollView(
                        child: Column(
                          children: List.generate(
                            _categories.length,
                            (index) {
                              final isActive = index == _activeCategoryIndex;
                              final item = _categories[index];

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _activeCategoryIndex = index;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: chipSize,
                                    height: chipSize,
                                    decoration: BoxDecoration(
                                      color: isActive ? const Color(0xFFE2C26D) : const Color(0xFF1F1F1F),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isActive ? const Color(0xFFF6D98F) : Colors.white10,
                                        width: 1.2,
                                      ),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFE2C26D).withOpacity(0.35),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          color: isActive ? Colors.black : Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.label,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isActive ? Colors.black : Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                              .animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(position: offsetAnimation, child: child),
                          );
                        },
                        child: Container(
                          key: ValueKey(_activeCategoryIndex),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: places.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No places found in this category.',
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: places.length + 1,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    if (index == places.length) {
                                      return OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white70,
                                          side: const BorderSide(color: Colors.white24),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: () => Navigator.pushNamed(context, '/location_map_selection'),
                                        child: const Text('Choose on map', style: TextStyle(fontSize: 12)),
                                      );
                                    }

                                    final place = places[index];
                                    return _PlaceTile(
                                      title: place.title,
                                      subtitle: place.subtitle,
                                      status: place.status,
                                      distance: place.distance,
                                      onTap: () {
                                        MockData.destination = place.title;
                                        MockData.routeSummary = '${MockData.pickup} -> ${place.title}';
                                        Navigator.pushNamed(context, '/location_map_selection');
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? status;
  final String distance;
  final VoidCallback? onTap;

  const _PlaceTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.distance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'Open';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFE2C26D), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if (status != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          status!,
                          style: TextStyle(
                            color: isOpen ? const Color(0xFFE2C26D) : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(distance, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class CategoryRepository {
  static List<CategoryModel> loadMock() {
    const apiPayload = [
      {
        'icon': 'food',
        'label': 'Food',
        'places': [
          {'title': 'Crab & Bites', 'subtitle': 'Kapt. Pepe', 'status': 'Open', 'distance': '2 km'},
          {'title': 'Jollibee Circum', 'subtitle': 'Circumferential Road', 'status': 'Closed', 'distance': '5 km'},
          {'title': "McDonald's Sancianco", 'subtitle': 'Maharlika Highway', 'status': null, 'distance': '8 km'},
          {'title': 'Mang Inasal', 'subtitle': 'Zabarte Road', 'status': 'Open', 'distance': '4 km'},
          {'title': 'Chowking Gen. Tinio', 'subtitle': 'Gen. Tinio St', 'status': null, 'distance': '3 km'},
        ],
      },
      {
        'icon': 'school',
        'label': 'School',
        'places': [
          {'title': 'Wesleyan University Philippines', 'subtitle': 'Mabini Extension', 'status': null, 'distance': '5 km'},
          {'title': 'NEUST', 'subtitle': 'Sumacab Campus', 'status': null, 'distance': '6 km'},
          {'title': 'AMA College', 'subtitle': 'Cabanatuan City', 'status': null, 'distance': '7 km'},
          {'title': 'College of the Immaculate Conception', 'subtitle': 'Burgos Ave', 'status': null, 'distance': '4 km'},
          {'title': 'Cabanatuan City Science High School', 'subtitle': 'Del Pilar St', 'status': null, 'distance': '5 km'},
        ],
      },
      {
        'icon': 'mall',
        'label': 'Mall',
        'places': [
          {'title': 'SM Cabanatuan', 'subtitle': 'Maharlika Highway', 'status': null, 'distance': '4 km'},
          {'title': 'WalterMart', 'subtitle': 'Zabarte Road', 'status': null, 'distance': '3 km'},
          {'title': 'NE Mall', 'subtitle': 'Gen. Tinio St', 'status': null, 'distance': '4 km'},
          {'title': 'Gapan City Mall', 'subtitle': 'Maharlika Highway', 'status': null, 'distance': '18 km'},
        ],
      },
      {
        'icon': 'cafe',
        'label': 'Cafe',
        'places': [
          {'title': 'Brew Lab', 'subtitle': 'Sumacab', 'status': 'Open', 'distance': '2 km'},
          {'title': 'Daily Grind', 'subtitle': 'Aguinaldo St', 'status': 'Open', 'distance': '3 km'},
          {'title': 'Bean & Co', 'subtitle': 'Caloocan Rd', 'status': 'Closed', 'distance': '6 km'},
          {'title': 'Cafe Horizon', 'subtitle': 'Mabini Extension', 'status': 'Open', 'distance': '3 km'},
        ],
      },
      {
        'icon': 'mart',
        'label': 'Mart',
        'places': [
          {'title': 'Savemore', 'subtitle': 'Maharlika Highway', 'status': null, 'distance': '3 km'},
          {'title': 'Puregold', 'subtitle': 'Cabanatuan City', 'status': null, 'distance': '4 km'},
          {'title': 'City Supermarket', 'subtitle': 'Zulueta St', 'status': null, 'distance': '2 km'},
          {'title': 'Central Market', 'subtitle': 'Public Market', 'status': null, 'distance': '2 km'},
        ],
      },
      {
        'icon': 'hospital',
        'label': 'Hospital',
        'places': [
          {'title': 'Dr. Paulino J. Garcia Hospital', 'subtitle': 'Maharlika Highway', 'status': null, 'distance': '6 km'},
          {'title': 'Wesleyan University Hospital', 'subtitle': 'Mabini Extension', 'status': null, 'distance': '5 km'},
          {'title': 'MV Gallego Foundation Hospital', 'subtitle': 'F. Vergara Hwy', 'status': null, 'distance': '7 km'},
        ],
      },
      {
        'icon': 'park',
        'label': 'Park',
        'places': [
          {'title': 'Freedom Park', 'subtitle': 'Cabanatuan City', 'status': null, 'distance': '3 km'},
          {'title': 'Camp Tinio Park', 'subtitle': 'Camp Tinio', 'status': null, 'distance': '4 km'},
        ],
      },
      {
        'icon': 'office',
        'label': 'Office',
        'places': [
          {'title': 'City Hall', 'subtitle': 'Cabanatuan City', 'status': null, 'distance': '3 km'},
          {'title': 'Provincial Capitol', 'subtitle': 'Palayan City', 'status': null, 'distance': '19 km'},
        ],
      },
      {
        'icon': 'airport',
        'label': 'Airport',
        'places': [
          {'title': 'Bongabon Airport', 'subtitle': 'Bongabon', 'status': null, 'distance': '28 km'},
        ],
      },
      {
        'icon': 'hotel',
        'label': 'Hotel',
        'places': [
          {'title': 'Harvest Hotel', 'subtitle': 'Zabarte Road', 'status': null, 'distance': '4 km'},
          {'title': 'Microtel', 'subtitle': 'Cabanatuan City', 'status': null, 'distance': '5 km'},
        ],
      },
      {
        'icon': 'gym',
        'label': 'Gym',
        'places': [
          {'title': 'Anytime Fitness', 'subtitle': 'Gen. Tinio St', 'status': 'Open', 'distance': '4 km'},
          {'title': 'Golds Gym', 'subtitle': 'Maharlika Highway', 'status': 'Open', 'distance': '5 km'},
        ],
      },
      {
        'icon': 'cinema',
        'label': 'Cinema',
        'places': [
          {'title': 'SM Cinema', 'subtitle': 'SM Cabanatuan', 'status': null, 'distance': '4 km'},
          {'title': 'NE Mall Cinema', 'subtitle': 'Gen. Tinio St', 'status': null, 'distance': '4 km'},
        ],
      },
    ];

    return apiPayload.map(CategoryModel.fromJson).toList();
  }
}
