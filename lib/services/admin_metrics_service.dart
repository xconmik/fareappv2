import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMetrics {
  final int totalUsers;
  final int totalDrivers;
  final int onlineDrivers;
  final int activeRides;
  final int ridesToday;
  final int cancelledToday;
  final int completedToday;
  final int? downloads;
  final int? activeUsers;

  const AdminMetrics({
    required this.totalUsers,
    required this.totalDrivers,
    required this.onlineDrivers,
    required this.activeRides,
    required this.ridesToday,
    required this.cancelledToday,
    required this.completedToday,
    required this.downloads,
    required this.activeUsers,
  });
}

class AdminMetricsService {
  AdminMetricsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AdminMetrics> streamMetrics() {
    return _metricsStream();
  }

  Stream<AdminMetrics> _metricsStream() async* {
    yield await fetchMetrics();
    yield* Stream<AdminMetrics>.periodic(const Duration(seconds: 30)).asyncMap(
      (_) => fetchMetrics(),
    );
  }

  Future<AdminMetrics> fetchMetrics() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startTimestamp = Timestamp.fromDate(startOfDay);
    final onlineThreshold = Timestamp.fromDate(now.subtract(const Duration(minutes: 10)));

    final usersCount = await _firestore.collection('users').count().get();
    final driversCount = await _firestore.collection('drivers').count().get();
    final onlineDriversCount = await _firestore
        .collection('drivers')
        .where('status', isEqualTo: 'available')
        .where('updatedAt', isGreaterThanOrEqualTo: onlineThreshold)
        .count()
        .get();
    final activeRidesCount = await _firestore
        .collection('ride_requests')
        .where('status', whereIn: ['searching', 'assigned'])
        .count()
        .get();
    final ridesTodayCount = await _firestore
        .collection('ride_requests')
        .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
        .count()
        .get();
    final cancelledTodayCount = await _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'cancelled')
        .where('cancelledAt', isGreaterThanOrEqualTo: startTimestamp)
        .count()
        .get();
    final completedTodayCount = await _firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: startTimestamp)
        .count()
        .get();

    final metricsDoc = await _firestore.collection('admin_metrics').doc('global').get();
    final metricsData = metricsDoc.data();
    final downloads = _readInt(metricsData, 'downloads');
    final activeUsers = _readInt(metricsData, 'activeUsers');

    return AdminMetrics(
      totalUsers: usersCount.count ?? 0,
      totalDrivers: driversCount.count ?? 0,
      onlineDrivers: onlineDriversCount.count ?? 0,
      activeRides: activeRidesCount.count ?? 0,
      ridesToday: ridesTodayCount.count ?? 0,
      cancelledToday: cancelledTodayCount.count ?? 0,
      completedToday: completedTodayCount.count ?? 0,
      downloads: downloads,
      activeUsers: activeUsers,
    );
  }

  int? _readInt(Map<String, dynamic>? data, String key) {
    if (data == null) {
      return null;
    }
    final value = data[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
