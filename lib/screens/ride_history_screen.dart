import 'package:flutter/material.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ride History', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            // Example ride history item
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jan 1, 2026', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Banska Bystrica -> Zvolen', style: TextStyle(color: Colors.grey)),
              trailing: const Text('PHP 120.00', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pushNamed(context, '/booking_details'),
            ),
            // ... more items can be added here
          ],
        ),
      ),
    );
  }
}
