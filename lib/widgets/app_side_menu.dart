import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/motion_presets.dart';

Future<void> showAppSideMenu(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  final displayName = (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
      ? user.displayName!.trim()
      : ((user?.email != null && user!.email!.trim().isNotEmpty) ? user.email!.trim() : 'Guest User');
  final profileInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G';
  final profilePhotoUrl = user?.photoURL?.trim();
  final hasProfilePhoto = profilePhotoUrl != null && profilePhotoUrl.isNotEmpty;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Side menu',
    barrierColor: Colors.black54,
    transitionDuration: kAppMotion.overlaySlide,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.78,
          child: Material(
            color: const Color(0xFF1A1A1A),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFF2A2A2A),
                            backgroundImage: hasProfilePhoto ? NetworkImage(profilePhotoUrl) : null,
                            child: hasProfilePhoto
                                ? null
                                : Text(
                                    profileInitial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _MenuItem(
                      icon: Icons.history,
                      label: 'Ride history',
                      onTap: () => _navigate(context, '/ride_history'),
                    ),
                    _MenuItem(
                      icon: Icons.local_taxi,
                      label: 'Fare Mode',
                      onTap: () => _navigate(context, '/fare_mode'),
                    ),
                    _MenuItem(
                      icon: Icons.support_agent,
                      label: 'Support',
                      onTap: () => _navigate(context, '/support'),
                    ),
                    _MenuItem(
                      icon: Icons.palette,
                      label: 'Appearance',
                      onTap: () => _navigate(context, '/appearance'),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context, rootNavigator: true).pop();
                          Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/auth', (_) => false);
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(curved);
      return SlideTransition(position: slide, child: child);
    },
  );
}

void _navigate(BuildContext context, String route) {
  Navigator.of(context, rootNavigator: true).pop();
  Navigator.of(context, rootNavigator: true).pushNamed(route);
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}
