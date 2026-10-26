import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../bookings/data/booking_repository.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../cashier/data/cashier_repository.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../models/payment_context.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    cashierRepo: ref.watch(cashierRepositoryProvider),
    bookingRepo: ref.watch(bookingRepositoryProvider),
  );
});

class PaymentRepository {
  final CashierRepository _cashierRepo;
  final BookingRepository _bookingRepo;

  PaymentRepository({
    CashierRepository? cashierRepo,
    BookingRepository? bookingRepo,
  })  : _cashierRepo = cashierRepo ?? CashierRepository(),
        _bookingRepo = bookingRepo ?? BookingRepository();

  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return _cashierRepo.fetchPaymentMethods();
  }

  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? notes,
  }) async {
    final isCash = paymentMethodCode.toUpperCase() == 'CASH';

    switch (context.transactionType) {
      case PaymentTransactionType.booking:
        final payload = Map<String, dynamic>.from(context.extraPayload ?? {});
        payload['payment_method_id'] = paymentMethodId;
        payload['cash_received'] = isCash ? cashReceived : amountToPay;

        final data = await _bookingRepo.createRental(payload);
        final change = isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0;
        final payments = (data['payments'] as List?) ?? [];
        final latestPayment = payments.isNotEmpty ? payments.last as Map? : null;

        return PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: latestPayment?['transaction_code'] ?? data['booking_code'],
          receiptNumber: latestPayment?['receipt_number'] ?? data['booking_code'],
          amountPaid: amountToPay,
          cashReceived: isCash ? cashReceived : amountToPay,
          cashChange: change,
          paymentMethodCode: paymentMethodCode,
          paymentMethodName: paymentMethodName,
          responseData: data,
        );

      case PaymentTransactionType.extension:
        final extra = context.extraPayload ?? {};
        final bookingItemId = (extra['booking_item_id'] as num?)?.toInt();
        final data = bookingItemId != null
            ? await _bookingRepo.adjustDuration(
                bookingId: context.bookingId ?? 0,
                bookingItemId: bookingItemId,
                direction: 'increase',
                hoursDelta: context.additionalHours ?? 6,
                additionalFee: amountToPay,
                paymentMethodId: paymentMethodId,
                cashReceived: isCash ? cashReceived : amountToPay,
                notes: notes,
              )
            : await _bookingRepo.extendRental(
                context.bookingId ?? 0,
                context.additionalHours ?? 6,
                fee: amountToPay,
                paymentMethodId: paymentMethodId,
                cashReceived: isCash ? cashReceived : amountToPay,
                notes: notes,
              );

        final payment = data['payment'] as Map?;
        final change = (payment?['cash_change'] != null)
            ? CurrencyFormatter.parse(payment!['cash_change'])
            : (isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0);

        return PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: payment?['transaction_code'] ?? data['adjustment']?['id']?.toString() ?? data['extension']?['id']?.toString(),
          receiptNumber: payment?['receipt_number'] ?? data['receipt_number'],
          amountPaid: amountToPay,
          cashReceived: isCash ? cashReceived : amountToPay,
          cashChange: change,
          paymentMethodCode: paymentMethodCode,
          paymentMethodName: paymentMethodName,
          responseData: data,
        );

      case PaymentTransactionType.penalty:
      case PaymentTransactionType.settlement:
        final data = await _cashierRepo.processPayment(
          bookingId: context.bookingId ?? 0,
          paymentMethodId: paymentMethodId,
          amount: amountToPay,
          paymentType: context.transactionType == PaymentTransactionType.penalty ? 'penalty' : 'settlement',
          cashReceived: isCash ? cashReceived : amountToPay,
          notes: notes,
        );

        final payment = data['payment'] as Map?;
        final change = (data['cash_change'] != null)
            ? CurrencyFormatter.parse(data['cash_change'])
            : 0.0;

        return PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: payment?['transaction_code'] ?? data['transaction_code'],
          receiptNumber: data['receipt_number'] ?? payment?['receipt_number'],
          amountPaid: amountToPay,
          cashReceived: isCash ? cashReceived : amountToPay,
          cashChange: change,
          paymentMethodCode: paymentMethodCode,
          paymentMethodName: paymentMethodName,
          responseData: data,
        );
    }
  }
}
