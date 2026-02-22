import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideMatchingService {
  RideMatchingService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<User> _ensureUser() async {
    final current = _auth.currentUser;
    if (current != null) {
      return current;
    }
    final credential = await _auth.signInAnonymously();
    return credential.user!;
  }

  Future<String> createRideRequest({
    required String pickupName,
    required String destinationName,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? distanceKm,
    String? destinationStatus,
    double? destinationRating,
  }) async {
    final user = await _ensureUser();
    // Calculate fare: ₱50 base + ₱20 per km
    final fare = 50.0 + ((distanceKm ?? 0) * 20.0);
    final doc = await _firestore.collection('ride_requests').add({
      'riderId': user.uid,
      'status': 'searching',
      'pickup': {
        'name': pickupName,
        'lat': pickupLat,
        'lng': pickupLng,
      },
      'destination': {
        'name': destinationName,
        'lat': destinationLat,
        'lng': destinationLng,
        'status': destinationStatus,
        'rating': destinationRating,
      },
      'distanceKm': distanceKm,
      'fare': fare,
      'passengers': 2,
      'routeSummary': '$pickupName → $destinationName',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRideRequest(String requestId) {
    return _firestore.collection('ride_requests').doc(requestId).snapshots();
  }

  Future<void> cancelRideRequest(String requestId) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePickupLocation({
    required String requestId,
    required String name,
    required double lat,
    required double lng,
  }) async {
    final docRef = _firestore.collection('ride_requests').doc(requestId);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final destination = data['destination'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final destinationName = destination['name'] as String? ??
        destination['title'] as String? ??
        'Destination';

    await docRef.update({
      'pickup.name': name,
      'pickup.lat': lat,
      'pickup.lng': lng,
      'routeSummary': '$name → $destinationName',
    });
  }

  Future<void> updateDestinationLocation({
    required String requestId,
    required String name,
    required double lat,
    required double lng,
  }) async {
    final docRef = _firestore.collection('ride_requests').doc(requestId);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final pickup = data['pickup'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final pickupName = pickup['name'] as String? ??
        pickup['title'] as String? ??
        'Pickup';

    await docRef.update({
      'destination.name': name,
      'destination.lat': lat,
      'destination.lng': lng,
      'routeSummary': '$pickupName → $name',
    });
  }

  Future<void> updatePassengers({
    required String requestId,
    required int passengers,
  }) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'passengers': passengers,
    });
  }

  Future<void> updateFare({
    required String requestId,
    required double fare,
  }) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'fare': fare,
    });
  }

  Future<void> acceptRideRequest(String requestId) async {
    await _firestore.collection('ride_requests').doc(requestId).update({
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }
}
