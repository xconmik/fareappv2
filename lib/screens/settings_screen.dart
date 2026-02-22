import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/responsive.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _displayName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final name = _displayName(user);
    final photoUrl = user?.photoURL?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF151517),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: r.space(18),
            right: r.space(18),
            top: r.space(10),
            bottom: r.space(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings/User Profile',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: r.font(10),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: r.space(14)),
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.white60, size: r.icon(16)),
              ),
              SizedBox(height: r.space(18)),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: r.space(52),
                      backgroundColor: const Color(0xFF2A2A2A),
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: hasPhoto
                          ? null
                          : Icon(Icons.person, color: Colors.white70, size: r.icon(42)),
                    ),
                    SizedBox(height: r.space(14)),
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.font(17),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.space(24)),
              _SettingsItem(
                label: 'Ride history',
                onTap: () => Navigator.pushNamed(context, '/ride_history'),
              ),
              _SettingsItem(
                label: 'Fare Mode',
                onTap: () => Navigator.pushNamed(context, '/fare_mode'),
              ),
              _SettingsItem(
                label: 'Support',
                onTap: () => Navigator.pushNamed(context, '/support'),
              ),
              _SettingsItem(
                label: 'Appearance',
                onTap: () => Navigator.pushNamed(context, '/appearance'),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: r.space(110),
                  height: r.space(36),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.radius(999)),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
                    },
                    child: Text(
                      'Sign Out',
                      style: TextStyle(fontSize: r.font(11), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.radius(10)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.space(10)),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: r.font(14),
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white38, size: r.icon(20)),
          ],
        ),
      ),
    );
  }
}
