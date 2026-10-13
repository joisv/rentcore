import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/voucher_repository.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) => VoucherRepository());

final vouchersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(voucherRepositoryProvider);
  return repo.fetchVouchers();
});
