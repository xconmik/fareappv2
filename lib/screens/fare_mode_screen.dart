import 'package:flutter/material.dart';
import '../theme/responsive.dart';

class FareModeScreen extends StatelessWidget {
  const FareModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.only(left: r.space(24), right: r.space(24), top: r.space(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fare Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: r.font(20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: r.space(16)),
            Text(
              'Set fare method to default.',
              style: TextStyle(color: Colors.grey, fontSize: r.font(12)),
            ),
            SizedBox(height: r.space(12)),
            Row(
              children: [
                Text('On', style: TextStyle(color: Colors.white, fontSize: r.font(14))),
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
