import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Smart Water Monitor';
  static const String tagline = 'AI-Powered Drinking Water Quality Monitoring';

  // Configurable Python Backend API URL (Default localhost:8080)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // ThingSpeak Information
  static const String thingSpeakChannelId = '3487158';

  // Sensor Normal Operational Baselines
  static const double basePh = 7.2;
  static const double baseTds = 235.0; // ppm
  static const double baseTurbidity = 1.2; // NTU
  static const double baseTemperature = 26.5; // °C
  static const double baseWaterLevel = 78.0; // %

  // Thresholds for Alerts
  static const double turbWarningThreshold = 2.5; // NTU
  static const double turbCriticalThreshold = 4.0; // NTU
  static const double tdsWarningThreshold = 500.0; // ppm
  static const double tdsCriticalThreshold = 1000.0; // ppm
  static const double phMinThreshold = 6.5;
  static const double phMaxThreshold = 8.5;

  // Status Colors
  static const Color colorExcellent = Color(0xFF00E676); // Vibrant Green
  static const Color colorGood = Color(0xFF29D07D); // Green
  static const Color colorAttention = Color(0xFFFFB300); // Amber / Yellow
  static const Color colorPoor = Color(0xFFFF9100); // Orange
  static const Color colorCritical = Color(0xFFFF3D00); // Red
  static const Color colorInfo = Color(0xFF00B0FF); // Cyan Blue

  // Navy / Dark Theme & Glassmorphism Palette
  static const Color darkBackground = Color(0xFF050B18);
  static const Color darkCardBackground = Color(0x8C14233C); // rgba(20, 35, 60, 0.55)
  static const Color darkCardBorder = Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.10)
  static const Color darkSurface = Color(0xFF0C162A);
  static const Color primaryBlue = Color(0xFF0288D1);
  static const Color accentCyan = Color(0xFF00E5FF);

  // Status Helpers (Section 5 Specification)
  // >= 90 → Excellent | >= 75 → Good | >= 50 → Moderate | >= 25 → Poor | < 25 → Very Poor
  static String getScoreLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 50) return 'Moderate';
    if (score >= 25) return 'Poor';
    return 'Very Poor';
  }

  static Color getScoreColor(int score) {
    if (score >= 90) return colorExcellent;
    if (score >= 75) return colorGood;
    if (score >= 50) return colorAttention;
    if (score >= 25) return colorPoor;
    return colorCritical;
  }
}

enum UserRole { admin, technician, viewer }
enum TankStatus { online, offline, maintenance }
enum PowerStatus { mains, backup, offline }
enum SimulationScenario { normal, deteriorating, critical, deviceOffline, powerFailure }
