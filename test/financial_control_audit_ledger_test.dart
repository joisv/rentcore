import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/cashier/presentation/financial_activity_ledger_screen.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

void main() {
  testWidgets('FinancialActivityLedgerScreen renders ledger list and filter chips', (tester) async {
    final mockSummary = {
      'date': 'HARI INI',
      'recent_transactions': [
        {
          'id': 1,
          'transaction_code': 'TX-2026-0001',
          'amount': 250000.0,
          'payment_method': 'Tunai',
          'type': 'settlement',
          'status': 'completed',
          'direction': 'inflow',
          'customer_name': 'Ahmad Fauzi',
          'items_summary': 'iPhone 15 Pro Max',
          'transacted_at': '2026-10-20T10:00:00.000Z',
        },
        {
          'id': 2,
          'transaction_code': 'TX-2026-0002',
          'amount': 50000.0,
          'payment_method': 'Tunai',
          'type': 'refund',
          'status': 'completed',
          'direction': 'outflow',
          'customer_name': 'Siti Rahma',
          'items_summary': 'iPhone 13',
          'transacted_at': '2026-10-20T11:00:00.000Z',
        },
      ],
    };

    final mockExpenses = {
      'expenses': [
        {
          'id': 10,
          'expense_number': 'EXP-2026-001',
          'title': 'Beli Kertas Thermal Printer Kasir',
          'amount': 45000.0,
          'category': 'supplies',
          'payment_source': 'cash_drawer',
          'status': 'approved',
          'created_at': '2026-10-20T12:00:00.000Z',
        },
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          closingSummaryProvider.overrideWith((ref) => Future.value(mockSummary)),
          cashierExpensesProvider.overrideWith((ref) => Future.value(mockExpenses)),
        ],
        child: const MaterialApp(
          home: FinancialActivityLedgerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Screen Title
    expect(find.text('Buku Aktivitas Keuangan (Ledger)'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('Semua Aktivitas'), findsOneWidget);
    expect(find.text('Pemasukan (In)'), findsOneWidget);
    expect(find.text('Beban Cabang (Out)'), findsOneWidget);
    expect(find.text('Refund Deposit (Out)'), findsOneWidget);
    expect(find.text('Dibatalkan (Void)'), findsOneWidget);

    // Verify Ledger Items rendered
    expect(find.text('TX-2026-0001'), findsOneWidget);
    expect(find.text('Ahmad Fauzi • iPhone 15 Pro Max'), findsOneWidget);
    expect(find.text('Beli Kertas Thermal Printer Kasir'), findsOneWidget);
  });

  testWidgets('CashDrawerShiftModal renders open shift form and denomination counter', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Open Mode
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CashDrawerShiftModal(
              activeShift: null,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Buka Shift Kasir'), findsOneWidget);
    expect(find.text('Modal Awal Kas Laci (Opening Float) *'), findsOneWidget);
    expect(find.text('Buka Shift Kasir Sekarang'), findsOneWidget);

    // 2. Close Mode with Active Shift
    final activeShift = {
      'id': 1,
      'shift_number': 'SHF-2026-001',
      'opening_cash_float': 500000.0,
      'status': 'open',
    };

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CashDrawerShiftModal(
              activeShift: activeShift,
              expectedDrawerCash: 1200000.0,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsOneWidget);
    expect(find.text('HITUNG FISIK UANG KAS (DENOMINASI)'), findsOneWidget);
    expect(find.textContaining('100.000'), findsOneWidget);
    expect(find.textContaining('50.000'), findsOneWidget);
    expect(find.text('Tutup Shift & Rekapitulasi Kasir'), findsOneWidget);
  });

  testWidgets('PosTransactionDetailSheet renders void action button and dialog', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBooking = {
      'id': 100,
      'booking_id': 100,
      'booking_code': 'BK-TEST-VOID',
      'total_bill': 350000.0,
      'subtotal_amount': 350000.0,
      'discount_amount': 0.0,
      'payment_status': 'paid',
      'status': 'confirmed',
      'customer': {'name': 'Bambang Sudirman', 'phone': '08123456789'},
      'payments': [
        {
          'id': 501,
          'transaction_code': 'TX-TEST-501',
          'amount': 350000.0,
          'payment_method': 'Tunai',
          'status': 'completed',
          'type': 'settlement',
        },
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingDetailProvider(100).overrideWith((ref) => Future.value(mockBooking)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PosTransactionDetailSheet(booking: mockBooking),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify transaction detail rendered
    expect(find.text('Rincian Transaksi Rental POS'), findsOneWidget);
    expect(find.text('RIWAYAT TRANSAKSI PEMBAYARAN'), findsOneWidget);

    // Verify Void Button is displayed on completed payment
    final voidIcon = find.byIcon(Icons.cancel_outlined);
    expect(voidIcon, findsOneWidget);

    // Tap Void Button
    await tester.tap(voidIcon);
    await tester.pumpAndSettle();

    // Verify Void Confirmation Dialog appears
    expect(find.text('Batalkan Transaksi (Void)'), findsOneWidget);
    expect(find.text('Alasan Pembatalan *'), findsOneWidget);
    expect(find.text('PIN Manager Cabang'), findsOneWidget);
    expect(find.text('Void Transaksi'), findsOneWidget);
  });
}
