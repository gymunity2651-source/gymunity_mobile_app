int buildPlannerNotificationId({
  required String taskId,
  required DateTime scheduledDate,
  required String reminderTime,
}) {
  final key =
      '${taskId.toLowerCase()}|${scheduledDate.toIso8601String().split('T').first}|$reminderTime';
  var hash = 0;
  for (final codeUnit in key.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash;
}
