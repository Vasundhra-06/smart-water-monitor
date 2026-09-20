import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/live_data/live_data_screen.dart';
import '../../features/live_data/parameter_detail_screen.dart';
import '../../features/graphs/graphs_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/alerts/alert_detail_screen.dart';
import '../../features/tanks/tanks_screen.dart';
import '../../features/tanks/add_tank_screen.dart';
import '../../features/tanks/tank_detail_screen.dart';
import '../../features/cleaning/cleaning_history_screen.dart';
import '../../features/cleaning/record_cleaning_screen.dart';
import '../../features/device/device_details_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/reports_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),

    // Core Bottom Navigation Shell Route / Main Navigation
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),

    GoRoute(path: '/live-data', builder: (context, state) => const LiveDataScreen()),
    GoRoute(
      path: '/parameter-details',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ParameterDetailScreen(
          parameterName: extra['parameter'] ?? 'pH',
          value: (extra['value'] as num?)?.toDouble() ?? 7.2,
          unit: extra['unit'] ?? '',
        );
      },
    ),

    GoRoute(path: '/graphs', builder: (context, state) => const GraphsScreen()),
    GoRoute(path: '/alerts', builder: (context, state) => const AlertsScreen()),
    GoRoute(
      path: '/alert-details',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AlertDetailScreen(alertData: extra);
      },
    ),

    GoRoute(path: '/tanks', builder: (context, state) => const TanksScreen()),
    GoRoute(path: '/add-tank', builder: (context, state) => const AddTankScreen()),
    GoRoute(
      path: '/tank-details',
      builder: (context, state) {
        final tankId = state.extra as String? ?? 'tank-main';
        return TankDetailScreen(tankId: tankId);
      },
    ),

    GoRoute(path: '/cleaning-history', builder: (context, state) => const CleaningHistoryScreen()),
    GoRoute(path: '/record-cleaning', builder: (context, state) => const RecordCleaningScreen()),
    GoRoute(path: '/device-details', builder: (context, state) => const DeviceDetailsScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
  ],
);
