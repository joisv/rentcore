import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/booking_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) => BookingRepository());

class BookingFilterNotifier extends Notifier<String?> {
  @override
  String? build() => 'rented';

  void setFilter(String? status) {
    state = status;
  }
}

final bookingFilterStatusProvider = NotifierProvider<BookingFilterNotifier, String?>(
  BookingFilterNotifier.new,
);

class BookingSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final bookingSearchQueryProvider = NotifierProvider<BookingSearchQueryNotifier, String>(
  BookingSearchQueryNotifier.new,
);

final bookingsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null || bizState.businesses.isEmpty) {
    return [];
  }
  final repo = ref.watch(bookingRepositoryProvider);
  final status = ref.watch(bookingFilterStatusProvider);
  final searchQuery = ref.watch(bookingSearchQueryProvider);
  return repo.fetchBookings(
    status: status == 'all' ? null : status,
    search: searchQuery.trim().isEmpty ? null : searchQuery.trim(),
    branchId: bizState.activeBranchId,
  );
});

final readyAssetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null || bizState.businesses.isEmpty) {
    return [];
  }
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.fetchReadyAssets(branchId: bizState.activeBranchId);
});
