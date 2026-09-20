import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/notification_bell_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('System Settings & Thresholds'),
        actions: const [
          NotificationBellButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRoleSelector(context, ref, role),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded, color: AppConstants.accentCyan),
            title: const Text('Push Notification Preferences', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Configure critical & cleaning alerts', style: TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            onTap: () => context.push('/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppConstants.accentCyan),
            title: const Text('User Profile & Roles', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Admin, Technician, Viewer permissions', style: TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            onTap: () => context.push('/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined, color: AppConstants.accentCyan),
            title: const Text('Generate Water Audit PDF Reports', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Export daily, weekly, and monthly reports', style: TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
            onTap: () => context.push('/reports'),
          ),
          const Divider(color: Colors.white24, height: 32),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () => context.go('/login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(BuildContext context, WidgetRef ref, UserRole activeRole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.darkCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CURRENT USER ROLE', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButton<UserRole>(
            value: activeRole,
            dropdownColor: AppConstants.darkSurface,
            isExpanded: true,
            underline: const SizedBox(),
            style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: UserRole.admin, child: Text('Admin (Full System Management)')),
              DropdownMenuItem(value: UserRole.technician, child: Text('Technician (View & Record Cleaning)')),
              DropdownMenuItem(value: UserRole.viewer, child: Text('Viewer (Read-Only Dashboards)')),
            ],
            onChanged: (role) {
              if (role != null) {
                ref.read(userRoleProvider.notifier).state = role;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Switched system role to ${role.name.toUpperCase()}')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
