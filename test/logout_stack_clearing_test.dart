import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';

void main() {
  testWidgets('logout-style stack clearing prevents back to protected screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: <String, WidgetBuilder>{
          AppRoutes.welcome: (_) => const Scaffold(body: Text('Welcome')),
          AppRoutes.memberHome: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.welcome,
                  (route) => false,
                );
              },
              child: const Text('Log out'),
            ),
          ),
        },
        initialRoute: AppRoutes.memberHome,
      ),
    );

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);

    final didPop = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(didPop, isFalse);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
  });
}
