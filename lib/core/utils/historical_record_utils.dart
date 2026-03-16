String normalizeHistoricalId(Object? value) {
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String normalizeHistoricalLabel(Object? value, String fallback) {
  if (value is String) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return fallback;
}
