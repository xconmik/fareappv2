import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/admin_metrics_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  AdminDashboardScreen({Key? key}) : super(key: key);

  final AdminMetricsService _metricsService = AdminMetricsService();

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            return Row(
              children: [
                if (isWide) _Sidebar(r: r),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: r.space(20), vertical: r.space(18)),
                    child: _DashboardContent(r: r, isWide: isWide, metricsService: _metricsService),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.r, required this.isWide, required this.metricsService});

  final Responsive r;
  final bool isWide;
  final AdminMetricsService metricsService;

  @override
  Widget build(BuildContext context) {
    final ridesStream = FirebaseFirestore.instance
        .collection('ride_requests')
        .orderBy('createdAt', descending: true)
        .limit(8)
        .snapshots();

    return StreamBuilder<AdminMetrics>(
      stream: metricsService.streamMetrics(),
      builder: (context, snapshot) {
        final metrics = snapshot.data;
        final stats = _buildStats(metrics);
        final alerts = _buildAlerts(metrics, snapshot.error);

        return LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(r: r, isWide: isWide),
                SizedBox(height: r.space(16)),
                _StatsGrid(r: r, items: stats, contentWidth: contentWidth),
                SizedBox(height: r.space(18)),
                Wrap(
                  spacing: r.space(16),
                  runSpacing: r.space(16),
                  children: [
                    SizedBox(
                      width: isWide ? contentWidth * 0.64 : double.infinity,
                      child: _TripsCard(r: r, ridesStream: ridesStream),
                    ),
                    SizedBox(
                      width: isWide ? contentWidth * 0.32 : double.infinity,
                      child: _AlertsCard(r: r, alerts: alerts),
                    ),
                  ],
                ),
                SizedBox(height: r.space(18)),
                _OpsCard(r: r),
              ],
            );
          },
        );
      },
    );
  }

  List<_StatData> _buildStats(AdminMetrics? metrics) {
    final downloads = metrics?.downloads;
    final activeUsers = metrics?.activeUsers;
    return [
      _StatData(label: 'Total users', value: _formatCount(metrics?.totalUsers), delta: 'All time'),
      _StatData(label: 'Total drivers', value: _formatCount(metrics?.totalDrivers), delta: 'All time'),
      _StatData(label: 'Drivers online', value: _formatCount(metrics?.onlineDrivers), delta: 'Live'),
      _StatData(label: 'Active rides', value: _formatCount(metrics?.activeRides), delta: 'Live'),
      _StatData(label: 'Trips today', value: _formatCount(metrics?.ridesToday), delta: 'Today'),
      _StatData(label: 'Cancelled today', value: _formatCount(metrics?.cancelledToday), delta: 'Today'),
      _StatData(label: 'Completed today', value: _formatCount(metrics?.completedToday), delta: 'Today'),
      _StatData(label: 'Downloads', value: _formatCount(downloads), delta: downloads == null ? 'Admin metrics' : 'All time'),
      _StatData(label: 'Active users', value: _formatCount(activeUsers), delta: activeUsers == null ? 'Admin metrics' : 'Live'),
    ];
  }

  List<_AlertData> _buildAlerts(AdminMetrics? metrics, Object? error) {
    final alerts = <_AlertData>[];

    if (error != null) {
      alerts.add(const _AlertData('Metrics unavailable', 'Check Firestore rules or indexes.'));
    }

    if (metrics == null) {
      alerts.add(const _AlertData('Loading metrics', 'Fetching live data from Firestore.'));
      return alerts;
    }

    if (metrics.onlineDrivers == 0 && metrics.activeRides > 0) {
      alerts.add(const _AlertData('No drivers online', 'Active rides are waiting for drivers.'));
    }

    if (metrics.cancelledToday >= 5) {
      alerts.add(_AlertData('High cancellations', '${metrics.cancelledToday} trips cancelled today.'));
    }

    if (metrics.ridesToday == 0) {
      alerts.add(const _AlertData('No trips today', 'No ride requests since midnight.'));
    }

    if (metrics.downloads == null || metrics.activeUsers == null) {
      alerts.add(const _AlertData('Set admin metrics', 'Add downloads/activeUsers in admin_metrics/global.'));
    }

    if (alerts.isEmpty) {
      alerts.add(const _AlertData('Operations normal', 'No urgent issues detected.'));
    }

    return alerts;
  }

  String _formatCount(int? value) {
    if (value == null) {
      return '--';
    }
    return value.toString();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.r, required this.isWide});

  final Responsive r;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.space(18), vertical: r.space(16)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF1F1F22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.radius(18)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin dashboard',
                  style: TextStyle(
                    fontSize: r.font(18),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: r.space(6)),
                Text(
                  'Live overview of rides, drivers, and operational alerts.',
                  style: TextStyle(fontSize: r.font(12.5), color: Colors.white70),
                ),
              ],
            ),
          ),
          if (isWide) ...[
            _HeaderButton(icon: Icons.search, label: 'Search'),
            SizedBox(width: r.space(10)),
            _HeaderButton(icon: Icons.notifications_none, label: 'Alerts'),
            SizedBox(width: r.space(10)),
            _HeaderButton(icon: Icons.settings, label: 'Settings'),
          ] else
            _HeaderButton(icon: Icons.notifications_none, label: 'Alerts'),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.r, required this.items, required this.contentWidth});

  final Responsive r;
  final List<_StatData> items;
  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    final columns = contentWidth >= 1200 ? 4 : contentWidth >= 900 ? 3 : contentWidth >= 620 ? 2 : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: r.space(12),
        mainAxisSpacing: r.space(12),
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: EdgeInsets.symmetric(horizontal: r.space(16), vertical: r.space(14)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(r.radius(16)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: TextStyle(color: Colors.white70, fontSize: r.font(11.5))),
              SizedBox(height: r.space(8)),
              Row(
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.font(18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.space(8), vertical: r.space(4)),
                    decoration: BoxDecoration(
                      color: const Color(0x1AC9A24D),
                      borderRadius: BorderRadius.circular(r.radius(12)),
                    ),
                    child: Text(
                      item.delta,
                      style: TextStyle(color: AppColors.goldEnd, fontSize: r.font(10.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripsCard extends StatelessWidget {
  const _TripsCard({required this.r, required this.ridesStream});

  final Responsive r;
  final Stream<QuerySnapshot<Map<String, dynamic>>> ridesStream;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.space(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.radius(18)),
        border: Border.all(color: AppColors.border),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ridesStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final trips = docs.map(_mapTrip).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Recent trips', style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Auto refresh', style: TextStyle(color: Colors.white54, fontSize: r.font(10.5))),
                ],
              ),
              SizedBox(height: r.space(14)),
              _TripRowHeader(r: r),
              SizedBox(height: r.space(8)),
              if (snapshot.connectionState == ConnectionState.waiting)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.space(12)),
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (trips.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.space(12)),
                  child: Text('No trips yet', style: TextStyle(color: Colors.white70, fontSize: r.font(11.5))),
                )
              else
                for (final trip in trips) ...[
                  _TripRow(r: r, trip: trip),
                  SizedBox(height: r.space(6)),
                ],
            ],
          );
        },
      ),
    );
  }

  _TripData _mapTrip(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final timestamp = data['createdAt'] as Timestamp?;
    final riderName = data['riderName'] as String?;
    final riderId = data['riderId'] as String?;
    final driverName = data['driverName'] as String?;
    final driverId = data['driverId'] as String?;
    final status = data['status'] as String? ?? 'unknown';
    final fare = (data['fare'] as num?)?.toDouble();
    final route = data['routeSummary'] as String?;

    return _TripData(
      _formatTime(timestamp?.toDate()),
      _formatPerson(riderName, riderId, fallback: 'Rider'),
      _formatPerson(driverName, driverId, fallback: 'Unassigned'),
      status,
      fare == null ? '--' : '\$${fare.toStringAsFixed(2)}',
      routeSummary: route,
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '--:--';
    }
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatPerson(String? name, String? id, {required String fallback}) {
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    if (id != null && id.length >= 6) {
      return '${id.substring(0, 4)}...${id.substring(id.length - 2)}';
    }
    return fallback;
  }
}

