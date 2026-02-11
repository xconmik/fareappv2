import 'dart:async';
import 'package:flutter/services.dart';

class AppConfig {
  static const platform = MethodChannel('com.fare.app/config');
  
  // Unrestricted API key - paste your key here
  static const String _devApiKey = 'AIzaSyD7eRiM0iLc8DJt3DqdjMhiI8A6BmzBQyY';
  
  static Future<String> getGoogleMapsApiKey() async {
    try {
      final String apiKey = await platform.invokeMethod('getGoogleMapsApiKey');
      return apiKey;
    } on PlatformException catch (e) {
      print("Failed to get API key from native platform: '${e.message}'.");
      return _devApiKey;
    }
  }
}
