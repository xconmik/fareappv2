import 'package:flutter/material.dart';

class PlaceModel {
  final String title;
  final String subtitle;
  final String? status;
  final String distance;

  const PlaceModel({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.distance,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      title: json['title'] as String? ?? 'Unknown place',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String?,
      distance: json['distance'] as String? ?? '',
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
    'place': Icons.place,
  };

  static IconData iconFor(String key) {
    return _icons[key] ?? Icons.place;
  }
}
