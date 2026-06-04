import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../constants/app_colors.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({
    super.key,
    required this.reason,
    required this.fallbackRoute,
  });

  final String reason;
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 40),
              const SizedBox(height: 16),
              const Text(
                'You do not have access to this area.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(reason, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    fallbackRoute.isEmpty ? AppRoutes.welcome : fallbackRoute,
                    (route) => false,
                  );
                },
                child: const Text('Go to my dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
