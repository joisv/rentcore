import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/transfer_repository.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepository();
});

class TransferDirectionNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setDirection(String direction) {
    state = direction;
  }
}

final selectedTransferDirectionProvider = NotifierProvider<TransferDirectionNotifier, String>(
  TransferDirectionNotifier.new,
);

class TransferStatusNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setStatus(String? status) {
    state = status;
  }
}

final selectedTransferStatusProvider = NotifierProvider<TransferStatusNotifier, String?>(
  TransferStatusNotifier.new,
);

final transfersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  final direction = ref.watch(selectedTransferDirectionProvider);
  final status = ref.watch(selectedTransferStatusProvider);

  return repo.fetchTransfers(
    direction: direction == 'all' ? null : direction,
    status: status,
  );
});

final destinationAffiliatesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.fetchDestinationAffiliates();
});
