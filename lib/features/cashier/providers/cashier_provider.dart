import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cashier_repository.dart';

final cashierRepositoryProvider = Provider<CashierRepository>((ref) => CashierRepository());

final closingSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(cashierRepositoryProvider);
  return repo.fetchClosingSummary();
});

final paymentMethodsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(cashierRepositoryProvider);
  return repo.fetchPaymentMethods();
});

final cashierBookingsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, search) async {
  final repo = ref.watch(cashierRepositoryProvider);
  return repo.fetchBookingsForCashier(search: search);
});
