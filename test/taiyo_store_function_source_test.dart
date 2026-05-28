import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store recommendations cart context matches store_carts schema', () {
    final source = File(
      'supabase/functions/taiyo-store-recommendations/index.ts',
    ).readAsStringSync();
    final loadCartContext = source.substring(
      source.indexOf('async function loadCartContext'),
      source.indexOf('function noProductsResponse'),
    );

    expect(loadCartContext, isNot(contains('.eq("status", "active")')));
    expect(loadCartContext, isNot(contains('select("id,status,updated_at")')));
  });
}
