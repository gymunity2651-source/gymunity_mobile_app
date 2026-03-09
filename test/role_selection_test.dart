import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/app/routes.dart';
import 'package:my_app/features/auth/presentation/screens/role_selection_screen.dart';

void main() {
  testWidgets('RoleSelectionScreen renders without errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: const RoleSelectionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
  });
}
