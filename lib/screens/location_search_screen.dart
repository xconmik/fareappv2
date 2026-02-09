import 'dart:ui';

import 'package:flutter/material.dart';

import '../mock/mock_data.dart';

class LocationSearchScreen extends StatelessWidget {
  const LocationSearchScreen({Key? key}) : super(key: key);

  static const _categories = <_CategoryItem>[
    _CategoryItem(icon: Icons.fastfood, label: 'Food'),
    _CategoryItem(icon: Icons.school, label: 'Univ'),
    _CategoryItem(icon: Icons.store_mall_directory, label: 'Mall'),
    _CategoryItem(icon: Icons.local_cafe, label: 'Cafe'),
    _CategoryItem(icon: Icons.local_grocery_store, label: 'Mart'),
  ];

  static const _recents = <_RecentItem>[
    _RecentItem(
      title: 'Crab & Bites',
      subtitle: 'Kapt. Pepe',
      status: 'Open',
      distanceKm: '2 km',
    ),
    _RecentItem(
      title: 'Jollibee Circum',
      subtitle: 'Circumferential Road',
      status: 'Closed',
      distanceKm: '5 km',
    ),
    _RecentItem(
      title: "McDonald's Sancianco",
      subtitle: 'Maharlika Highway',
      status: null,
      distanceKm: '8 km',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const SafeArea(
        child: LocationSearchSheet(),
      ),
    );
  }
}

class LocationSearchSheet extends StatelessWidget {
  const LocationSearchSheet({Key? key, this.controller}) : super(key: key);

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Search destination',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFC9A24D),
                  Color(0xFFF2D58A),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                '51 drivers available nearby',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 82,
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) => _CategoryChip(item: LocationSearchScreen._categories[index]),
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemCount: LocationSearchScreen._categories.length,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                ...LocationSearchScreen._recents.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.white70),
                    title: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    subtitle: Row(
                      children: [
                        Text(item.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        if (item.status != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            item.status!,
                            style: TextStyle(
                              color: item.status == 'Open' ? const Color(0xFFD4AF37) : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Text(item.distanceKm, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    onTap: () {
                      MockData.destination = item.title;
                      MockData.routeSummary = '${MockData.pickup} -> ${item.title}';
                      Navigator.pushNamed(context, '/location_map_selection');
                    },
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/location_map_selection'),
                  child: const Text('Choose on map', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final IconData icon;
  final String label;

  const _CategoryItem({required this.icon, required this.label});
}

class _CategoryChip extends StatelessWidget {
  final _CategoryItem item;

  const _CategoryChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: Colors.white70, size: 18),
          const SizedBox(height: 5),
          Text(item.label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RecentItem {
  final String title;
  final String subtitle;
  final String? status;
  final String distanceKm;

  const _RecentItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.distanceKm,
  });
}
