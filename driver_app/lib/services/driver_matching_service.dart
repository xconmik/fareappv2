import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DriverMatchingService {
  DriverMatchingService({FirebaseAuth? auth, FirebaseFirestore? firestore})
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenRequests() {
    return _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'searching')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<bool> acceptRequest(String requestId) async {
    final driver = await _ensureUser();
    final requestRef = _firestore.collection('ride_requests').doc(requestId);

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      final data = snap.data();
      if (data == null || data['status'] != 'searching') {
        return false;
      }
      tx.update(requestRef, {
        'status': 'assigned',
        'driverId': driver.uid,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  Future<void> updateDriverLocation(Position position) async {
    final driver = await _ensureUser();
    await _firestore.collection('drivers').doc(driver.uid).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'available',
    }, SetOptions(merge: true));
  }
}
