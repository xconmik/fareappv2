import 'package:flutter/material.dart';

class ProfileScreenV2 extends StatelessWidget {
  const ProfileScreenV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 48,
              backgroundImage: AssetImage('assets/avatar_placeholder.png'),
            ),
            const SizedBox(height: 16),
            const Text('ENZO ENZO CRUZ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Ride history', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushNamed(context, '/ride_history'),
            ),
            ListTile(
              title: const Text('Report', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushNamed(context, '/report_issue'),
            ),
            ListTile(
              title: const Text('Appearance', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushNamed(context, '/appearance'),
            ),
            ListTile(
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushNamed(context, '/settings'),
            ),
            ListTile(
              title: const Text('Fare mode', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pushNamed(context, '/fare_mode'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
