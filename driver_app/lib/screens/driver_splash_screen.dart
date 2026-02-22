import 'package:flutter/material.dart';

import '../widgets/fare_logo.dart';

class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({Key? key}) : super(key: key);

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final scale = (screenWidth / 375).clamp(0.85, 1.25);
    final logoHeight = 120.0 * scale;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fare Logo
            SizedBox(
              height: logoHeight,
              child: Center(
                child: FareLogo(height: logoHeight),
              ),
            ),
            SizedBox(height: 24.0 * scale),
            Text(
              'Driver Mode',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.0 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
