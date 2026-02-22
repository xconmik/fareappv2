import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/driver_matching_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _service = DriverMatchingService();
  bool _tracking = false;

  Future<void> _startTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }
    setState(() {
      _tracking = true;
    });

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((position) {
      _service.updateDriverLocation(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Queue'),
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFF1C1C1E),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _tracking ? null : _startTracking,
              icon: Icon(_tracking ? Icons.check_circle : Icons.location_on),
              label: Text(_tracking ? 'Online' : 'Go Online'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _tracking ? Colors.green : const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                disabledBackgroundColor: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.watchOpenRequests(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE2C26D)),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No ride requests yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final pickup = (data['pickup'] as Map<String, dynamic>?)?['name'] as String? ?? 'Pickup';
                    final destination = (data['destination'] as Map<String, dynamic>?)?['name'] as String? ?? 'Destination';
                    final fare = (data['fare'] as num?)?.toStringAsFixed(2) ?? '0.00';

                    return Card(
                      color: const Color(0xFF2C2C2E),
                      child: ListTile(
                        title: Text(
                          pickup,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          destination,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱$fare',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final accepted = await _service.acceptRequest(docs[index].id);
                                if (!context.mounted) {
                                  return;
                                }
                                return;
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                              child: const Text('Accept', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
