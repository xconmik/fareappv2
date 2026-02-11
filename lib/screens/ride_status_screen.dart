import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/ride_matching_service.dart';
import '../theme/responsive.dart';

class RideStatusScreen extends StatelessWidget {
  const RideStatusScreen({Key? key, required this.requestId}) : super(key: key);

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final service = RideMatchingService();

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Finding driver', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.watchRideRequest(requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(
              child: Text('Request not found', style: TextStyle(color: Colors.white70)),
            );
          }

          final status = data['status'] as String? ?? 'searching';
          final driverId = data['driverId'] as String?;

          return Padding(
            padding: EdgeInsets.all(r.space(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == 'assigned' ? 'Driver found' : 'Searching for a driver...',
                  style: TextStyle(color: Colors.white, fontSize: r.font(18), fontWeight: FontWeight.w700),
                ),
                SizedBox(height: r.space(12)),
                if (status == 'assigned' && driverId != null)
                  Text(
                    'Driver ID: $driverId',
                    style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
                  ),
                if (status == 'cancelled')
                  const Text('Request cancelled', style: TextStyle(color: Colors.white70)),
                const Spacer(),
                if (status == 'searching')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: EdgeInsets.symmetric(vertical: r.space(12)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(12))),
                      ),
                      onPressed: () async {
                        await service.cancelRideRequest(requestId);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Cancel request'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
