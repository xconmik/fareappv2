import 'package:flutter/material.dart';

import '../theme/responsive.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Support', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.only(left: r.space(20), right: r.space(20), top: r.space(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? We\'ve got your back.', style: TextStyle(color: Colors.white70, fontSize: r.font(12))),
            SizedBox(height: r.space(16)),
            _SupportCard(
              title: 'Report Issue',
              subtitle: 'Tell us what happened - your driver won\'t see your message.',
              buttonText: 'Start issue Report',
              r: r,
            ),
            SizedBox(height: r.space(12)),
            _SupportCard(
              title: 'Report Lost Item',
              subtitle: 'Submit a request for a lost item and we\'ll get in touch.',
              buttonText: 'Start lost item Report',
              r: r,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.r,
  });

  final String title;
  final String subtitle;
  final String buttonText;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: r.space(12), right: r.space(12), top: r.space(12)),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(r.radius(12)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600)),
          SizedBox(height: r.space(6)),
          Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
          SizedBox(height: r.space(12)),
          SizedBox(
            width: double.infinity,
            height: r.space(34),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(10))),
              ),
              onPressed: () {
                return;
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
