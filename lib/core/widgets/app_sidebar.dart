import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final String activeRoute;

  const AppSidebar({
    super.key,
    required this.activeRoute,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