class _TripRowHeader extends StatelessWidget {
  const _TripRowHeader({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderCell(r: r, label: 'Time', flex: 2),
        _HeaderCell(r: r, label: 'Rider', flex: 3),
        _HeaderCell(r: r, label: 'Driver', flex: 3),
        _HeaderCell(r: r, label: 'Status', flex: 3),
        _HeaderCell(r: r, label: 'Fare', flex: 2, alignEnd: true),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.r, required this.label, required this.flex, this.alignEnd = false});

  final Responsive r;
  final String label;
  final int flex;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(color: Colors.white54, fontSize: r.font(10.5), fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.r, required this.trip});

  final Responsive r;
  final _TripData trip;

  Color _statusColor(String status) {
    switch (status) {
      case 'searching':
        return const Color(0xFF93C5FD);
      case 'assigned':
        return const Color(0xFFFBBF24);
      case 'Completed':
      case 'completed':
        return const Color(0xFF6EE7B7);
      case 'In progress':
        return const Color(0xFFF59E0B);
      case 'Cancelled':
      case 'cancelled':
        return const Color(0xFFF87171);
      default:
        return const Color(0xFF93C5FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(trip.status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.space(10), vertical: r.space(8)),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(r.radius(12)),
      ),
      child: Row(
        children: [
          _RowCell(r: r, text: trip.time, flex: 2),
          _RowCell(r: r, text: trip.rider, flex: 3),
          _RowCell(r: r, text: trip.driver, flex: 3),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: r.space(6),
                  height: r.space(6),
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                SizedBox(width: r.space(6)),
                Expanded(
                  child: Text(
                    trip.status,
                    style: TextStyle(color: statusColor, fontSize: r.font(11)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _RowCell(r: r, text: trip.fare, flex: 2, alignEnd: true),
        ],
      ),
    );
  }
}

class _RowCell extends StatelessWidget {
  const _RowCell({required this.r, required this.text, required this.flex, this.alignEnd = false});

  final Responsive r;
  final String text;
  final int flex;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(color: Colors.white70, fontSize: r.font(11.5)),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.r, required this.alerts});

  final Responsive r;
  final List<_AlertData> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.space(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.radius(18)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operations alerts', style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w600)),
          SizedBox(height: r.space(14)),
          if (alerts.isEmpty)
            Text('No alerts', style: TextStyle(color: Colors.white70, fontSize: r.font(11.5)))
          else
            for (final alert in alerts) ...[
              _AlertRow(r: r, alert: alert),
              SizedBox(height: r.space(10)),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.r, required this.alert});

  final Responsive r;
  final _AlertData alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(10)),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(r.radius(12)),
      ),
      child: Row(
        children: [
          Container(
            width: r.space(32),
            height: r.space(32),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.goldStart, AppColors.goldEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.bolt, color: Colors.black, size: 18),
          ),
          SizedBox(width: r.space(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(color: Colors.white, fontSize: r.font(11.5), fontWeight: FontWeight.w600)),
                SizedBox(height: r.space(4)),
                Text(alert.detail, style: TextStyle(color: Colors.white54, fontSize: r.font(10.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsCard extends StatelessWidget {
  const _OpsCard({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.space(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.radius(18)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operations quick actions', style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w600)),
          SizedBox(height: r.space(14)),
          Wrap(
            spacing: r.space(12),
            runSpacing: r.space(12),
            children: [
              _ActionChip(r: r, icon: Icons.campaign, label: 'Send promo'),
              _ActionChip(r: r, icon: Icons.security, label: 'Review incidents'),
              _ActionChip(r: r, icon: Icons.support_agent, label: 'Open support queue'),
              _ActionChip(r: r, icon: Icons.assessment, label: 'Export reports'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.r, required this.icon, required this.label});

  final Responsive r;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white70,
        side: const BorderSide(color: AppColors.border),
        padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(10)),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF18181A),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.space(18), vertical: r.space(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fare Admin', style: TextStyle(color: Colors.white, fontSize: r.font(16), fontWeight: FontWeight.w700)),
                SizedBox(height: r.space(6)),
                Text('Control center', style: TextStyle(color: Colors.white54, fontSize: r.font(11.5))),
              ],
            ),
          ),
          const Divider(height: 1),
          _SidebarItem(r: r, icon: Icons.dashboard, label: 'Overview', isActive: true),
          _SidebarItem(r: r, icon: Icons.route, label: 'Trips'),
          _SidebarItem(r: r, icon: Icons.directions_car_filled, label: 'Drivers'),
          _SidebarItem(r: r, icon: Icons.account_balance_wallet, label: 'Payments'),
          _SidebarItem(r: r, icon: Icons.support_agent, label: 'Support'),
          const Spacer(),
          Padding(
            padding: EdgeInsets.all(r.space(16)),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.exit_to_app, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.r, required this.icon, required this.label, this.isActive = false});

  final Responsive r;
  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isActive ? AppColors.goldEnd : Colors.white54, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.white70,
          fontSize: r.font(12.5),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: () {},
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final String delta;

  const _StatData({required this.label, required this.value, required this.delta});
}

class _TripData {
  final String time;
  final String rider;
  final String driver;
  final String status;
  final String fare;
  final String? routeSummary;

  const _TripData(this.time, this.rider, this.driver, this.status, this.fare, {this.routeSummary});
}

class _AlertData {
  final String title;
  final String detail;

  const _AlertData(this.title, this.detail);
}
