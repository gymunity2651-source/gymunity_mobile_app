import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String localeNameFor(Locale locale) {
  return locale.languageCode == 'ar' ? 'ar_EG' : 'en_US';
}

String formatNumber(num value, Locale locale) {
  return NumberFormat.decimalPattern(localeNameFor(locale)).format(value);
}

String formatEgp(num value, Locale locale) {
  final digits = NumberFormat.decimalPattern(
    localeNameFor(locale),
  ).format(value);
  return locale.languageCode == 'ar' ? '$digits ج.م' : 'EGP $digits';
}

String localizedMeasurementUnitLabel(Locale locale, String value) {
  final isArabic = locale.languageCode == 'ar';
  switch (value) {
    case 'metric':
      return isArabic ? 'متري' : 'Metric';
    case 'imperial':
      return isArabic ? 'إمبراطوري' : 'Imperial';
    default:
      return value;
  }
}

String localizedRiskLevelLabel(Locale locale, String value) {
  final isArabic = locale.languageCode == 'ar';
  switch (value) {
    case 'low':
      return isArabic ? 'منخفض' : 'Low';
    case 'medium':
      return isArabic ? 'متوسط' : 'Medium';
    case 'high':
      return isArabic ? 'مرتفع' : 'High';
    default:
      return value;
  }
}

String localizedStatusLabel(Locale locale, String value) {
  final isArabic = locale.languageCode == 'ar';
  switch (value) {
    case 'in_progress':
      return isArabic ? 'قيد التنفيذ' : 'In progress';
    case 'pending':
      return isArabic ? 'قيد الانتظار' : 'Pending';
    case 'completed':
      return isArabic ? 'مكتمل' : 'Completed';
    case 'partial':
      return isArabic ? 'جزئي' : 'Partial';
    case 'skipped':
      return isArabic ? 'تم التخطي' : 'Skipped';
    case 'missed':
      return isArabic ? 'فائت' : 'Missed';
    case 'active':
      return isArabic ? 'نشط' : 'Active';
    case 'archived':
      return isArabic ? 'مؤرشف' : 'Archived';
    case 'published':
      return isArabic ? 'منشور' : 'Published';
    case 'draft':
      return isArabic ? 'مسودة' : 'Draft';
    default:
      return value;
  }
}
