import 'package:flutter/material.dart';
import '../theme/responsive.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({Key? key}) : super(key: key);

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  String _mode = 'dark';

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
        padding: EdgeInsets.all(r.space(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(color: Colors.white, fontSize: r.font(20), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: r.space(16)),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(r.radius(10)),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'light',
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value ?? 'light'),
                    title: Text('Light Mode', style: TextStyle(color: Colors.white, fontSize: r.font(14))),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  RadioListTile<String>(
                    value: 'dark',
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value ?? 'dark'),
                    title: Text('Dark Mode', style: TextStyle(color: Colors.white, fontSize: r.font(14))),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
