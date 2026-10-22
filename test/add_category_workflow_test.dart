import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/add_product_sheet.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _MockCategoryAssetRepo extends AssetRepository {
  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
    {'id': 2, 'name': 'Lensa', 'slug': 'lensa'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    return List.from(_categories);
  }

  @override
  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> payload) async {
    final newId = _categories.length + 1;
    final cat = {
      'id': newId,
      'name': payload['name'],
      'slug': payload['name'].toString().toLowerCase().replaceAll(' ', '-'),
    };
    _categories.add(cat);
    return cat;
  }
}

class _MockCategoryBizNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Store',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Store',
            'role': 'owner',
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat', 'is_central': true},
            ],
          }
        ],
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Add Category from Add Model Workflow Tests', () {
    testWidgets('Quick add category dialog creates category and selects it in dropdown', (tester) async {
      final mockRepo = _MockCategoryAssetRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockCategoryBizNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AddProductSheet(
                onSuccess: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify category field exists
      expect(find.text('Kategori Perangkat *'), findsOneWidget);
      expect(find.text('Kategori Baru'), findsOneWidget);

      // Tap "Kategori Baru" to open dialog
      await tester.tap(find.text('Kategori Baru'));
      await tester.pumpAndSettle();

      // Verify AlertDialog is displayed
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);

      // Enter empty name and tap Simpan -> should show validation error inside modal
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Nama kategori wajib diisi.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Enter valid name
      final dialogTextField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(dialogTextField, 'Drone & Gimbal');
      await tester.pumpAndSettle();

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(AlertDialog), findsNothing);

      // Verify newly created category is selected in the dropdown
      expect(find.text('Drone & Gimbal'), findsOneWidget);
    });
  });
}
