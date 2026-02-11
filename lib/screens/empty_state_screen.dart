import 'package:flutter/material.dart';
import '../theme/responsive.dart';

class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, color: const Color(0xFFD4AF37), size: r.icon(64)),
            SizedBox(height: r.space(24)),
            Text(
              "You're on the way to the future. Keep seated.",
              style: TextStyle(color: Colors.white, fontSize: r.font(18)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
