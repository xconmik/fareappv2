import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/empty_state_screen.dart';
import 'screens/location_map_selection_screen.dart';
import 'screens/location_search_screen.dart';
import 'screens/home_main_screen.dart';
import 'screens/fare_mode_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FareAppRemake',
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
      routes: {
        '/home_main': (context) => const HomeMainScreen(),
        '/fare_mode': (context) => const FareModeScreen(),
        '/home': (context) => HomeScreen(),
        '/appearance': (context) => const AppearanceScreen(),
        '/booking_details': (context) => const BookingDetailsScreen(),
        '/empty': (context) => const EmptyStateScreen(),
        '/location_search': (context) => const LocationSearchScreen(),
        '/location_map_selection': (context) => const LocationMapSelectionScreen(),
      },
    );
  }
}


