import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/idempotency_helper.dart';
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
    String? externalReference,
    String? idempotencyKey,
  }) async {
    final isCash = paymentMethodCode.toUpperCase() == 'CASH';
    final effectiveIdempotencyKey =
        (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        ? idempotencyKey.trim()
        : ((context.idempotencyKey != null &&
                  context.idempotencyKey!.trim().isNotEmpty)
              ? context.idempotencyKey!.trim()
              : IdempotencyHelper.generateUuidV4());

    switch (context.transactionType) {
      case PaymentTransactionType.booking:
        final payload = Map<String, dynamic>.from(context.extraPayload ?? {});
        if (context.branchId != null) {
          payload['branch_id'] ??= context.branchId;
          payload['affiliate_id'] ??= context.branchId;
        }
        payload['payment_method_id'] = paymentMethodId;
        payload['cash_received'] = isCash ? cashReceived : amountToPay;
        if (!isCash && externalReference != null && externalReference.trim().isNotEmpty) {
          payload['external_reference'] = externalReference.trim();
        }
        if (context.isDownPayment) {
          payload['paid_amount'] ??= amountToPay;
          payload['dp_amount'] ??= amountToPay;
        }

        final data = await _bookingRepo.createRental(
          payload,
          idempotencyKey: effectiveIdempotencyKey,
        );
        final change = isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0;
        final payments = (data['payments'] as List?) ?? [];
        final latestPayment = payments.isNotEmpty ? payments.last as Map? : null;
        final isPartial = context.isDownPayment ||
            data['payment_status']?.toString().toLowerCase() == 'partial';

        return PaymentResult(
          status: isPartial ? PaymentStatus.partial : PaymentStatus.completed,
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
                idempotencyKey: effectiveIdempotencyKey,
              )
            : await _bookingRepo.extendRental(
                context.bookingId ?? 0,
                context.additionalHours ?? 6,
                fee: amountToPay,
                paymentMethodId: paymentMethodId,
                cashReceived: isCash ? cashReceived : amountToPay,
                notes: notes,
                idempotencyKey: effectiveIdempotencyKey,
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
        if (context.transactionType == PaymentTransactionType.penalty &&
            context.extraPayload?['is_return_workflow'] == true) {
          final returnPayload = Map<String, dynamic>.from(context.extraPayload?['return_payload'] ?? {});
          returnPayload['penalty_payment_method_id'] = paymentMethodId;
          returnPayload['cash_received'] = isCash ? cashReceived : amountToPay;
          returnPayload['late_fee'] ??= amountToPay;
          returnPayload['total_penalty'] ??= amountToPay;
          returnPayload['penalty_amount'] ??= amountToPay;
          if (context.extraPayload?['frp_cleared'] != null) {
            returnPayload['frp_cleared'] ??= context.extraPayload!['frp_cleared'];
          }
          if (context.extraPayload?['account_removed'] != null) {
            returnPayload['account_removed'] ??= context.extraPayload!['account_removed'];
          }
          if (notes != null && notes.isNotEmpty) {
            returnPayload['staff_notes'] = notes;
          }

          final data = await _bookingRepo.processReturn(
            context.bookingId ?? 0,
            returnPayload,
            idempotencyKey: effectiveIdempotencyKey,
          );

          final booking = data['booking'] as Map?;
          final payments = (booking?['payments'] as List?) ?? [];
          Map? latestPenaltyPayment;
          for (final p in payments.reversed) {
            if (p is Map && p['type']?.toString().toLowerCase() == 'penalty') {
              latestPenaltyPayment = p;
              break;
            }
          }

          final change = isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0;

          final double actualAmountPaid = latestPenaltyPayment?['amount'] != null
              ? (double.tryParse(latestPenaltyPayment!['amount'].toString()) ?? amountToPay)
              : amountToPay;
          final double actualCashReceived = latestPenaltyPayment?['cash_received'] != null
              ? (double.tryParse(latestPenaltyPayment!['cash_received'].toString()) ?? (isCash ? cashReceived : amountToPay))
              : (isCash ? cashReceived : amountToPay);
          final double actualChange = latestPenaltyPayment?['cash_change'] != null
              ? (double.tryParse(latestPenaltyPayment!['cash_change'].toString()) ?? change)
              : change;

          return PaymentResult(
            status: PaymentStatus.completed,
            transactionCode: latestPenaltyPayment?['transaction_code'] ?? data['id']?.toString(),
            receiptNumber: latestPenaltyPayment?['receipt_number'],
            amountPaid: actualAmountPaid,
            cashReceived: actualCashReceived,
            cashChange: actualChange,
            paymentMethodCode: paymentMethodCode,
            paymentMethodName: paymentMethodName,
            responseData: data,
          );
        }

        final data = await _cashierRepo.processPayment(
          bookingId: context.bookingId ?? 0,
          paymentMethodId: paymentMethodId,
          amount: amountToPay,
          paymentType: context.transactionType == PaymentTransactionType.penalty ? 'penalty' : 'settlement',
          cashReceived: isCash ? cashReceived : amountToPay,
          notes: notes,
          externalReference: (!isCash && externalReference != null && externalReference.trim().isNotEmpty)
              ? externalReference.trim()
              : null,
          frpCleared: context.extraPayload?['frp_cleared'] as bool?,
          accountRemoved: context.extraPayload?['account_removed'] as bool?,
          isHandoverSettlement: context.isHandoverSettlement
              ? true
              : context.extraPayload?['is_handover_settlement'] as bool?,
          assetUnitId: (context.extraPayload?['asset_unit_id'] as num?)?.toInt(),
          collateralType: context.extraPayload?['collateral_type']?.toString(),
          collateralStorageSlot:
              context.extraPayload?['collateral_storage_slot']?.toString(),
          startNow: context.extraPayload?['start_now'] as bool?,
          keepOriginalEndAt:
              context.extraPayload?['keep_original_end_at'] as bool?,
          idempotencyKey: effectiveIdempotencyKey,
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
