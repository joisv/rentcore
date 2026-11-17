# Graph Report - rentcore  (2026-11-17)

## Corpus Check
- 220 files · ~231,235 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 3806 nodes · 6226 edges · 191 communities (139 shown, 52 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7cb660c0`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Thermal Printer Data Models
- transfers_screen.dart
- Core API & Network Client
- Direct Rental Booking
- macOS Native Runner App
- Thermal Receipt Printing Service
- Organization & Branch Management
- Payment Gateway & Processing
- Inventory & Asset Catalog
- Voucher & Discount Rules
- Linux Native Desktop Runner
- Thermal Printer Management
- paginated_result.dart
- rental_queue_actions.dart
- cashier_and_header_standardization_test.dart
- skeleton_loading.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- cashier_screen.dart
- payment_page.dart
- customer_directory_to_booking_prefill_test.dart
- Printer Bluetooth Driver Module
- thermal_receipt_preview_dialog.dart
- Home Dashboard & Analytics
- shift_schedule_screen.dart
- Rental Return Processing
- App Colors Module
- businessProvider
- home_header_and_unread_badge_test.dart
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- voucher_management_test.dart
- dock_aware_scaffold.dart
- generate_onboarding_figcraft.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- main.dart
- login_screen.dart
- auth_lifecycle_relogin_test.dart
- revenue_report_screen.dart
- Map
- notification_item.dart
- Booking Management System
- Authentication & User Session
- rentcore_app_bar.dart
- status_badge.dart
- Windows Native Desktop Runner
- user_profile_screen.dart
- business_setup_wizard_screen.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- auth_provider.dart
- payment_page_test.dart
- pos_numpad.dart
- payment_method_settings_screen.dart
- bookings_screen.dart
- exchange_wizard_screen.dart
- store_profile_screen.dart
- payment_page_shift_activation_test.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- ConsumerState
- inventory_live_payload_test.dart
- animated_success_checkmark.dart
- add_branch_expense_modal.dart
- customer_provider.dart
- late_return_penalty_pos_test.dart
- store_settings_screen.dart
- late_return_penalty_return_workflow_test.dart
- List
- Cashier POS & Register
- unit_thumbnail.dart
- Windows Native Desktop Runner
- notification_provider.dart
- Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?
- .Create
- Mainactivity Module
- Android Native Activity Runner
- Android Native Activity Runner
- Android Native Activity Runner
- Android Native Activity Runner
- Android Native Activity Runner
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- iOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- macOS Native Runner App
- Flutter Web Shell Platform
- Flutter Web Shell Platform
- Flutter Web Shell Platform
- Flutter Web Shell Platform
- Flutter Web Shell Platform
- asset_provider.dart
- ../../core/constants/app_colors.dart
- onboarding_provider.dart
- financial_activity_ledger_screen.dart
- app_text_styles.dart
- booking_provider.dart
- notification_and_branch_switcher_simplification_test.dart
- notification_center_screen.dart
- StatelessWidget
- financial_hub_screen.dart
- booking_rc_261030_0001_late_penalty_bug_fix_test.dart
- quick_open_shift_modal.dart
- package:shared_preferences/shared_preferences.dart
- staff_resignation_sheet.dart
- package:flutter_test/flutter_test.dart
- package:rentcore_mobile/features/cashier/providers/cashier_provider.dart
- customer_directory_screen.dart
- rental_duration_multiplier_test.dart
- package:flutter_secure_storage/flutter_secure_storage.dart
- inventory_unit_deduplication_test.dart
- voucher_screen.dart
- feature_walkthrough_screen.dart
- add_customer_sheet.dart
- cashier_shift_and_rental_queue_refactor_test.dart
- pos_all_branches_filter_test.dart
- rental_addons_and_policies_test.dart
- currency_formatter.dart
- device_protection_quarantine_return_test.dart
- package:flutter_test/flutter_test.dart
- printerProvider
- navigation_laporan_and_queue_actions_test.dart
- Win32Window
- int?
- package:flutter_riverpod/flutter_riverpod.dart
- pos_all_branches_filter_test.dart
- staff_resignation_test.dart
- BookingRepository
- CashierRepository
- ../../auth/providers/business_provider.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- organizationProvider
- printer_settings_screen.dart
- ../../core/utils/currency_formatter.dart
- notification_center_test.dart
- customer_repository.dart
- .MessageHandler
- qris_service.dart
- progressive_checklist_banner.dart
- date_formatter.dart
- payment_repository.dart
- cash_suggestion_helper.dart
- _MainShellScreenState
- _BusinessOnboardingDialogState
- SingleTickerProviderStateMixin
- _AddBranchBottomSheetState
- _InviteMemberBottomSheetState
- direct_rental_streamline_and_multiplier_test.dart
- _RentalRulesTabViewState
- BusinessNotifier
- NotificationNotifier
- Size
- transfer_provider.dart
- businessProvider
- package:flutter_test/flutter_test.dart

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 91 edges
2. `BusinessNotifier` - 59 edges
3. `authProvider` - 48 edges
4. `AuthNotifier` - 41 edges
5. `BusinessState` - 40 edges
6. `BookingRepository` - 32 edges
7. `printerProvider` - 30 edges
8. `CashierRepository` - 28 edges
9. `organizationProvider` - 28 edges
10. `cashierRepositoryProvider` - 22 edges

## Surprising Connections (you probably didn't know these)
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/cashier_shift_inline_buttons_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_and_booking_refinements_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockGoogleAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockPasswordAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dynamic_qris_end_to_end_test.dart → lib/features/auth/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (191 total, 52 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.08
Nodes (27): _bookingRepo, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer, createState (+19 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.02
Nodes (80): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+72 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.02
Nodes (92): _addonSearchController, _addonSearchQuery, _addonSubtotal, _addressController, _assetValidationError, _basePrice, _buildAddonsSelectionSection, _buildBookingPaymentContext (+84 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.05
Nodes (18): Cocoa, file_selector_macos, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate (+10 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (36): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+28 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (32): _addonsEnabled, _addressController, branches, _buildCard, _buildPendingResignationBanner, _buildRoleBadge, _buildRoleChoice, businessId (+24 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.04
Nodes (45): additionalHours, addonSubtotal, amountPaid, assetCode, booking, bookingCode, bookingId, branchId (+37 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.05
Nodes (42): _accessoriesController, _addPresetRate, _addRateRow, _brandController, build, _buildModelPhotoPicker, _buildPresetChip, _colorController (+34 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (26): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+18 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.05
Nodes (38): PrinterConnectionStatus, ThermalPrinterDevice, build, connectDevice, connectedDevice, copyWith, disconnect, discoveredDevices (+30 more)

### Community 12 - "paginated_result.dart"
Cohesion: 0.18
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 13 - "rental_queue_actions.dart"
Cohesion: 0.06
Nodes (26): _AdjustmentTarget, _buildDurationMultiplierRow, _computeMaxDurationMultiplier, currentDurationHours, currentPrice, _DurationOption, _getDurationOptionsForTarget, getItemCategoryIcon (+18 more)

### Community 14 - "cashier_and_header_standardization_test.dart"
Cohesion: 0.06
Nodes (25): build, _EmptyBookingRepo, fetchBookings, fetchBookingsForCashier, fetchBranchExpenses, fetchClosingSummary, fetchPaymentMethods, _MockCashierBizNotifier (+17 more)

### Community 15 - "skeleton_loading.dart"
Cohesion: 0.07
Nodes (26): borderRadius, build, _buildMetricCard, child, circle, color, _colorAnimation, _controller (+18 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.06
Nodes (30): PrintMode, ReceiptCustomizationSettings, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard (+22 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.02
Nodes (75): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildCatalogView, _buildChip, _buildDrawerButton (+67 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.06
Nodes (30): VoucherRepository, build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading (+22 more)

### Community 19 - "cashier_screen.dart"
Cohesion: 0.08
Nodes (23): build, _buildCompactFilterChip, _buildCustomShiftHistoryDateFilterChip, _buildDetailRow, _buildShiftClosingActionButtons, _buildShiftHistoryCard, _calcCashTotal, _calcNonCashTotal (+15 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.03
Nodes (58): _actionsTrack, _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile (+50 more)

### Community 21 - "customer_directory_to_booking_prefill_test.dart"
Cohesion: 0.09
Nodes (20): PaymentRepository, PaymentContext, PaymentResult, executePayment, lastContext, main, mockCategories, mockPaymentMethods (+12 more)

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.14
Nodes (9): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+1 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.04
Nodes (37): _buildBusinessErrorCard, _buildConsolidatedBanner, _buildDailyOperationsGrid, _buildDashboardContent, _buildErrorCard, _buildOnboardingBanner, _buildOperationCard, _buildOverdueAlertCard (+29 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (24): _branchClosingTime, _branchOpeningTime, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard, _buildTimePickerTile, _closingTime (+16 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.06
Nodes (30): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _canSubmitReturn, _category (+22 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "businessProvider"
Cohesion: 0.07
Nodes (38): _buildStep3FinancialAndAuth, ExchangeWizardScreen, _ExchangeWizardScreenState, _buildShiftHistoryDateFilterChips, _buildShiftHistoryTab, activeShiftProvider, bizState, build (+30 more)

### Community 29 - "home_header_and_unread_badge_test.dart"
Cohesion: 0.13
Nodes (14): build, checkCurrentSession, emptyKpi, fetchNotifications, fetchUnreadCountCalls, fetchUnreadCountOnly, _initialState, main (+6 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.04
Nodes (48): activeShift, branchId, build, _buildCloseShiftMiddleContent, _buildCoinRow, _buildDenominationRow, _buildDirectTotalInput, _buildHeader (+40 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (30): branches, build, businessId, businessName, cancelResignation, copyWith, createBranch, error (+22 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.08
Nodes (23): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, build, businesses, businessProfileProvider, copyWith (+15 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.10
Nodes (18): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+10 more)

### Community 34 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (17): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+9 more)

### Community 35 - "dock_aware_scaffold.dart"
Cohesion: 0.11
Nodes (17): appBar, backgroundColor, body, bottomSheet, build, DockAwareScaffold, DockClearance, DockEdgeInsetsExtension (+9 more)

### Community 36 - "generate_onboarding_figcraft.dart"
Cohesion: 0.03
Nodes (74): archCard, authCard, avtBtn, b1, bellBtn, bizPill, btnBack3, btnBack4 (+66 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.07
Nodes (26): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildBranchRow, _buildCurrentStepBody, _buildMonochromePill (+18 more)

### Community 39 - "main.dart"
Cohesion: 0.09
Nodes (6): createState, _currentTabIndex, initializeDateFormatting, main, null, _openNewBookingSheet

### Community 40 - "login_screen.dart"
Cohesion: 0.12
Nodes (15): build, createState, dispose, _emailController, _getEffectiveServerClientId, _handleGoogleSignIn, _login, LoginScreen (+7 more)

### Community 41 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.09
Nodes (19): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+11 more)

### Community 42 - "revenue_report_screen.dart"
Cohesion: 0.11
Nodes (15): _buildBranchContributionBreakdown, _buildBranchSelectorHeader, _buildCompactFilterChip, _buildCustomDateFilterChip, _buildHeroRevenueCard, _buildIncomeTypeBreakdown, _buildPaymentMethodBreakdown, _buildRecentTransactionsAudit (+7 more)

### Community 43 - "Map"
Cohesion: 0.03
Nodes (60): AuthRepository, _FakeAuthRepository, _FakeAuthRepository, completeWalkthrough, _FakeWalkthroughAuthRepository, isWalkthroughCompleted, main, walkthroughApiCalled (+52 more)

### Community 44 - "notification_item.dart"
Cohesion: 0.11
Nodes (16): actionPayload, actionRoute, affiliate, affiliateId, body, businessId, category, copyWith (+8 more)

### Community 45 - "Booking Management System"
Cohesion: 0.17
Nodes (11): adjustDuration, _client, createRental, exchangeRentalUnit, extendRental, fetchAvailableReplacements, fetchBookingDetail, fetchBookings (+3 more)

### Community 46 - "Authentication & User Session"
Cohesion: 0.05
Nodes (36): approveResignation, cancelResignation, checkSession, clearWizardDraft, _client, completeWalkthrough, createBranch, createBusiness (+28 more)

### Community 47 - "rentcore_app_bar.dart"
Cohesion: 0.11
Nodes (16): actions, automaticallyImplyLeading, backgroundColor, bottom, build, centerTitle, color, leading (+8 more)

### Community 48 - "status_badge.dart"
Cohesion: 0.11
Nodes (16): backgroundColor, borderColor, borderRadius, build, fontSize, icon, inventory, isLineThrough (+8 more)

### Community 49 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (5): AssetStatusFilterNotifier, wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "user_profile_screen.dart"
Cohesion: 0.10
Nodes (21): build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials, _handleSavePassword, _handleSaveProfile (+13 more)

### Community 51 - "business_setup_wizard_screen.dart"
Cohesion: 0.07
Nodes (28): _boundUserId, _branchStructure, build, _buildBottomActionBar, _buildBranchOptionCard, _buildStep1BusinessName, _buildStep2BranchStructure, _buildStep3CategoryPersonalization (+20 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (21): booking, bookingId, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer, createState (+13 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.11
Nodes (18): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, createProductMultipart, deleteAsset (+10 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.11
Nodes (11): build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, logout, _repository (+3 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (28): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+20 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.12
Nodes (15): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+7 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.07
Nodes (25): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _hasValidQrisPayload, _isDynamicQrisEnabled (+17 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.06
Nodes (25): 7, _buildFilterChip, _clearSearch, createState, _currentBookingPage, _debounceTimer, didUpdateWidget, dispose (+17 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (42): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+34 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

### Community 61 - "payment_page_shift_activation_test.dart"
Cohesion: 0.13
Nodes (11): defaultPaymentMethods, FakeCashierRepoForShiftTest, fetchCurrentShift, hasActiveShift, main, openedBranchId, openedFloat, openShift (+3 more)

### Community 62 - "Asset Transfer Workflow"
Cohesion: 0.18
Nodes (10): approveTransfer, cancelTransfer, _client, createTransfer, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, receiveTransfer (+2 more)

### Community 63 - "Flutter Web Shell Platform"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 64 - "Core API & Network Client"
Cohesion: 0.17
Nodes (6): _baseUrl, currentBaseUrl, dio, init, _instance, updateBaseUrl

### Community 65 - "Voucher & Discount Rules"
Cohesion: 0.14
Nodes (12): ApiClient, _client, fetchKpi, _client, createVoucher, deleteVoucher, fetchPrintSlip, fetchVouchers (+4 more)

### Community 66 - "ConsumerState"
Cohesion: 0.07
Nodes (43): ReturnWizardScreen, _ReturnWizardScreenState, _buildBranchSelectorHeader, _CashierShiftViewState, build, _FinancialActivityLedgerScreenState, _VoidTransactionDialog, _VoidTransactionDialogState (+35 more)

### Community 67 - "inventory_live_payload_test.dart"
Cohesion: 0.05
Nodes (34): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+26 more)

### Community 68 - "animated_success_checkmark.dart"
Cohesion: 0.09
Nodes (19): build, checkColor, _CheckmarkStrokePainter, _checkProgress, circleColor, _circleScale, color, _controller (+11 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (17): AddBranchExpenseModal, _amountController, branchId, build, _categories, createState, dispose, _errorMessage (+9 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.05
Nodes (36): CustomerRepository, build, copyWith, createCustomer, currentPage, CustomerNotifier, customerRepositoryProvider, customers (+28 more)

### Community 71 - "late_return_penalty_pos_test.dart"
Cohesion: 0.12
Nodes (15): build, _FakeCashierRepository, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState (+7 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.12
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "late_return_penalty_return_workflow_test.dart"
Cohesion: 0.12
Nodes (16): build, buildTestScreen, businessState, fakeBookingRepo, _FakeBookingRepositoryForReturn, fakeCashierRepo, fetchCurrentShift, fetchPaymentMethods (+8 more)

### Community 74 - "List"
Cohesion: 0.03
Nodes (65): AssetRepository, build, _categories, createCategory, fetchCategories, main, _MockCategoryAssetRepo, _MockCategoryBizNotifier (+57 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.10
Nodes (19): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+11 more)

### Community 77 - "unit_thumbnail.dart"
Cohesion: 0.12
Nodes (13): backgroundColor, borderRadius, build, _buildFallback, candidates, extractUnitImageUrl, fallbackIcon, iconColor (+5 more)

### Community 79 - "notification_provider.dart"
Cohesion: 0.13
Nodes (13): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, _isFetchingUnreadCount, isLoading, markAllAsRead (+5 more)

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.19
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "asset_provider.dart"
Cohesion: 0.08
Nodes (44): AuthNotifier, _invalidateTenantAndUserData, customerSearchQueryProvider, _AddProductSheetState, _AddAssetSheet, _AddAssetSheetState, build, initState (+36 more)

### Community 128 - "../../core/constants/app_colors.dart"
Cohesion: 0.14
Nodes (9): onAddNewModel, onSelectProduct, build, _buildCenterActionButton, _buildDockItem, currentIndex, FloatingCapsuleDock, onAddTap (+1 more)

### Community 129 - "onboarding_provider.dart"
Cohesion: 0.12
Nodes (14): build, completeWalkthrough, copyWith, dismissChecklist, hasCompletedWalkthrough, isChecklistDismissed, isLoading, OnboardingState (+6 more)

### Community 130 - "financial_activity_ledger_screen.dart"
Cohesion: 0.13
Nodes (11): _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen, _searchController (+3 more)

### Community 131 - "app_text_styles.dart"
Cohesion: 0.17
Nodes (5): AppTextStyles, pageHeader, pageHeaderHorizontalPadding, pageHeaderToolbarHeight, AppTheme

### Community 132 - "booking_provider.dart"
Cohesion: 0.09
Nodes (27): BookingsScreen, _BookingsScreenState, build, _onBookingsScroll, build, DirectRentalScreen, _DirectRentalScreenState, _executeExchangeSubmission (+19 more)

### Community 133 - "notification_and_branch_switcher_simplification_test.dart"
Cohesion: 0.12
Nodes (16): build, checkCurrentSession, _FakeAuthNotifier, _FakeBusinessNotifier, fetchNotifications, _initialState, lastIsConsolidated, lastMarkedReadId (+8 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.11
Nodes (16): didChangeAppLifecycleState, _handleRefresh, initState, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationRow (+8 more)

### Community 135 - "StatelessWidget"
Cohesion: 0.13
Nodes (14): ActiveShiftSkeleton, BookingCardSkeleton, CatalogTabSkeleton, DashboardSkeletonView, DashboardSummaryGridSkeleton, DetailViewSkeleton, PhysicalUnitsTabSkeleton, RentalQueueListSkeleton (+6 more)

### Community 136 - "financial_hub_screen.dart"
Cohesion: 0.17
Nodes (8): build, createState, dispose, FinancialHubScreen, _FinancialHubScreenState, initialTabIndex, initState, _tabController

### Community 137 - "booking_rc_261030_0001_late_penalty_bug_fix_test.dart"
Cohesion: 0.12
Nodes (15): bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchCurrentShift, fetchPaymentMethods (+7 more)

### Community 138 - "quick_open_shift_modal.dart"
Cohesion: 0.12
Nodes (16): branchId, build, createState, dispose, _errorMessage, _floatController, _focusNode, _formatInput (+8 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.22
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "staff_resignation_sheet.dart"
Cohesion: 0.14
Nodes (11): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+3 more)

### Community 141 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.11
Nodes (16): authStateOwner, build, businessStateOwner, fetchPaymentMethods, fetchPaymentSettings, hasPayload, _initial, isDynamicQris (+8 more)

### Community 142 - "package:rentcore_mobile/features/cashier/providers/cashier_provider.dart"
Cohesion: 0.07
Nodes (18): executePayment, _FakeCashierRepoForSelection, fetchPaymentMethods, lastPaymentMethodCode, lastPaymentMethodId, lastPaymentMethodName, main, main (+10 more)

### Community 143 - "customer_directory_screen.dart"
Cohesion: 0.12
Nodes (18): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+10 more)

### Community 144 - "rental_duration_multiplier_test.dart"
Cohesion: 0.14
Nodes (13): adjustDuration, build, _FakeDurationMultiplierBookingRepository, fetchBookings, initialState, lastAdditionalFee, lastBookingId, lastBookingItemId (+5 more)

### Community 145 - "package:flutter_secure_storage/flutter_secure_storage.dart"
Cohesion: 0.18
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 146 - "inventory_unit_deduplication_test.dart"
Cohesion: 0.14
Nodes (13): build, _DuplicateMockAssetRepository, duplicateUnitsList, fetchAssets, fetchAssetsPaginated, fetchCategories, fetchModels, fetchProducts (+5 more)

### Community 147 - "voucher_screen.dart"
Cohesion: 0.10
Nodes (13): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher, createState, _debounceTimer (+5 more)

### Community 148 - "feature_walkthrough_screen.dart"
Cohesion: 0.11
Nodes (17): build, _buildBottomControls, _buildMetricTile, _buildSlide1Preview, _buildSlide2Preview, _buildSlide3Preview, _buildSlide4Preview, _buildSlideContainer (+9 more)

### Community 149 - "add_customer_sheet.dart"
Cohesion: 0.14
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 150 - "cashier_shift_and_rental_queue_refactor_test.dart"
Cohesion: 0.12
Nodes (14): activeShiftData, bookings, build, closedShiftResult, closeShift, _FakeBusinessNotifier, fetchBookingDetail, fetchBookings (+6 more)

### Community 151 - "pos_all_branches_filter_test.dart"
Cohesion: 0.10
Nodes (17): bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, main (+9 more)

### Community 152 - "rental_addons_and_policies_test.dart"
Cohesion: 0.15
Nodes (11): OrganizationNotifier, OrganizationState, _MockOrganizationNotifier, build, loadOrganization, main, _mockInitialState, _MockRentalRulesOrgNotifier (+3 more)

### Community 153 - "currency_formatter.dart"
Cohesion: 0.29
Nodes (4): CurrencyFormatter, format, _formatter, parse

### Community 154 - "device_protection_quarantine_return_test.dart"
Cohesion: 0.08
Nodes (23): androidBooking, appleBooking, build, buildScreen, _FakeBookingRepo, _FakeCashierRepo, fetchCurrentShift, fetchPaymentMethods (+15 more)

### Community 155 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (38): build, _FakeCashierRepo, fetchClosingSummary, fetchCurrentShift, main, _TestAuthNotifier, _TestBusinessNotifier, build (+30 more)

### Community 156 - "printerProvider"
Cohesion: 0.07
Nodes (30): _printBookingReceipt, ExchangeHistorySheet, _printExchangeReceipt, printBookingReceipt, RentalQueueActions, _showReturnSuccessDialog, _buildActiveShiftTab, build (+22 more)

### Community 157 - "navigation_laporan_and_queue_actions_test.dart"
Cohesion: 0.04
Nodes (55): createState, customer, _getInitials, initState, show, DashboardRepository, _FakeDashboardRepository, build (+47 more)

### Community 158 - "Win32Window"
Cohesion: 0.15
Nodes (7): Point, x, y, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 159 - "int?"
Cohesion: 0.06
Nodes (31): PosFilterBranchIdNotifier, AssetCategoryFilterNotifier, attempts, main, voidTransaction, build, fetchBookingDetail, fetchBookingsForCashier (+23 more)

### Community 160 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (22): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline, fakeAuthRepo, fetchBusinesses (+14 more)

### Community 161 - "pos_all_branches_filter_test.dart"
Cohesion: 0.15
Nodes (12): build, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastBookingsAllBranches, lastBookingsBranchId, lastClosingAllBranches (+4 more)

### Community 162 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 163 - "BookingRepository"
Cohesion: 0.03
Nodes (66): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState (+58 more)

### Community 164 - "CashierRepository"
Cohesion: 0.10
Nodes (16): CashierRepository, _FakeCashierRepoForLatePenalty, _FakeCashierRepository, _FakeCashierShiftRepo, _FakeStreamlineCashierRepository, _FakeCashierRepoForDynamicQris, _FakeCashierRepositoryForReturn, _FakeFinancialRepo (+8 more)

### Community 165 - "../../auth/providers/business_provider.dart"
Cohesion: 0.20
Nodes (7): _buildEmbeddedRentalQueue, bizState, dashboardQueueBookingsProvider, dashboardRepositoryProvider, dashboardSummaryProvider, fetchKpi, repo

### Community 166 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.05
Nodes (36): buildTestableWidget, main, build, dismissedMap, _initial, isChecklistDismissed, main, setChecklistDismissed (+28 more)

### Community 167 - "organizationProvider"
Cohesion: 0.15
Nodes (13): build, _buildBranchesTab, _buildErrorState, _buildMembersTab, _confirmApproveResignation, _confirmDeactivateMember, initState, _saveRules (+5 more)

### Community 168 - "printer_settings_screen.dart"
Cohesion: 0.17
Nodes (7): build, _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, initState

### Community 169 - "../../core/utils/currency_formatter.dart"
Cohesion: 0.17
Nodes (8): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, _printExchangeReceipt, show

### Community 170 - "notification_center_test.dart"
Cohesion: 0.18
Nodes (6): build, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead, markAsRead

### Community 171 - "customer_repository.dart"
Cohesion: 0.20
Nodes (7): createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument

### Community 173 - "qris_service.dart"
Cohesion: 0.40
Nodes (4): calculateCrc16, generateDynamicQris, isValidQrisPayload, QrisService

### Community 174 - "progressive_checklist_banner.dart"
Cohesion: 0.22
Nodes (3): _buildChecklistItem, onOpenInventory, totalAssetCount

### Community 175 - "date_formatter.dart"
Cohesion: 0.29
Nodes (6): DateFormatter, formatDayMonth, formatFull, formatRelative, formatShort, formatTime

### Community 176 - "payment_repository.dart"
Cohesion: 0.20
Nodes (4): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods

### Community 177 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 178 - "_MainShellScreenState"
Cohesion: 0.67
Nodes (3): networkStatusProvider, MainShellScreen, _MainShellScreenState

### Community 180 - "SingleTickerProviderStateMixin"
Cohesion: 0.23
Nodes (10): AnimatedSuccessCheckmark, _AnimatedSuccessCheckmarkState, SkeletonPulseWrapper, _SkeletonPulseWrapperState, _ModelPickerBottomSheet, _ModelPickerBottomSheetState, ExpandableInventoryFab, ExpandableInventoryFabState (+2 more)

### Community 183 - "direct_rental_streamline_and_multiplier_test.dart"
Cohesion: 0.12
Nodes (15): build, buildScreen, createRental, createRentalCalls, fakeBookingRepo, fakeCashierRepo, fetchCurrentShift, fetchPaymentMethods (+7 more)

### Community 185 - "BusinessNotifier"
Cohesion: 0.05
Nodes (42): AuthState, BusinessNotifier, BusinessState, _TestBusinessNotifier, _TestBusinessNotifier, build, buildCatalogScreen, _FakeAssetRepository (+34 more)

### Community 186 - "NotificationNotifier"
Cohesion: 0.40
Nodes (5): NotificationNotifier, NotificationState, _TrackingNotificationNotifier, _FakeNotificationNotifier, _FakeNotificationNotifier

### Community 187 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 188 - "transfer_provider.dart"
Cohesion: 0.11
Nodes (20): build, _InitiateTransferForm, _InitiateTransferFormState, _TransfersScreenState, branchRecipientsProvider, build, destinationAffiliatesProvider, direction (+12 more)

### Community 189 - "businessProvider"
Cohesion: 0.09
Nodes (37): authProvider, authRepositoryProvider, checkCurrentSession, login, businessProvider, BookingFilterNotifier, BookingSearchQueryNotifier, shiftScheduleProvider (+29 more)

### Community 194 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.06
Nodes (23): rootNavigatorKey, build, createTestWidget, fetchAssets, fetchCategories, fetchProducts, main, _MockAssetRepo (+15 more)

## Knowledge Gaps
- **2494 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+2489 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2734 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **52 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `.MessageHandler`, `.Create`, `Windows Native Desktop Runner`, `Size`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _2494 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `BookingRepository` connect `BookingRepository` to `transfers_screen.dart`, `booking_provider.dart`, `late_return_penalty_return_workflow_test.dart`, `Booking Management System`, `cashier_and_header_standardization_test.dart`, `payment_repository.dart`, `rental_duration_multiplier_test.dart`, `device_protection_quarantine_return_test.dart`, `package:flutter_test/flutter_test.dart`, `navigation_laporan_and_queue_actions_test.dart`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.07881773399014778 - nodes in this community are weakly interconnected._
- **Why does `RegisterPlugins()` connect `Windows Native Desktop Runner` to `Win32Window`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.024390243902439025 - nodes in this community are weakly interconnected._