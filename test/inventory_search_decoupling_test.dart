import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

void main() {
  group('Inventory Search Decoupling Tests', () {
    test('assetSearchQueryProvider and catalogSearchQueryProvider maintain independent state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Verify initial states are empty
      expect(container.read(assetSearchQueryProvider), '');
      expect(container.read(catalogSearchQueryProvider), '');

      // Set search query in Tab 0 (Unit Fisik / Asset Search)
      container.read(assetSearchQueryProvider.notifier).setSearch('SN-IP13-0092');

      // Verify Tab 0 updated, but Tab 1 (Catalog Search) remains empty
      expect(container.read(assetSearchQueryProvider), 'SN-IP13-0092');
      expect(container.read(catalogSearchQueryProvider), '');

      // Set search query in Tab 1 (Katalog & Tarif)
      container.read(catalogSearchQueryProvider.notifier).setSearch('MacBook Pro');

      // Verify both providers retain independent queries
      expect(container.read(assetSearchQueryProvider), 'SN-IP13-0092');
      expect(container.read(catalogSearchQueryProvider), 'MacBook Pro');

      // Clearing Tab 0 does not clear Tab 1
      container.read(assetSearchQueryProvider.notifier).setSearch('');
      expect(container.read(assetSearchQueryProvider), '');
      expect(container.read(catalogSearchQueryProvider), 'MacBook Pro');
    });
  });
}
