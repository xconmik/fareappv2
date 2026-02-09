import 'package:flutter/material.dart';

class FareModeScreen extends StatelessWidget {
  const FareModeScreen({Key? key}) : super(key: key);

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
            const Text('Fare Mode', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Set fare method to default.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('On', style: TextStyle(color: Colors.white)),
                const Spacer(),
                Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
