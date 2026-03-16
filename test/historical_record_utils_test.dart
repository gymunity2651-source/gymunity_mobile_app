import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/utils/historical_record_utils.dart';

void main() {
  test('normalizeHistoricalId returns empty string for missing ids', () {
    expect(normalizeHistoricalId(null), '');
    expect(normalizeHistoricalId(''), '');
    expect(normalizeHistoricalId('   '), '');
    expect(normalizeHistoricalId('user-1'), 'user-1');
  });

  test('normalizeHistoricalLabel falls back for missing actor names', () {
    expect(normalizeHistoricalLabel(null, 'Deleted seller'), 'Deleted seller');
    expect(normalizeHistoricalLabel('', 'Deleted seller'), 'Deleted seller');
    expect(
      normalizeHistoricalLabel('  Coach Mona  ', 'Deleted coach'),
      'Coach Mona',
    );
  });
}
