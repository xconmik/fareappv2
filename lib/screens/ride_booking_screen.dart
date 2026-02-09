import 'package:flutter/material.dart';

import '../mock/mock_data.dart';

class RideBookingScreen extends StatefulWidget {
  const RideBookingScreen({Key? key}) : super(key: key);

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  void _updatePassengers(int delta) {
    setState(() {
      final next = MockData.passengers + delta;
      if (next >= 1 && next <= 6) {
        MockData.passengers = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/profile_v2'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map placeholder
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
            ),
            child: const Center(
              child: Text('Map View', style: TextStyle(color: Colors.white54)),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF232323),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('8 min', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 8),
                        Text('3.4 km', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('Be ready at the pickup spot', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(MockData.pickup, style: const TextStyle(color: Colors.white)),
                            subtitle: const Text('Pickup', style: TextStyle(color: Colors.grey)),
                            leading: const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          ListTile(
                            title: Text(MockData.destination, style: const TextStyle(color: Colors.white)),
                            subtitle: const Text('Destination', style: TextStyle(color: Colors.grey)),
                            leading: const Icon(Icons.flag, color: Color(0xFFD4AF37)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Passengers', style: TextStyle(color: Colors.white)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white),
                              onPressed: () => _updatePassengers(-1),
                            ),
                            Text('${MockData.passengers}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () => _updatePassengers(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(MockData.fare, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 18)),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/location_search'),
                              child: const Text('Tap to Change', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 120,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/booking_details'),
                            child: const Text('Book', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
