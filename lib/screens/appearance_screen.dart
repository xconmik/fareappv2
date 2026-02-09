import 'package:flutter/material.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({Key? key}) : super(key: key);

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  String _mode = 'dark';

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
            const Text('Appearance', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'light',
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value ?? 'light'),
                    title: const Text('Light Mode', style: TextStyle(color: Colors.white)),
                    activeColor: const Color(0xFFD4AF37),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  RadioListTile<String>(
                    value: 'dark',
                    groupValue: _mode,
                    onChanged: (value) => setState(() => _mode = value ?? 'dark'),
                    title: const Text('Dark Mode', style: TextStyle(color: Colors.white)),
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
