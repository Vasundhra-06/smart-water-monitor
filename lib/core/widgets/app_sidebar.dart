import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';
import '../providers/app_providers.dart';

class AppSidebar extends ConsumerWidget {
  final String activeRoute;

  const AppSidebar({
    super.key,
    required this.activeRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTank = ref.watch(selectedTankProvider);
    final activeTankName = selectedTank?.tankName ?? 'Main Tank';

    return Container(
      width: 240,
      color: AppConstants.darkCardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header (App Title & Branding)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.accentCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: AppConstants.accentCyan, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.appName,
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                          const SizedBox(width: 4),
                          Text(activeTankName, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppConstants.darkCardBorder, height: 1),
          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Text('MONITORING', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                  _navTile(context, 'Dashboard', Icons.dashboard_rounded, '/dashboard'),
                  _navTile(context, 'Storage Tanks', Icons.water_rounded, '/tanks'),

                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Text('REPORTS & MAINTENANCE', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                  _navTile(context, 'Audit Reports', Icons.picture_as_pdf_rounded, '/reports'),
                  _navTile(context, 'Cleaning Log', Icons.cleaning_services_rounded, '/cleaning-history'),
                  _navTile(context, 'Settings', Icons.settings_rounded, '/settings'),
                ],
              ),
            ),
          ),

          // Bottom Sidebar Footer Mini-Card
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.darkCardBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF00E676), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('System Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('5 Telemetry Probes Active', style: TextStyle(color: Colors.white54, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, String title, IconData icon, String route) {
    final isSelected = activeRoute == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              context.go(route);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppConstants.accentCyan.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: AppConstants.accentCyan.withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppConstants.accentCyan : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isSelected ? AppConstants.accentCyan : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppConstants.accentCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
