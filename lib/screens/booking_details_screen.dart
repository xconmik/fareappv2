import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/responsive.dart';

class BookingDetailsScreen extends StatelessWidget {
  final String? requestId;
  
  const BookingDetailsScreen({Key? key, this.requestId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    
    if (requestId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          title: const Text('Booking', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            'No booking details available',
            style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Booking Details', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('ride_requests').doc(requestId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: const Color(0xFFE2C26D)),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return Center(
              child: Text(
                'Booking not found',
                style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
              ),
            );
          }

          final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
          final destination = data['destination'] as Map<String, dynamic>? ?? {};
          final routeSummary = data['routeSummary'] as String? ?? 'Unknown route';
          final fare = data['fare'] as num? ?? 0;
          final status = data['status'] as String? ?? 'pending';

          return Padding(
            padding: EdgeInsets.all(r.space(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: r.space(200),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(r.radius(12)),
                  ),
                  child: const Center(
                    child: Text('Map View', style: TextStyle(color: Colors.white54)),
                  ),
                ),
                SizedBox(height: r.space(16)),
                Text(
                  status == 'assigned' ? 'Your ride is booked!' : 'Booking pending...',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: r.font(18)),
                ),
                SizedBox(height: r.space(8)),
                Text(
                  routeSummary,
                  style: TextStyle(color: Colors.grey, fontSize: r.font(12)),
                ),
                SizedBox(height: r.space(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱ ${fare.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                        fontSize: r.font(18),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: status == 'assigned'
                        ? () => Navigator.pushNamed(context, '/process_payment')
                        : null,
                      child: const Text('Pay'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
