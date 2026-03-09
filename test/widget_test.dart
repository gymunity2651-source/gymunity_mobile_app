import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/app/app.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const GymUnityApp());
    // Splash screen should display the app name
    expect(find.text('GymUnity'), findsOneWidget);
  });
}
