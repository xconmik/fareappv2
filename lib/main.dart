import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'screens/home_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/empty_state_screen.dart';
import 'screens/home_main_screen.dart';
import 'screens/fare_mode_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/ride_booked_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ride_history_screen.dart';
import 'screens/support_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final initFuture = _initFirebase();
  runApp(FirebaseGate(initFuture: initFuture));
}

Future<FirebaseApp> _initFirebase() async {
  if (kIsWeb) {
    return Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDShkEtJXdRWRmAAUKu7QVEhnhnmq0sGfk',
        authDomain: 'fareappv2.firebaseapp.com',
        projectId: 'fareappv2',
        storageBucket: 'fareappv2.firebasestorage.app',
        messagingSenderId: '622263264816',
        appId: '1:622263264816:web:2d65dc6c2cce5246a1eff5',
        measurementId: 'G-49X8HVFY5R',
      ),
    );
  }
  return Firebase.initializeApp();
}

class FirebaseGate extends StatelessWidget {
  const FirebaseGate({super.key, required this.initFuture});

  final Future<FirebaseApp> initFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            theme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const Scaffold(
              backgroundColor: Color(0xFF1C1C1E),
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            theme: AppTheme.dark(),
            themeMode: ThemeMode.dark,
            home: Scaffold(
              backgroundColor: const Color(0xFF1C1C1E),
              body: Center(
                child: Text(
                  'Firebase init failed. Check your web config.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          );
        }

        return const MyApp();
      },
    );
  }
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
        '/auth': (context) => const AuthScreen(),
        '/home_main': (context) => const HomeMainScreen(),
        '/fare_mode': (context) => const FareModeScreen(),
        '/home': (context) => HomeScreen(),
        '/appearance': (context) => const AppearanceScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/ride_history': (context) => const RideHistoryScreen(),
        '/support': (context) => const SupportScreen(),
        '/empty': (context) => const EmptyStateScreen(),
        '/ride_booked': (context) {
          final requestId = ModalRoute.of(context)?.settings.arguments as String?;
          if (requestId == null) {
            return const HomeMainScreen();
          }
          return RideBookedScreen(requestId: requestId);
        },
      },
    );
  }
}


