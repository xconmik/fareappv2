import 'package:flutter/material.dart';
import '../theme/responsive.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(child: Text('Home Screen Mockup', style: TextStyle(fontSize: r.font(14)))),
    );
  }
}
