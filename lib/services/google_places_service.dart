import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

class GooglePlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const double _cabanatuanLat = 15.4866;
  static const double _cabanatuanLng = 120.9677;
  static const int _cabanatuanRadius = 15000;
  static const String _cityName = 'cabanatuan';
  static const String _provinceName = 'nueva ecija';
  
  final String _apiKey;

  GooglePlacesService({required String apiKey}) : _apiKey = apiKey;

  /// Get autocomplete predictions from Google Places API
  Future<List<PlacePrediction>> getAutocompletePredictions({
    required String input,
    required double? latitude,
    required double? longitude,
    String? sessionToken,
    bool restrictToCabanatuan = false,
    bool strictCityFilter = false,
  }) async {
    try {
      const radius = 15000; // 15km radius
      
      final queryParams = {
        'input': input,
        'key': _apiKey,
        'components': 'country:ph', // Philippines
      };

      if (restrictToCabanatuan) {
        queryParams['location'] = '$_cabanatuanLat,$_cabanatuanLng';
        queryParams['radius'] = _cabanatuanRadius.toString();
      } else if (latitude != null && longitude != null) {
        queryParams['location'] = '$latitude,$longitude';
        queryParams['radius'] = radius.toString();
      }

      if (sessionToken != null) {
        queryParams['sessionToken'] = sessionToken;
      }

      final uri = Uri.parse('$_baseUrl/place/autocomplete/json')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Places API request timed out'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawPredictions = (json['predictions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
          [];

        final filteredPredictions = strictCityFilter
          ? rawPredictions.where((p) {
            final description = (p['description'] as String?) ?? '';
            final secondaryText = (p['structured_formatting'] as Map<String, dynamic>?)?['secondary_text'] as String? ?? '';
            return _isCabanatuanText(description) || _isCabanatuanText(secondaryText);
            }).toList()
          : rawPredictions;

        final predictions = filteredPredictions
          .map((p) => PlacePrediction.fromJson(p))
          .toList();
        return predictions;
      } else if (response.statusCode == 403) {
        throw Exception('Places API key invalid or quota exceeded');
      } else {
        throw Exception('Failed to fetch predictions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting predictions: $e');
      rethrow;
    }
  }

  /// Get place details (coordinates, description, etc.)
  Future<PlaceDetailsResult?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  }) async {
    try {
      final queryParams = {
        'place_id': placeId,
        'key': _apiKey,
        'fields': 'geometry,formatted_address,name,photos',
      };

      if (sessionToken != null) {
        queryParams['sessionToken'] = sessionToken;
      }

      final uri = Uri.parse('$_baseUrl/place/details/json')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Place details API request timed out'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        
        if (result != null) {
          return PlaceDetailsResult.fromJson(result);
        }
        return null;
      } else {
        throw Exception('Failed to fetch place details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
      rethrow;
    }
  }

  /// Geocode an address to get coordinates
  Future<GeocodeResult?> geocodeAddress({
    required String address,
  }) async {
    try {
      final queryParams = {
        'address': address,
        'key': _apiKey,
        'region': 'ph',
      };

      final uri = Uri.parse('$_baseUrl/geocode/json')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Geocoding request timed out'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (json['results'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        
        if (results.isNotEmpty) {
          return GeocodeResult.fromJson(results.first);
        }
        return null;
      } else {
        throw Exception('Geocoding failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error geocoding: $e');
      rethrow;
    }
  }

  /// Search for nearby places by type/keyword
  Future<List<NearbyPlaceResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    required String keyword,
    int radius = 5000,
    bool restrictToCabanatuan = false,
    bool strictCityFilter = false,
  }) async {
    try {
      debugPrint('[GooglePlaces] Searching nearby places:');
      debugPrint('  - Location: $latitude, $longitude');
      debugPrint('  - Keyword: $keyword');
      debugPrint('  - Radius: ${radius}m');
      
      final queryParams = {
        'location': restrictToCabanatuan
            ? '$_cabanatuanLat,$_cabanatuanLng'
            : '$latitude,$longitude',
        'radius': (restrictToCabanatuan ? _cabanatuanRadius : radius).toString(),
        'keyword': keyword,
        'key': _apiKey,
      };

      final uri = Uri.parse('$_baseUrl/place/nearbysearch/json')
          .replace(queryParameters: queryParams);
        debugPrint('  - API URL: $_baseUrl/place/nearbysearch/json');

      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('Nearby search request timed out'),
      );

      debugPrint('[GooglePlaces] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = json['status'] as String?;
        debugPrint('[GooglePlaces] API status: $status');
        
        if (status != 'OK') {
          debugPrint('[GooglePlaces] Warning: API status is not OK. Response: ${response.body}');
        }
        
        final results = (json['results'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map((r) => NearbyPlaceResult.fromJson(r))
                .toList() ??
            [];
        final filteredResults = strictCityFilter
            ? results.where((r) {
                if (_isCabanatuanText(r.address)) {
                  return true;
                }
                final distanceKm = _haversineKm(
                  _cabanatuanLat,
                  _cabanatuanLng,
                  r.latitude,
                  r.longitude,
                );
                return distanceKm <= (_cabanatuanRadius / 1000.0);
              }).toList()
            : results;
        debugPrint('[GooglePlaces] Found ${filteredResults.length} results');
        return filteredResults;
      } else {
        debugPrint('[GooglePlaces] Error response: ${response.body}');
        throw Exception('Nearby search failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[GooglePlaces] Error searching nearby places: $e');
      rethrow;
    }
  }

  bool _isCabanatuanText(String? text) {
    if (text == null || text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    return lower.contains(_cityName) || lower.contains(_provinceName);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const radiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}

/// Autocomplete prediction from Google Places API
class PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] as String? ?? '',
      mainText: (json['structured_formatting'] as Map<String, dynamic>?)?['main_text'] as String? ?? '',
      secondaryText: (json['structured_formatting'] as Map<String, dynamic>?)?['secondary_text'] as String? ?? '',
      fullText: json['description'] as String? ?? '',
    );
  }
}

/// Place details result
class PlaceDetailsResult {
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? name;

  const PlaceDetailsResult({
    this.latitude,
    this.longitude,
    this.address,
    this.name,
  });

  factory PlaceDetailsResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    return PlaceDetailsResult(
      latitude: location?['lat'] as double?,
      longitude: location?['lng'] as double?,
      address: json['formatted_address'] as String?,
      name: json['name'] as String?,
    );
  }
}

/// Geocode result
class GeocodeResult {
  final double latitude;
  final double longitude;
  final String address;

  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory GeocodeResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return GeocodeResult(
      latitude: location['lat'] as double,
      longitude: location['lng'] as double,
      address: json['formatted_address'] as String? ?? '',
    );
  }
}

/// Nearby place result from Nearby Search API
class NearbyPlaceResult {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final bool openNow;
  final double? rating;

  const NearbyPlaceResult({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.openNow = false,
    this.rating,
  });

  factory NearbyPlaceResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final openingHours = json['opening_hours'] as Map<String, dynamic>?;

    return NearbyPlaceResult(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Place',
      latitude: location['lat'] as double,
      longitude: location['lng'] as double,
      address: json['vicinity'] as String?,
      openNow: openingHours?['open_now'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}
