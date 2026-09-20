import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(title: const Text('User Profile & Access Level')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppConstants.primaryBlue,
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text('Dr. Rajesh Sharma', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('admin@watermonitor.edu', style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: AppConstants.accentCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text('Active Role: ${role.name.toUpperCase()}', style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 32),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.security, color: AppConstants.accentCyan),
                    title: const Text('Role-Based Access Control (RBAC)', style: TextStyle(color: Colors.white)),
                    subtitle: Text('Current permissions: ${role == UserRole.admin ? "Full add/edit tanks, configure thresholds & record cleanings" : "View dashboards & records"}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
