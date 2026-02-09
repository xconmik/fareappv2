import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/location_selection_screen.dart';
import 'screens/ride_history_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/profile_screen_v2.dart';
import 'screens/report_issue_screen.dart';
import 'screens/support_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/empty_state_screen.dart';
import 'screens/process_payment_screen.dart';
import 'screens/location_search_screen.dart';
import 'screens/location_map_selection_screen.dart';
import 'screens/location_ride_status_screen.dart';
import 'screens/location_confirm_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/home_main_screen.dart';
import 'screens/fare_mode_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/ride_booking_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: const AuthGate(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/sign_in': (context) => const SignInScreen(),
        '/sign_up': (context) => const SignUpScreen(),
        '/otp': (context) => const OtpScreen(),
        '/home_main': (context) => const HomeMainScreen(),
        '/fare_mode': (context) => const FareModeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/profile': (context) => ProfileScreen(),
        '/location': (context) => const LocationSelectionScreen(),
        '/ride_history': (context) => const RideHistoryScreen(),
        '/appearance': (context) => const AppearanceScreen(),
        '/profile_v2': (context) => const ProfileScreenV2(),
        '/report_issue': (context) => const ReportIssueScreen(),
        '/support': (context) => const SupportScreen(),
        '/booking_details': (context) => const BookingDetailsScreen(),
        '/rating': (context) => const RatingScreen(),
        '/empty': (context) => const EmptyStateScreen(),
        '/ride_booking': (context) => const RideBookingScreen(),
        '/process_payment': (context) => const ProcessPaymentScreen(),
        '/location_search': (context) => const LocationSearchScreen(),
        '/location_map_selection': (context) => const LocationMapSelectionScreen(),
        '/location_ride_status': (context) => const LocationRideStatusScreen(),
        '/location_confirm': (context) => const LocationConfirmScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1C1C1E),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != null) {
          return const HomeMainScreen();
        }

        return const SignInScreen();
      },
    );
  }
}


