class ApiConstants {
  // Can be adjusted via runtime settings or emulator default
  static const String defaultBaseUrl = 'http://192.168.1.93:8000/api/v1';
  static const String lanPcBaseUrl = 'http://192.168.1.93:8000/api/v1';
  static const String usbReverseBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String laragonVhostUrl = 'http://rentcore.test/api/v1';

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Dashboard
  static const String dashboardKpi = '/dashboard/kpi';

  // Assets & Catalog
  static const String assets = '/assets';
  static const String assetModels = '/assets/models';
  static const String categories = '/categories';
  static const String products = '/products';
  static String productRates(dynamic id) => '/products/$id/rates';
  static const String calculatePrice = '/pricing/calculate';
  static String assetAvailability(dynamic id) => '/assets/$id/availability';

  // Vouchers
  static const String vouchers = '/vouchers';
  static const String validateVoucher = '/vouchers/validate';
  static String printVoucherSlip(String code) => '/vouchers/$code/print-slip';

  // Bookings
  static const String bookings = '/bookings';
  static String bookingDetail(dynamic id) => '/bookings/$id';
  static String extendBooking(dynamic id) => '/bookings/$id/extend';
  static String returnBooking(dynamic id) => '/bookings/$id/return';

  // Cashier
  static const String closingSummary = '/cashier/closing-summary';
  static const String paymentMethods = '/cashier/payment-methods';
  static const String cashierPay = '/cashier/pay';
  static String cashierReceipt(dynamic id) => '/cashier/transactions/$id/receipt';

  // Inter-Affiliate Stock Transfers
  static const String transfers = '/transfers';
  static const String transferDestinations = '/transfers/destinations';
  static String receiveTransfer(dynamic id) => '/transfers/$id/receive';
  static String cancelTransfer(dynamic id) => '/transfers/$id/cancel';
  static String updateAsset(dynamic id) => '/assets/$id';

  // Customers & Identity Verification
  static const String customers = '/customers';
  static const String customerLookup = '/customers/lookup';
  static String customerIdentityDoc(dynamic id) => '/customers/$id/identity-document';
  static String toggleCustomerBlacklist(dynamic id) => '/customers/$id/blacklist';
}
