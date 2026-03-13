import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/error/app_failure.dart';

String describeStoreError(Object error, {required String fallbackMessage}) {
  if (error is AppFailure && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  return fallbackMessage;
}

String formatOrderStatus(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'paid':
      return 'Paid';
    case 'processing':
      return 'Processing';
    case 'shipped':
      return 'Shipped';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status.replaceAll('_', ' ');
  }
}

Color orderStatusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFE6A23C);
    case 'paid':
      return const Color(0xFF2F80ED);
    case 'processing':
      return const Color(0xFF27AE60);
    case 'shipped':
      return const Color(0xFF56CCF2);
    case 'delivered':
      return AppColors.orange;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.textMuted;
  }
}
