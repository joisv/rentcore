import '../network/api_client.dart';

class ApiConstants {
  // Production endpoint (can be customized at build time via --dart-define=API_BASE_URL=...)
  static const String productionBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.rentcore.id/api/v1',
  );

  // Can be adjusted via runtime settings in development builds
  static const String defaultBaseUrl = 'http://192.168.1.101:8000/api/v1';
  static const String lanPcBaseUrl = 'http://192.168.1.101:8000/api/v1';
  static const String currentLanPcBaseUrl = 'http://192.168.1.101:8000/api/v1';
  static const String usbReverseBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String laragonVhostUrl = 'http://sewakasir_backend.test/api/v1';

  // Public App Gate & Telemetry
  static const String appConfig = '/app-config';

  // Auth & OAuth
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '285736278913-v12ke23f40magh6fh1oj1oq7jdsavt2i.apps.googleusercontent.com',
  );
  static const String login = '/auth/login';
  static const String googleSignIn = '/auth/google';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String updatePassword = '/auth/password';
  static const String completeWalkthrough = '/auth/walkthrough-completed';

  // Multi-Tenant Businesses
  static const String businesses = '/businesses';
  static String businessDetail(dynamic id) => '/businesses/$id';
  static String businessMembers(dynamic id) => '/businesses/$id/members';
  static String businessMember(dynamic bizId, dynamic memberId) =>
      '/businesses/$bizId/members/$memberId';
  static String reassignMemberBranch(dynamic bizId, dynamic memberId) =>
      '/businesses/$bizId/members/$memberId/reassign-branch';
  static String removeMemberBranch(
    dynamic bizId,
    dynamic memberId,
    dynamic branchId,
  ) => '/businesses/$bizId/members/$memberId/branches/$branchId';
  static String memberManagerPin(dynamic bizId, dynamic memberId) =>
      '/businesses/$bizId/members/$memberId/pin';
  static String businessBranches(dynamic id) => '/businesses/$id/branches';
  static String businessBranchDetail(dynamic bizId, dynamic branchId) =>
      '/businesses/$bizId/branches/$branchId';
  static String businessRentalRules(dynamic id) =>
      '/businesses/$id/rental-rules';
  static String branchBookingRules(dynamic branchId) =>
      '/branches/$branchId/booking-rules';
  static String resignationRequests(dynamic id) =>
      '/businesses/$id/resignation-requests';
  static String resignStatus(dynamic id) => '/businesses/$id/resign-status';
  static String resign(dynamic id) => '/businesses/$id/resign';
  static String cancelResignation(dynamic bizId, dynamic reqId) =>
      '/businesses/$bizId/resignation-requests/$reqId/cancel';
  static String approveResignation(dynamic bizId, dynamic reqId) =>
      '/businesses/$bizId/resignation-requests/$reqId/approve';
  static String rejectResignation(dynamic bizId, dynamic reqId) =>
      '/businesses/$bizId/resignation-requests/$reqId/reject';
  static String approveResignationById(dynamic reqId) =>
      '/resignation-requests/$reqId/approve';
  static String rejectResignationById(dynamic reqId) =>
      '/resignation-requests/$reqId/reject';

  // Dashboard
  static const String dashboardKpi = '/dashboard/kpi';

  // Assets & Catalog
  static const String assets = '/assets';
  static const String assetModels = '/assets/models';
  static const String categories = '/categories';
  static const String products = '/products';
  static String productDetail(dynamic id) => '/products/$id';
  static String updateProduct(dynamic id) => '/products/$id';
  static String productRates(dynamic id) => '/products/$id/rates';
  static const String calculatePrice = '/pricing/calculate';
  static String assetAvailability(dynamic id) => '/assets/$id/availability';

  // Vouchers
  static const String vouchers = '/vouchers';
  static const String validateVoucher = '/vouchers/validate';
  static String printVoucherSlip(String code) => '/vouchers/$code/print-slip';

  // Bookings
  static const String bookings = '/bookings';
  static const String bookingAvailability = '/bookings/availability';
  static String bookingDetail(dynamic id) => '/bookings/$id';
  static String bookingAvailableUnits(dynamic id) =>
      '/bookings/$id/available-units';
  static String checkInBooking(dynamic id) => '/bookings/$id/check-in';
  static String markBookingNoShow(dynamic id) => '/bookings/$id/no-show';
  static String cancelBooking(dynamic id) => '/bookings/$id/cancel';
  static String extendBookingGrace(dynamic id) => '/bookings/$id/extend-grace';
  static String extendBookingPickup(dynamic id) => '/bookings/$id/extend-pickup';
  static String rescheduleBooking(dynamic id) => '/bookings/$id/reschedule';
  static String extendBooking(dynamic id) => '/bookings/$id/extend';
  static String adjustBookingDuration(dynamic id) =>
      '/bookings/$id/adjust-duration';
  static String bookingLateFeePreview(dynamic id) =>
      '/bookings/$id/late-fee-preview';
  static String returnBooking(dynamic id) => '/bookings/$id/return';
  static String availableReplacements(dynamic id, {dynamic assetId}) =>
      assetId != null
      ? '/bookings/$id/available-replacements?asset_id=$assetId'
      : '/bookings/$id/available-replacements';
  static String exchangeBooking(dynamic id) => '/bookings/$id/exchange';

  // Cashier
  static const String closingSummary = '/cashier/closing-summary';
  static const String paymentMethods = '/cashier/payment-methods';
  static const String cashierPay = '/cashier/pay';
  static String voidTransaction(dynamic id) => '/cashier/transactions/$id/void';
  static String cashierReceipt(dynamic id) =>
      '/cashier/transactions/$id/receipt';
  static const String cashierExpenses = '/cashier/expenses';
  static String approveExpense(dynamic id) => '/cashier/expenses/$id/approve';
  static String voidExpense(dynamic id) => '/cashier/expenses/$id/void';
  static const String currentShift = '/cashier/shift/current';
  static const String openShift = '/cashier/shift/open';
  static const String closeShift = '/cashier/shift/close';
  static const String shiftHistory = '/cashier/shift/history';
  static const String shifts = '/cashier/shifts';
  static const String shiftSchedule = '/cashier/shift/schedule';
  static const String paymentSettings = '/payment-settings';
  static const String qrisImage = '/payment-settings/qris-image';

  // Inter-Affiliate Stock Transfers
  static const String transfers = '/transfers';
  static const String transferDestinations = '/transfers/destinations';
  static String transferRecipients(dynamic branchId) =>
      '/transfers/recipients?branch_id=$branchId';
  static String approveTransfer(dynamic id) => '/transfers/$id/approve';
  static String rejectTransfer(dynamic id) => '/transfers/$id/reject';
  static String receiveTransfer(dynamic id) => '/transfers/$id/receive';
  static String cancelTransfer(dynamic id) => '/transfers/$id/cancel';
  static String updateAsset(dynamic id) => '/assets/$id';
  static String deleteAsset(dynamic id) => '/assets/$id';
  static String approveAsset(dynamic id) => '/assets/$id/approve';
  static String rejectAsset(dynamic id) => '/assets/$id/reject';

  // Customers & Identity Verification
  static const String customers = '/customers';
  static const String customerLookup = '/customers/lookup';
  static String customerIdentityDoc(dynamic id) =>
      '/customers/$id/identity-document';
  static String toggleCustomerBlacklist(dynamic id) =>
      '/customers/$id/blacklist';

  // Tenant Notifications
  static const String notifications = '/notifications';
  static String markNotificationRead(dynamic id) => '/notifications/$id/read';
  static const String markAllNotificationsRead = '/notifications/read-all';

  /// Extracts the active server origin (scheme://host[:port][optional prefix]) from [baseUrl],
  /// stripping `/api/v1` (or `/api`) and trailing slashes.
  static String resolveServerOrigin({String? baseUrlOverride}) {
    final rawBase = (baseUrlOverride ?? ApiClient().currentBaseUrl).trim();
    final parsed = Uri.tryParse(rawBase);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      final portPart = parsed.hasPort ? ':${parsed.port}' : '';
      final prefixPath = parsed.path
          .replaceFirst(RegExp(r'/api/v\d+/?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'/api/?$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'/+$'), '');
      return '${parsed.scheme}://${parsed.host}$portPart$prefixPath';
    }
    return rawBase
        .replaceFirst(RegExp(r'/api/v\d+/?$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'/api/?$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  /// Resolves a raw media/storage URL against the active API server origin.
  ///
  /// - Returns `null` if empty, invalid, or a raw `data:image/...` blob.
  /// - Prepends the active server origin when [rawUrl] starts with `/storage/`
  ///   or `storage/` (or a bare storage directory like `models/`).
  /// - Rewrites localhost / stale dev hosts (`rentcore_backend.test`, `127.0.0.1`,
  ///   `localhost`, `10.0.2.2`, `sewakasir_backend.test`) to the active server host.
  static String? resolveMediaUrl(String? rawUrl, {String? baseUrlOverride}) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase().startsWith('data:image')) return null;

    final origin = resolveServerOrigin(baseUrlOverride: baseUrlOverride);
    if (origin.isEmpty) return null;

    if (trimmed.startsWith('/storage/') || trimmed.startsWith('storage/')) {
      final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return '$origin$normalizedPath';
    }

    final withoutPublicPrefix = trimmed.startsWith('public/')
        ? trimmed.substring('public/'.length)
        : trimmed;
    if (withoutPublicPrefix.startsWith('models/') ||
        withoutPublicPrefix.startsWith('asset_models/') ||
        withoutPublicPrefix.startsWith('qris/')) {
      return '$origin/storage/$withoutPublicPrefix';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) return null;
      final hostLower = uri.host.toLowerCase();
      final isStaleOrLocalHost = hostLower == 'localhost' ||
          hostLower == '127.0.0.1' ||
          hostLower == '10.0.2.2' ||
          hostLower == 'rentcore_backend.test' ||
          hostLower == 'sewakasir_backend.test' ||
          hostLower.contains('rentcore_backend') ||
          hostLower.endsWith('.test') ||
          hostLower.endsWith('.local');

      if (isStaleOrLocalHost) {
        final originUri = Uri.tryParse(origin);
        if (originUri != null && originUri.hasScheme && originUri.host.isNotEmpty) {
          return uri
              .replace(
                scheme: originUri.scheme,
                host: originUri.host,
                port: originUri.hasPort ? originUri.port : null,
              )
              .toString();
        }
      }
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '$origin$trimmed';
    }

    return null;
  }
}
