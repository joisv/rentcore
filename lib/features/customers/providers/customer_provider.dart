import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository();
});

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final customerSearchQueryProvider =
    NotifierProvider<CustomerSearchQueryNotifier, String>(CustomerSearchQueryNotifier.new);

final customerSearchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.searchCustomers(query: query.isEmpty ? null : query);
});
