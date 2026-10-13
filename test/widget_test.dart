import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RentCoreApp smoke test and render', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RentCoreApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify login screen renders by default
    expect(find.text('RENTCORE'), findsOneWidget);
    expect(find.text('Masuk Akun'), findsOneWidget);
  });
}
