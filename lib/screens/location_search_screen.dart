import 'dart:ui';

import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import 'category_with_places.dart';

class LocationSearchScreen extends StatelessWidget {
  const LocationSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CategoryWithPlacesScreen();
  }
}

class LocationSearchSheet extends StatelessWidget {
  const LocationSearchSheet({Key? key, this.controller}) : super(key: key);

  final ScrollController? controller;

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomInset),
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
                          autofocus: true,
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
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recents', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: controller,
                children: _recents
                    .map(
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
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
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
