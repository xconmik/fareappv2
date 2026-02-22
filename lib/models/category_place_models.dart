import 'package:flutter/material.dart';

class PlaceModel {
  final String title;
  final String subtitle;
  final String? status;
  final String distance;
  final double? latitude;
  final double? longitude;

  const PlaceModel({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.distance,
    this.latitude,
    this.longitude,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      title: json['title'] as String? ?? 'Unknown place',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String?,
      distance: json['distance'] as String? ?? '',
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }
}

class CategoryModel {
  final String label;
  final String iconKey;
  final List<PlaceModel> places;

  const CategoryModel({
    required this.label,
    required this.iconKey,
    required this.places,
  });

  IconData get icon => CategoryIconRegistry.iconFor(iconKey);

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final placesJson = json['places'] as List<dynamic>? ?? const [];
    return CategoryModel(
      label: json['label'] as String? ?? 'Unknown',
      iconKey: json['icon'] as String? ?? 'place',
      places: placesJson
          .map((place) => PlaceModel.fromJson(place as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategorySeed {
  final String label;
  final String iconKey;

  const CategorySeed({required this.label, required this.iconKey});
}

const List<CategorySeed> kDefaultCategorySeeds = [
  CategorySeed(label: 'Food', iconKey: 'food'),
  CategorySeed(label: 'School', iconKey: 'school'),
  CategorySeed(label: 'Mall', iconKey: 'mall'),
  CategorySeed(label: 'Cafe', iconKey: 'cafe'),
  CategorySeed(label: 'Mart', iconKey: 'mart'),
  CategorySeed(label: 'Hospital', iconKey: 'hospital'),
  CategorySeed(label: 'Park', iconKey: 'park'),
  CategorySeed(label: 'Office', iconKey: 'office'),
  CategorySeed(label: 'Airport', iconKey: 'airport'),
  CategorySeed(label: 'Hotel', iconKey: 'hotel'),
  CategorySeed(label: 'Gym', iconKey: 'gym'),
  CategorySeed(label: 'Cinema', iconKey: 'cinema'),
  CategorySeed(label: 'Grocery', iconKey: 'grocery'),
  CategorySeed(label: 'Pharmacy', iconKey: 'pharmacy'),
  CategorySeed(label: 'Bank', iconKey: 'bank'),
  CategorySeed(label: 'ATM', iconKey: 'atm'),
  CategorySeed(label: 'Gas', iconKey: 'gas'),
  CategorySeed(label: 'Church', iconKey: 'church'),
  CategorySeed(label: 'Library', iconKey: 'library'),
  CategorySeed(label: 'Terminal', iconKey: 'terminal'),
];

List<CategoryModel> buildDefaultCategories() {
  return kDefaultCategorySeeds
      .map(
        (seed) => CategoryModel(
          label: seed.label,
          iconKey: seed.iconKey,
          places: const [],
        ),
      )
      .toList(growable: false);
}

class CategoryIconRegistry {
  static const Map<String, IconData> _icons = {
    'food': Icons.fastfood,
    'school': Icons.school,
    'mall': Icons.store_mall_directory,
    'cafe': Icons.local_cafe,
    'mart': Icons.local_grocery_store,
    'hospital': Icons.local_hospital,
    'park': Icons.park,
    'office': Icons.business_center,
    'airport': Icons.flight,
    'hotel': Icons.hotel,
    'gym': Icons.fitness_center,
    'cinema': Icons.movie,
    'grocery': Icons.local_grocery_store,
    'pharmacy': Icons.local_pharmacy,
    'bank': Icons.account_balance,
    'atm': Icons.atm,
    'gas': Icons.local_gas_station,
    'church': Icons.church,
    'library': Icons.local_library,
    'terminal': Icons.directions_bus,
    'place': Icons.place,
  };

  static IconData iconFor(String key) {
    return _icons[key] ?? Icons.place;
  }
}
