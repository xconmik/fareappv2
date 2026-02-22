import 'package:flutter/material.dart';

import '../theme/responsive.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Ride History', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.only(left: r.space(20), right: r.space(20), top: r.space(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ride History', style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w600)),
            SizedBox(height: r.space(14)),
            _RideHistoryTile(
              date: 'Jun 30, 2025',
              route: 'Crislo de Ilive',
              price: '₱ 20.00',
              r: r,
            ),
            _RideHistoryTile(
              date: 'Jun 29, 2025',
              route: 'Wesleyan University Philippines',
              price: '₱ 20.00',
              r: r,
            ),
          ],
        ),
      ),
    );
  }
}

class _RideHistoryTile extends StatelessWidget {
  const _RideHistoryTile({
    required this.date,
    required this.route,
    required this.price,
    required this.r,
  });

  final String date;
  final String route;
  final String price;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.space(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
          SizedBox(height: r.space(6)),
          Row(
            children: [
              Expanded(
                child: Text(route, style: TextStyle(color: Colors.white70, fontSize: r.font(12))),
              ),
              Text(price, style: TextStyle(color: Colors.white70, fontSize: r.font(12))),
            ],
          ),
        ],
      ),
    );
  }
}
