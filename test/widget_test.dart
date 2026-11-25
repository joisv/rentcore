import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('RentCoreApp smoke test and render', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RentCoreApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify SewaKasir login screen renders by default
    expect(find.text('SEWAKASIR'), findsOneWidget);
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
  });
}
