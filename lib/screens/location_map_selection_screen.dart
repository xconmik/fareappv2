import 'package:flutter/material.dart';
import '../theme/responsive.dart';

class LocationMapSelectionScreen extends StatelessWidget {
  const LocationMapSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Choose on map', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Text(
          'Map selection screen placeholder',
          style: TextStyle(color: Colors.white70, fontSize: r.font(14)),
        ),
      ),
    );
  }
}
