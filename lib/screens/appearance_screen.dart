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
        title: const Text('Appearance', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.only(left: r.space(20), right: r.space(20), top: r.space(20)),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF232323),
            borderRadius: BorderRadius.circular(r.radius(12)),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppearanceOption(
                label: 'Light Mode',
                selected: _mode == 'light',
                onTap: () => setState(() => _mode = 'light'),
              ),
              const Divider(height: 1, color: Colors.white12),
              _AppearanceOption(
                label: 'Dark Mode',
                selected: _mode == 'dark',
                onTap: () => setState(() => _mode = 'dark'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(label, style: TextStyle(color: Colors.white, fontSize: r.font(12))),
      trailing: selected
          ? Icon(Icons.check, color: const Color(0xFFC9B469), size: r.icon(18))
          : null,
    );
  }
}
