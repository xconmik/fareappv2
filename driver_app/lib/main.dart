import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/driver_splash_screen.dart';
import 'screens/driver_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fare Driver',
      theme: ThemeData.dark(),
      home: const DriverSplashScreen(),
      routes: {
        '/home': (context) => const DriverHomeScreen(),
      },
    );
  }
}
