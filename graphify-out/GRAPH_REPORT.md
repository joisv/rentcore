# Graph Report - rentcore  (2026-11-14)

## Corpus Check
- 213 files · ~220,579 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 3616 nodes · 5885 edges · 187 communities (136 shown, 51 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e03da858`
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
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- rental_queue_actions.dart
- businessProvider
- skeleton_loading.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- cashier_screen.dart
- payment_page.dart
- inventory_empty_state_test.dart
- Printer Bluetooth Driver Module
- thermal_receipt_preview_dialog.dart
- Home Dashboard & Analytics
- shift_schedule_screen.dart
- Rental Return Processing
- App Colors Module
- cashier_provider.dart
- printerProvider
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- home_queue_card_layout_test.dart
- dock_aware_scaffold.dart
- generate_onboarding_figcraft.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- main.dart
- _PaymentPageState
- voucher_management_test.dart
- revenue_report_screen.dart
- Map
- notification_item.dart
- Booking Management System
- Authentication & User Session
- rentcore_app_bar.dart
- status_badge.dart
- Windows Native Desktop Runner
- authProvider
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
- add_customer_sheet.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- customer_repository.dart
- Map
- animated_success_checkmark.dart
- add_branch_expense_modal.dart
- customer_provider.dart
- int?
- store_settings_screen.dart
- revenue_report_screen.dart
- feature_walkthrough_screen.dart
- Cashier POS & Register
- booking_rc_261030_0001_late_penalty_bug_fix_test.dart
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
- inventory_live_payload_test.dart
- onboarding_provider.dart
- network_status_provider.dart
- physical_units_empty_state_guided_progression_test.dart
- ../../auth/providers/business_provider.dart
- notification_center_test.dart
- notification_center_screen.dart
- expandable_inventory_fab_test.dart
- financial_hub_screen.dart
- voucher_screen.dart
- quick_open_shift_modal.dart
- package:shared_preferences/shared_preferences.dart
- staff_resignation_sheet.dart
- dynamic_qris_end_to_end_test.dart
- payment_page_shift_activation_test.dart
- customer_directory_screen.dart
- catalog_card_refactor_test.dart
- secure_token_storage.dart
- bookings_queue_overdue_test.dart
- exchange_history_sheet.dart
- catalog_card_polish_test.dart
- ewallet_and_bank_transfer_selection_test.dart
- rental_duration_multiplier_test.dart
- branch_aware_booking_test.dart
- organization_test.dart
- currency_formatter.dart
- device_protection_quarantine_return_test.dart
- paginated_result.dart
- cashierRepositoryProvider
- home_dashboard_metrics_grid_test.dart
- .MessageHandler
- package:rentcore_mobile/features/cashier/providers/cashier_provider.dart
- OrganizationNotifier
- booking_provider.dart
- AuthNotifier
- BookingRepository
- assetRepositoryProvider
- AssetRepository
- customer_detail_sheet.dart
- customer_directory_to_booking_prefill_test.dart
- payment_success_animation_test.dart
- branch_revenue_and_dashboard_test.dart
- List
- app_theme.dart
- inventory_unit_deduplication_test.dart
- qris_service.dart
- rental_addons_and_policies_test.dart
- Point
- CustomerRepository
- SkeletonPulseScope
- _BusinessOnboardingDialogState
- SingleTickerProviderStateMixin
- customer_directory_and_governance_test.dart
- progressive_checklist_banner.dart
- cash_suggestion_helper.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- Win32Window
- payment_methods_dynamic_visibility_and_qris_upload_test.dart
- progressive_checklist_banner_test.dart

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 89 edges
2. `BusinessNotifier` - 54 edges
3. `authProvider` - 46 edges
4. `AuthNotifier` - 38 edges
5. `BusinessState` - 35 edges
6. `BookingRepository` - 28 edges
7. `organizationProvider` - 28 edges
8. `printerProvider` - 28 edges
9. `CashierRepository` - 27 edges
10. `cashierRepositoryProvider` - 22 edges

## Surprising Connections (you probably didn't know these)
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/cashier_shift_inline_buttons_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockGoogleAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockPasswordAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_dashboard_metrics_grid_test.dart → lib/features/auth/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (187 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.05
Nodes (47): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+39 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.02
Nodes (80): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+72 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.02
Nodes (77): _addonSubtotal, _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildAddonsSelectionSection, _buildBookingPaymentContext, _buildNavigationButtonRow (+69 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.05
Nodes (18): Cocoa, file_selector_macos, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate (+10 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.05
Nodes (53): _AddBranchBottomSheet, _AddBranchBottomSheetState, _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard (+45 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.04
Nodes (45): additionalHours, addonSubtotal, amountPaid, assetCode, booking, bookingCode, bookingId, branchId (+37 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (33): _accessoriesController, _addPresetRate, _addRateRow, _brandController, build, _buildPresetChip, _colorController, createState (+25 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (26): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+18 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (28): PrinterConnectionStatus, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith, disconnect (+20 more)

### Community 12 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.07
Nodes (25): build, fetchClosingSummary, fetchCurrentShift, main, _TestAuthNotifier, _TestBusinessNotifier, _Biz, build (+17 more)

### Community 13 - "rental_queue_actions.dart"
Cohesion: 0.07
Nodes (26): _AdjustmentTarget, _buildDurationMultiplierRow, _computeMaxDurationMultiplier, currentDurationHours, currentPrice, _DurationOption, _getDurationOptionsForTarget, getItemCategoryIcon (+18 more)

### Community 14 - "businessProvider"
Cohesion: 0.06
Nodes (54): networkStatusProvider, checkCurrentSession, login, businessProvider, BookingsScreen, _BookingsScreenState, DirectRentalScreen, _DirectRentalScreenState (+46 more)

### Community 15 - "skeleton_loading.dart"
Cohesion: 0.06
Nodes (39): ActiveShiftSkeleton, BookingCardSkeleton, borderRadius, build, _buildMetricCard, CatalogTabSkeleton, child, circle (+31 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (28): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+20 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.03
Nodes (60): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildAvatarFallback, _buildBranchBar, _buildCatalogView, _buildChip (+52 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.08
Nodes (25): build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading, isSubmitting (+17 more)

### Community 19 - "cashier_screen.dart"
Cohesion: 0.07
Nodes (25): build, _buildCompactFilterChip, _buildCustomShiftHistoryDateFilterChip, _buildDetailRow, _buildShiftClosingActionButtons, _buildShiftHistoryCard, _buildShiftHistoryDateFilterChips, _buildShiftHistoryTab (+17 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.03
Nodes (57): _actionsTrack, _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile (+49 more)

### Community 21 - "inventory_empty_state_test.dart"
Cohesion: 0.13
Nodes (14): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+6 more)

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.14
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.06
Nodes (30): _buildBusinessErrorCard, _buildDailyOperationsGrid, _buildDashboardContent, _buildErrorCard, _buildOnboardingBanner, _buildOperationCard, _buildOverdueAlertCard, _buildQueueCard (+22 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (26): shiftScheduleProvider, _branchClosingTime, _branchOpeningTime, build, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard (+18 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.07
Nodes (26): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _category, _checklistDefs (+18 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "cashier_provider.dart"
Cohesion: 0.10
Nodes (19): activeShiftProvider, bizState, build, cashierBookingsProvider, effectiveBranchId, endDate, fetchCurrentShift, isConsolidated (+11 more)

### Community 29 - "printerProvider"
Cohesion: 0.08
Nodes (23): _printExchangeReceipt, _printExchangeReceipt, RentalQueueActions, _showReturnSuccessDialog, _printPaymentReceipt, build, _buildChoiceChip, _buildConnectionStatusCard (+15 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.04
Nodes (50): activeShift, branchId, build, _buildCloseShiftMiddleContent, _buildCoinRow, _buildDenominationRow, _buildDirectTotalInput, _buildHeader (+42 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (30): branches, build, businessId, businessName, cancelResignation, copyWith, createBranch, error (+22 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.08
Nodes (23): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, build, businesses, businessProfileProvider, copyWith (+15 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.10
Nodes (18): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+10 more)

### Community 34 - "home_queue_card_layout_test.dart"
Cohesion: 0.10
Nodes (16): build, fetchBookingsForCashier, fetchBranchExpenses, fetchClosingSummary, fetchPaymentMethods, _MockCashierBizNotifier, _MockCashierRepository, bookings (+8 more)

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
Nodes (24): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildCurrentStepBody, _buildStep1Identity, _buildStep2Branch (+16 more)

### Community 39 - "main.dart"
Cohesion: 0.10
Nodes (5): createState, _currentTabIndex, initializeDateFormatting, main, null

### Community 40 - "_PaymentPageState"
Cohesion: 0.29
Nodes (11): currentShiftByBranchProvider, currentShiftProvider, paymentSettingsProvider, paymentRepositoryProvider, build, _executePaymentProcess, PaymentPage, _PaymentPageState (+3 more)

### Community 41 - "voucher_management_test.dart"
Cohesion: 0.05
Nodes (39): VoucherRepository, currentUserEmail, _FakeVoucherRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+31 more)

### Community 42 - "revenue_report_screen.dart"
Cohesion: 0.12
Nodes (16): build, _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen (+8 more)

### Community 43 - "Map"
Cohesion: 0.03
Nodes (74): AuthRepository, _FakeAuthRepository, fakeAuthRepo, _FakeAuthRepository, fetchBusinesses, main, setActiveContext, storedContext (+66 more)

### Community 44 - "notification_item.dart"
Cohesion: 0.11
Nodes (16): actionPayload, actionRoute, affiliate, affiliateId, body, businessId, category, copyWith (+8 more)

### Community 45 - "Booking Management System"
Cohesion: 0.15
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
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "authProvider"
Cohesion: 0.05
Nodes (41): build, createState, dispose, _emailController, _getEffectiveServerClientId, _handleGoogleSignIn, _login, LoginScreen (+33 more)

### Community 51 - "business_setup_wizard_screen.dart"
Cohesion: 0.06
Nodes (33): authRepositoryProvider, _boundUserId, _branchStructure, _buildBottomActionBar, _buildBranchOptionCard, _buildStep1BusinessName, _buildStep2BranchStructure, _buildStep3CategoryPersonalization (+25 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.07
Nodes (15): build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, logout, _repository (+7 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.08
Nodes (21): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, onTabSelected, build, _buildActionKey (+13 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.07
Nodes (25): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _hasValidQrisPayload, _isDynamicQrisEnabled (+17 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.07
Nodes (21): 7, createState, _currentBookingPage, _debounceTimer, didUpdateWidget, dispose, endAt, _extraBookings (+13 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.04
Nodes (51): _onBookingsScroll, booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader (+43 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

### Community 61 - "add_customer_sheet.dart"
Cohesion: 0.15
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 62 - "Asset Transfer Workflow"
Cohesion: 0.18
Nodes (10): approveTransfer, cancelTransfer, _client, createTransfer, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, receiveTransfer (+2 more)

### Community 63 - "Flutter Web Shell Platform"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 64 - "Core API & Network Client"
Cohesion: 0.18
Nodes (6): _baseUrl, currentBaseUrl, dio, init, _instance, updateBaseUrl

### Community 65 - "Voucher & Discount Rules"
Cohesion: 0.20
Nodes (9): _client, createVoucher, deleteVoucher, fetchPrintSlip, fetchVouchers, getVoucher, toggleVoucherStatus, updateVoucher (+1 more)

### Community 66 - "customer_repository.dart"
Cohesion: 0.15
Nodes (10): ApiClient, createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument (+2 more)

### Community 67 - "Map"
Cohesion: 0.12
Nodes (15): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+7 more)

### Community 68 - "animated_success_checkmark.dart"
Cohesion: 0.09
Nodes (19): build, checkColor, _CheckmarkStrokePainter, _checkProgress, circleColor, _circleScale, color, _controller (+11 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (17): AddBranchExpenseModal, _amountController, branchId, build, _categories, createState, dispose, _errorMessage (+9 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.07
Nodes (28): build, copyWith, createCustomer, currentPage, CustomerNotifier, customerRepositoryProvider, customers, customerSearchResultsProvider (+20 more)

### Community 71 - "int?"
Cohesion: 0.07
Nodes (27): AssetCategoryFilterNotifier, build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState (+19 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (9): build, _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen (+1 more)

### Community 73 - "revenue_report_screen.dart"
Cohesion: 0.13
Nodes (12): _buildBranchContributionBreakdown, _buildBranchSelectorHeader, _buildCompactFilterChip, _buildHeroRevenueCard, _buildIncomeTypeBreakdown, _buildPaymentMethodBreakdown, _buildRecentTransactionsAudit, _buildRevenueContent (+4 more)

### Community 74 - "feature_walkthrough_screen.dart"
Cohesion: 0.12
Nodes (14): build, _buildBottomControls, _buildMetricTile, _buildSlide1Preview, _buildSlide2Preview, _buildSlide3Preview, _buildSlide4Preview, _buildSlideContainer (+6 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.10
Nodes (19): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+11 more)

### Community 77 - "booking_rc_261030_0001_late_penalty_bug_fix_test.dart"
Cohesion: 0.13
Nodes (14): bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, _initialState (+6 more)

### Community 79 - "notification_provider.dart"
Cohesion: 0.14
Nodes (12): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+4 more)

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "asset_provider.dart"
Cohesion: 0.07
Nodes (28): BookingFilterNotifier, BookingSearchQueryNotifier, PosFilterBranchIdNotifier, CustomerSearchQueryNotifier, AssetSearchQueryNotifier, AssetStatusFilterNotifier, bizState, build (+20 more)

### Community 128 - "inventory_live_payload_test.dart"
Cohesion: 0.13
Nodes (14): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+6 more)

### Community 129 - "onboarding_provider.dart"
Cohesion: 0.11
Nodes (16): build, checkStatus, completeWalkthrough, copyWith, dismissChecklist, hasCompletedWalkthrough, isChecklistDismissed, isLoading (+8 more)

### Community 130 - "network_status_provider.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 131 - "physical_units_empty_state_guided_progression_test.dart"
Cohesion: 0.13
Nodes (14): assets, baseBusinessState, build, categories, createTestWidget, fetchAssets, fetchCategories, fetchModels (+6 more)

### Community 132 - "../../auth/providers/business_provider.dart"
Cohesion: 0.15
Nodes (11): build, _buildEmbeddedRentalQueue, HomeScreen, _HomeScreenState, bizState, dashboardKpiProvider, dashboardQueueBookingsProvider, dashboardRepositoryProvider (+3 more)

### Community 133 - "notification_center_test.dart"
Cohesion: 0.14
Nodes (9): NotificationNotifier, NotificationState, build, _FakeNotificationNotifier, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead (+1 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (16): _buildHeader, _handleRefresh, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState (+8 more)

### Community 135 - "expandable_inventory_fab_test.dart"
Cohesion: 0.15
Nodes (9): build, createTestWidget, fetchAssets, fetchCategories, fetchProducts, main, _MockAssetRepo, _MockBizNotifier (+1 more)

### Community 136 - "financial_hub_screen.dart"
Cohesion: 0.20
Nodes (6): build, createState, dispose, initialTabIndex, initState, _tabController

### Community 137 - "voucher_screen.dart"
Cohesion: 0.10
Nodes (13): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher, createState, _debounceTimer (+5 more)

### Community 138 - "quick_open_shift_modal.dart"
Cohesion: 0.12
Nodes (17): branchId, build, createState, dispose, _errorMessage, _floatController, _focusNode, _formatInput (+9 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "staff_resignation_sheet.dart"
Cohesion: 0.13
Nodes (13): build, businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState (+5 more)

### Community 141 - "dynamic_qris_end_to_end_test.dart"
Cohesion: 0.11
Nodes (15): authStateOwner, build, businessStateOwner, fetchPaymentMethods, fetchPaymentSettings, hasPayload, _initial, isDynamicQris (+7 more)

### Community 142 - "payment_page_shift_activation_test.dart"
Cohesion: 0.15
Nodes (10): defaultPaymentMethods, FakeCashierRepoForShiftTest, fetchCurrentShift, hasActiveShift, main, openedBranchId, openedFloat, openShift (+2 more)

### Community 143 - "customer_directory_screen.dart"
Cohesion: 0.12
Nodes (17): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+9 more)

### Community 144 - "catalog_card_refactor_test.dart"
Cohesion: 0.15
Nodes (11): build, buildCatalogScreen, _FakeAssetRepository, fetchCategories, fetchModels, fetchProducts, _initial, main (+3 more)

### Community 145 - "secure_token_storage.dart"
Cohesion: 0.18
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 146 - "bookings_queue_overdue_test.dart"
Cohesion: 0.15
Nodes (12): build, changeBranch, _FakeBookingRepository, fetchBookings, initialState, lastAllBranches, lastBranchId, lastSearch (+4 more)

### Community 147 - "exchange_history_sheet.dart"
Cohesion: 0.17
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 148 - "catalog_card_polish_test.dart"
Cohesion: 0.17
Nodes (10): build, buildTestApp, fetchAssets, fetchCategories, fetchProducts, _initial, main, products (+2 more)

### Community 149 - "ewallet_and_bank_transfer_selection_test.dart"
Cohesion: 0.20
Nodes (7): executePayment, _FakeCashierRepoForSelection, fetchPaymentMethods, lastPaymentMethodCode, lastPaymentMethodId, lastPaymentMethodName, main

### Community 150 - "rental_duration_multiplier_test.dart"
Cohesion: 0.06
Nodes (23): bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, main (+15 more)

### Community 151 - "branch_aware_booking_test.dart"
Cohesion: 0.17
Nodes (11): build, changeBranch, _FakeAssetRepository, _FakeBookingRepository, fetchAssets, fetchReadyAssets, initialState, main (+3 more)

### Community 152 - "organization_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 153 - "currency_formatter.dart"
Cohesion: 0.15
Nodes (9): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+1 more)

### Community 154 - "device_protection_quarantine_return_test.dart"
Cohesion: 0.04
Nodes (44): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, _FakeBookingRepoForQueue, androidBooking, appleBooking, buildScreen, _FakeBookingRepo (+36 more)

### Community 155 - "paginated_result.dart"
Cohesion: 0.18
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 156 - "cashierRepositoryProvider"
Cohesion: 0.18
Nodes (11): _printBookingReceipt, printBookingReceipt, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, _submitCloseShift, _submitOpenShift, _submitOpenShift (+3 more)

### Community 157 - "home_dashboard_metrics_grid_test.dart"
Cohesion: 0.04
Nodes (48): DashboardRepository, _FakeDashboardRepository, _FakeDashboardRepository, build, _initial, main, _StaticAuthNotifier, _StaticBusinessNotifier (+40 more)

### Community 159 - "package:rentcore_mobile/features/cashier/providers/cashier_provider.dart"
Cohesion: 0.03
Nodes (66): CashierRepository, _FakeCashierRepoForLatePenalty, activeShiftData, bookings, build, closedShiftResult, closeShift, _FakeCashierShiftRepo (+58 more)

### Community 160 - "OrganizationNotifier"
Cohesion: 0.33
Nodes (6): OrganizationNotifier, OrganizationState, _MockOrganizationNotifier, _MockRentalRulesOrgNotifier, _MockOrganizationNotifier, MockOrganizationNotifier

### Community 161 - "booking_provider.dart"
Cohesion: 0.10
Nodes (21): build, _buildFilterChip, _clearSearch, initState, _onSearchChanged, build, bizState, bookingFilterStatusProvider (+13 more)

### Community 162 - "AuthNotifier"
Cohesion: 0.18
Nodes (21): AuthNotifier, _invalidateTenantAndUserData, customerSearchQueryProvider, build, initState, _InventoryScreenState, _onUnitsScroll, build (+13 more)

### Community 163 - "BookingRepository"
Cohesion: 0.04
Nodes (50): rootNavigatorKey, build, _FakeSearchBookingRepository, fetchBookings, initialState, lastBranchId, lastSearch, lastStatus (+42 more)

### Community 164 - "assetRepositoryProvider"
Cohesion: 0.25
Nodes (8): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, allCatalogModelsProvider, assetRepositoryProvider

### Community 165 - "AssetRepository"
Cohesion: 0.18
Nodes (11): AssetRepository, _FakeAssetRepository, _FakeAssetRepositoryForPolish, _FakeAssetRepo, _TrackingAssetRepository, _ConfigurableAssetRepository, _LivePayloadAssetRepository, _DuplicateMockAssetRepository (+3 more)

### Community 166 - "customer_detail_sheet.dart"
Cohesion: 0.18
Nodes (9): build, createState, customer, CustomerDetailSheet, _CustomerDetailSheetState, _getInitials, _handleBlacklistToggle, initState (+1 more)

### Community 167 - "customer_directory_to_booking_prefill_test.dart"
Cohesion: 0.09
Nodes (19): PaymentRepository, PaymentContext, PaymentResult, executePayment, lastContext, mockCategories, mockPaymentMethods, MockPaymentRepository (+11 more)

### Community 168 - "payment_success_animation_test.dart"
Cohesion: 0.20
Nodes (6): buildPaymentSuccessWidget, _FakeCashierRepoForAnimationTest, fetchCurrentShift, main, qrisResult, testContext

### Community 169 - "branch_revenue_and_dashboard_test.dart"
Cohesion: 0.14
Nodes (13): build, changeBranch, _FakeCashierRepository, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main (+5 more)

### Community 170 - "List"
Cohesion: 0.20
Nodes (7): build, _categories, createCategory, fetchCategories, main, _MockCategoryAssetRepo, _MockCategoryBizNotifier

### Community 172 - "inventory_unit_deduplication_test.dart"
Cohesion: 0.15
Nodes (12): build, duplicateUnitsList, fetchAssets, fetchAssetsPaginated, fetchCategories, fetchModels, fetchProducts, _initial (+4 more)

### Community 173 - "qris_service.dart"
Cohesion: 0.40
Nodes (4): calculateCrc16, generateDynamicQris, isValidQrisPayload, QrisService

### Community 174 - "rental_addons_and_policies_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 175 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 176 - "CustomerRepository"
Cohesion: 0.67
Nodes (3): CustomerRepository, MockCustomerRepository, _MockCustomerRepo

### Community 180 - "SingleTickerProviderStateMixin"
Cohesion: 0.23
Nodes (10): AnimatedSuccessCheckmark, _AnimatedSuccessCheckmarkState, SkeletonPulseWrapper, _SkeletonPulseWrapperState, FinancialHubScreen, _FinancialHubScreenState, ExpandableInventoryFab, ExpandableInventoryFabState (+2 more)

### Community 181 - "customer_directory_and_governance_test.dart"
Cohesion: 0.18
Nodes (5): createCustomer, dummyCustomers, fetchCustomersPaginated, main, toggleBlacklist

### Community 183 - "progressive_checklist_banner.dart"
Cohesion: 0.20
Nodes (3): _buildChecklistItem, onOpenInventory, totalAssetCount

### Community 184 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 185 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.04
Nodes (48): AuthState, BusinessNotifier, BusinessState, _FakeBusinessNotifier, build, fakeDashboardData, lastCurrentPassword, lastNewPassword (+40 more)

### Community 187 - "Win32Window"
Cohesion: 0.16
Nodes (7): Size, height, width, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 189 - "payment_methods_dynamic_visibility_and_qris_upload_test.dart"
Cohesion: 0.10
Nodes (10): defaultPaymentMethods, executePayment, lastContext, lastMethodCode, main, testContext, FakeCashierRepoForPolishTest, fetchCurrentShift (+2 more)

### Community 190 - "progressive_checklist_banner_test.dart"
Cohesion: 0.09
Nodes (19): ReceiptCustomizationSettings, PrinterNotifier, PrinterState, thermalPrinterServiceProvider, buildTestableWidget, main, build, dismissedMap (+11 more)

## Knowledge Gaps
- **2349 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+2344 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2590 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Point`, `.Create`, `Windows Native Desktop Runner`, `.MessageHandler`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _2349 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `Windows Native Desktop Runner` to `Windows Native Desktop Runner`, `Win32Window`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05411764705882353 - nodes in this community are weakly interconnected._
- **Why does `CashierRepository` connect `package:rentcore_mobile/features/cashier/providers/cashier_provider.dart` to `home_queue_card_layout_test.dart`, `int?`, `payment_success_animation_test.dart`, `branch_revenue_and_dashboard_test.dart`, `Cashier POS & Register`, `payment_page_shift_activation_test.dart`, `ewallet_and_bank_transfer_selection_test.dart`, `rental_duration_multiplier_test.dart`, `auth_provider.dart`, `package:rentcore_mobile/features/auth/providers/business_provider.dart`, `device_protection_quarantine_return_test.dart`, `cashier_provider.dart`, `payment_methods_dynamic_visibility_and_qris_upload_test.dart`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.024390243902439025 - nodes in this community are weakly interconnected._