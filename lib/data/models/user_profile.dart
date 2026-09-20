import '../../core/constants/app_constants.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? 'User',
      email: json['email'] ?? '',
      role: _parseRole(json['role']),
    );
  }

  static UserRole _parseRole(dynamic r) {
    if (r == 'admin') return UserRole.admin;
    if (r == 'technician') return UserRole.technician;
    return UserRole.viewer;
  }
}
