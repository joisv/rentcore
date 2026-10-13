import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final bookingsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final status = ref.watch(bookingFilterStatusProvider);
  return repo.fetchBookings(status: status == 'all' ? null : status);
});

final readyAssetsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.fetchReadyAssets();
});
