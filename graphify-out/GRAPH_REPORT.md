# Graph Report - rentcore  (2026-11-15)

## Corpus Check
- 217 files · ~225,980 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 3724 nodes · 6077 edges · 200 communities (149 shown, 51 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `61721d5f`
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
- List
- rental_queue_actions.dart
- catalog_card_refactor_test.dart
- skeleton_loading.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- cashier_screen.dart
- payment_page.dart
- catalog_card_polish_test.dart
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
- inventory_live_payload_test.dart
- dock_aware_scaffold.dart
- generate_onboarding_figcraft.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- main.dart
- login_screen.dart
- voucher_management_test.dart
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
- customer_repository.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- ConsumerState
- Map
- animated_success_checkmark.dart
- add_branch_expense_modal.dart
- customer_provider.dart
- late_return_penalty_pos_test.dart
- store_settings_screen.dart
- late_return_penalty_return_workflow_test.dart
- inventory_empty_state_test.dart
- Cashier POS & Register
- package:rentcore_mobile/features/bookings/providers/booking_provider.dart
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
- authProvider
- onboarding_provider.dart
- ../../core/constants/app_colors.dart
- app_text_styles.dart
- booking_provider.dart
- notification_and_branch_switcher_simplification_test.dart
- notification_center_screen.dart
- onboarding_routing_gate_test.dart
- financial_hub_screen.dart
- AuthNotifier
- quick_open_shift_modal.dart
- package:shared_preferences/shared_preferences.dart
- staff_resignation_sheet.dart
- package:flutter_test/flutter_test.dart
- package:flutter/material.dart
- customer_directory_screen.dart
- physical_units_empty_state_guided_progression_test.dart
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
- cashier_and_header_standardization_test.dart
- printerProvider
- navigation_laporan_and_queue_actions_test.dart
- win32_window.cpp
- int?
- network_status_provider.dart
- booking_provider.dart
- staff_resignation_test.dart
- BookingRepository
- home_dashboard_metrics_grid_test.dart
- ../../auth/providers/business_provider.dart
- provider_late_initialization_and_store_profile_test.dart
- rental_duration_multiplier_test.dart
- AuthNotifier
- auth_lifecycle_relogin_test.dart
- notification_center_test.dart
- customer_directory_and_governance_test.dart
- logout_and_inventory_detail_test.dart
- qris_service.dart
- progressive_checklist_banner.dart
- payment_repository.dart
- cash_suggestion_helper.dart
- AssetRepository
- exchange_history_sheet.dart
- SingleTickerProviderStateMixin
- string
- unit_test.dart
- direct_rental_streamline_and_multiplier_test.dart
- currency_formatter.dart
- BusinessNotifier
- NotificationNotifier
- Size
- transfer_provider.dart
- businessProvider
- progressive_checklist_banner_test.dart
- CustomerRepository
- CustomerNotifier
- SkeletonPulseScope
- package:flutter_test/flutter_test.dart
- _CashDrawerShiftModalState
- assetRepositoryProvider
- organization_test.dart
- OrganizationNotifier
- _DirectRentalScreenState

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 89 edges
2. `BusinessNotifier` - 57 edges
3. `authProvider` - 46 edges
4. `AuthNotifier` - 40 edges
5. `BusinessState` - 40 edges
6. `BookingRepository` - 31 edges
7. `CashierRepository` - 28 edges
8. `organizationProvider` - 28 edges
9. `printerProvider` - 28 edges
10. `cashierRepositoryProvider` - 22 edges

## Surprising Connections (you probably didn't know these)
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/cashier_shift_inline_buttons_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_dashboard_metrics_grid_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_header_and_unread_badge_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/payment_method_settings_screen_test.dart → lib/features/auth/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (200 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.09
Nodes (26): _bookingRepo, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer, createState, dispose, _InitiateTransferForm (+18 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.02
Nodes (80): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+72 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.02
Nodes (89): _addonSubtotal, _addressController, _assetValidationError, _basePrice, _buildAddonsSelectionSection, _buildDurationMultiplierRow, _buildNavigationButtonRow, _buildStep1UnitAndDuration (+81 more)

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
Nodes (34): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, _buildPresetChip, _colorController (+26 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (29): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+21 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.06
Nodes (33): PrinterConnectionStatus, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith, disconnect (+25 more)

### Community 12 - "List"
Cohesion: 0.05
Nodes (32): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+24 more)

### Community 13 - "rental_queue_actions.dart"
Cohesion: 0.06
Nodes (26): _AdjustmentTarget, _buildDurationMultiplierRow, _computeMaxDurationMultiplier, currentDurationHours, currentPrice, _DurationOption, _getDurationOptionsForTarget, getItemCategoryIcon (+18 more)

### Community 14 - "catalog_card_refactor_test.dart"
Cohesion: 0.11
Nodes (13): build, buildCatalogScreen, _FakeAssetRepository, fetchCategories, fetchModels, fetchProducts, _initial, main (+5 more)

### Community 15 - "skeleton_loading.dart"
Cohesion: 0.06
Nodes (39): ActiveShiftSkeleton, BookingCardSkeleton, borderRadius, build, _buildMetricCard, CatalogTabSkeleton, child, circle (+31 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.06
Nodes (30): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+22 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.03
Nodes (60): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildAvatarFallback, _buildBranchBar, _buildCatalogView, _buildChip (+52 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.08
Nodes (25): build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading, isSubmitting (+17 more)

### Community 19 - "cashier_screen.dart"
Cohesion: 0.07
Nodes (28): build, _buildCompactFilterChip, _buildCustomShiftHistoryDateFilterChip, _buildDetailRow, _buildShiftClosingActionButtons, _buildShiftHistoryCard, _buildShiftHistoryDateFilterChips, _buildShiftHistoryTab (+20 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.03
Nodes (58): _actionsTrack, _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile (+50 more)

### Community 21 - "catalog_card_polish_test.dart"
Cohesion: 0.15
Nodes (11): build, buildTestApp, _FakeAssetRepositoryForPolish, fetchAssets, fetchCategories, fetchProducts, _initial, main (+3 more)

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.13
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.05
Nodes (35): _buildBusinessErrorCard, _buildConsolidatedBanner, _buildDailyOperationsGrid, _buildDashboardContent, _buildErrorCard, _buildExpandableSearchBar, _buildOnboardingBanner, _buildOperationCard (+27 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (26): shiftScheduleProvider, _branchClosingTime, _branchOpeningTime, build, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard (+18 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.06
Nodes (32): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _canSubmitReturn, _category (+24 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "businessProvider"
Cohesion: 0.08
Nodes (27): build, _buildDateFilterRow, FinancialActivityLedgerScreen, _FinancialActivityLedgerScreenState, _buildCustomDateFilterChip, _buildTopFilterBar, activeShiftProvider, bizState (+19 more)

### Community 29 - "home_header_and_unread_badge_test.dart"
Cohesion: 0.12
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

### Community 34 - "inventory_live_payload_test.dart"
Cohesion: 0.13
Nodes (14): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+6 more)

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
Cohesion: 0.06
Nodes (29): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, build, _buildBranchRow, _buildCurrentStepBody (+21 more)

### Community 39 - "main.dart"
Cohesion: 0.08
Nodes (10): networkStatusProvider, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen, _MainShellScreenState (+2 more)

### Community 40 - "login_screen.dart"
Cohesion: 0.12
Nodes (14): build, createState, dispose, _emailController, _getEffectiveServerClientId, _login, LoginScreen, _LoginScreenState (+6 more)

### Community 41 - "voucher_management_test.dart"
Cohesion: 0.06
Nodes (29): VoucherRepository, _FakeVoucherRepository, _MockVoucherRepo, alerts, build, fetchKpi, fetchVouchers, _FixedAuthNotifier (+21 more)

### Community 42 - "revenue_report_screen.dart"
Cohesion: 0.13
Nodes (12): _buildBranchContributionBreakdown, _buildBranchSelectorHeader, _buildCompactFilterChip, _buildHeroRevenueCard, _buildIncomeTypeBreakdown, _buildPaymentMethodBreakdown, _buildRecentTransactionsAudit, _buildRevenueContent (+4 more)

### Community 43 - "Map"
Cohesion: 0.05
Nodes (34): AuthRepository, _FakeAuthRepository, fakeAuthRepo, _FakeAuthRepository, fetchBusinesses, main, setActiveContext, storedContext (+26 more)

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
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "user_profile_screen.dart"
Cohesion: 0.12
Nodes (17): _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials, _isPasswordLoading, _isProfileLoading, _nameController (+9 more)

### Community 51 - "business_setup_wizard_screen.dart"
Cohesion: 0.07
Nodes (26): _boundUserId, _branchStructure, _buildBottomActionBar, _buildBranchOptionCard, _buildStep1BusinessName, _buildStep2BranchStructure, _buildStep3CategoryPersonalization, _buildStepDivider (+18 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.09
Nodes (20): booking, bookingId, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer, createState (+12 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.10
Nodes (11): build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, logout, _repository (+3 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.08
Nodes (22): build, _buildCenterActionButton, _buildDockItem, currentIndex, FloatingCapsuleDock, onAddTap, onTabSelected, build (+14 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.07
Nodes (26): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _hasValidQrisPayload, _isDynamicQrisEnabled (+18 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.07
Nodes (21): 7, createState, _currentBookingPage, _debounceTimer, didUpdateWidget, dispose, endAt, _extraBookings (+13 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (42): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+34 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

### Community 61 - "customer_repository.dart"
Cohesion: 0.15
Nodes (10): ApiClient, createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument (+2 more)

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

### Community 66 - "ConsumerState"
Cohesion: 0.17
Nodes (14): ExchangeWizardScreen, _ExchangeWizardScreenState, _VoidTransactionDialog, _VoidTransactionDialogState, AddBranchExpenseModal, _AddBranchExpenseModalState, QuickOpenShiftModal, _QuickOpenShiftModalState (+6 more)

### Community 67 - "Map"
Cohesion: 0.12
Nodes (15): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+7 more)

### Community 68 - "animated_success_checkmark.dart"
Cohesion: 0.09
Nodes (19): build, checkColor, _CheckmarkStrokePainter, _checkProgress, circleColor, _circleScale, color, _controller (+11 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.09
Nodes (18): _amountController, branchId, build, _categories, createState, dispose, _errorMessage, _formKey (+10 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.07
Nodes (25): build, copyWith, createCustomer, currentPage, customers, customerSearchResultsProvider, error, hasMore (+17 more)

### Community 71 - "late_return_penalty_pos_test.dart"
Cohesion: 0.06
Nodes (27): CashierRepository, _FakeCashierRepoForLatePenalty, _FakeCashierShiftRepo, _FakeStreamlineCashierRepository, _FakeCashierRepoForDynamicQris, build, _FakeCashierRepository, fetchBookingDetail (+19 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "late_return_penalty_return_workflow_test.dart"
Cohesion: 0.12
Nodes (15): build, buildTestScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchCurrentShift, fetchPaymentMethods, _initialState (+7 more)

### Community 74 - "inventory_empty_state_test.dart"
Cohesion: 0.08
Nodes (21): build, _categories, createCategory, fetchCategories, main, _MockCategoryBizNotifier, assetsToReturn, baseBusinessState (+13 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.10
Nodes (19): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+11 more)

### Community 77 - "package:rentcore_mobile/features/bookings/providers/booking_provider.dart"
Cohesion: 0.08
Nodes (21): PaymentRepository, PaymentContext, PaymentResult, executePayment, lastContext, main, mockCategories, mockPaymentMethods (+13 more)

### Community 79 - "notification_provider.dart"
Cohesion: 0.13
Nodes (13): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, _isFetchingUnreadCount, isLoading, markAllAsRead (+5 more)

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.14
Nodes (8): Point, x, y, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "asset_provider.dart"
Cohesion: 0.09
Nodes (22): AssetCategoryFilterNotifier, bizState, build, catalogModelsProvider, CatalogSearchQueryNotifier, categoryId, copyWith, error (+14 more)

### Community 128 - "authProvider"
Cohesion: 0.16
Nodes (15): _handleGoogleSignIn, build, _handleSavePassword, _handleSaveProfile, initState, authProvider, authRepositoryProvider, build (+7 more)

### Community 129 - "onboarding_provider.dart"
Cohesion: 0.12
Nodes (15): build, completeWalkthrough, copyWith, dismissChecklist, hasCompletedWalkthrough, isChecklistDismissed, isLoading, OnboardingNotifier (+7 more)

### Community 130 - "../../core/constants/app_colors.dart"
Cohesion: 0.10
Nodes (13): _buildDateChip, _buildFilterChip, _buildLedgerTile, createState, dispose, _searchController, _searchFilter, _selectedType (+5 more)

### Community 131 - "app_text_styles.dart"
Cohesion: 0.17
Nodes (5): AppTextStyles, pageHeader, pageHeaderHorizontalPadding, pageHeaderToolbarHeight, AppTheme

### Community 132 - "booking_provider.dart"
Cohesion: 0.14
Nodes (12): bizState, BookingFilterNotifier, BookingSearchQueryNotifier, build, clear, fetchBookings, fetchReadyAssets, repo (+4 more)

### Community 133 - "notification_and_branch_switcher_simplification_test.dart"
Cohesion: 0.12
Nodes (15): build, checkCurrentSession, _FakeBusinessNotifier, fetchNotifications, _initialState, lastIsConsolidated, lastMarkedReadId, lastSelectedBranch (+7 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (17): didChangeAppLifecycleState, _handleRefresh, initState, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationRow (+9 more)

### Community 135 - "onboarding_routing_gate_test.dart"
Cohesion: 0.13
Nodes (13): checkSession, _FakeGateBookingRepository, fetchAssetModels, fetchAssets, fetchBookings, fetchBusinesses, fetchCategories, fetchProducts (+5 more)

### Community 136 - "financial_hub_screen.dart"
Cohesion: 0.17
Nodes (8): build, createState, dispose, FinancialHubScreen, _FinancialHubScreenState, initialTabIndex, initState, _tabController

### Community 137 - "AuthNotifier"
Cohesion: 0.08
Nodes (21): AuthNotifier, build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main (+13 more)

### Community 138 - "quick_open_shift_modal.dart"
Cohesion: 0.12
Nodes (15): branchId, build, createState, dispose, _errorMessage, _floatController, _focusNode, _formatInput (+7 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.22
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "staff_resignation_sheet.dart"
Cohesion: 0.13
Nodes (13): build, businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState (+5 more)

### Community 141 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.11
Nodes (15): authStateOwner, build, businessStateOwner, fetchPaymentMethods, fetchPaymentSettings, hasPayload, _initial, isDynamicQris (+7 more)

### Community 142 - "package:flutter/material.dart"
Cohesion: 0.03
Nodes (50): rootNavigatorKey, bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchCurrentShift (+42 more)

### Community 143 - "customer_directory_screen.dart"
Cohesion: 0.08
Nodes (26): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+18 more)

### Community 144 - "physical_units_empty_state_guided_progression_test.dart"
Cohesion: 0.13
Nodes (14): assets, baseBusinessState, build, categories, createTestWidget, fetchAssets, fetchCategories, fetchModels (+6 more)

### Community 145 - "package:flutter_secure_storage/flutter_secure_storage.dart"
Cohesion: 0.17
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 146 - "inventory_unit_deduplication_test.dart"
Cohesion: 0.14
Nodes (13): build, _DuplicateMockAssetRepository, duplicateUnitsList, fetchAssets, fetchAssetsPaginated, fetchCategories, fetchModels, fetchProducts (+5 more)

### Community 147 - "voucher_screen.dart"
Cohesion: 0.09
Nodes (15): branches, build, _buildDetailRow, _confirmDelete, isOwner, onPrintThermal, show, voucher (+7 more)

### Community 148 - "feature_walkthrough_screen.dart"
Cohesion: 0.11
Nodes (16): build, _buildBottomControls, _buildMetricTile, _buildSlide1Preview, _buildSlide2Preview, _buildSlide3Preview, _buildSlide4Preview, _buildSlideContainer (+8 more)

### Community 149 - "add_customer_sheet.dart"
Cohesion: 0.15
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 150 - "cashier_shift_and_rental_queue_refactor_test.dart"
Cohesion: 0.07
Nodes (19): activeShiftData, bookings, build, closedShiftResult, closeShift, _FakeBusinessNotifier, fetchBookingDetail, fetchBookings (+11 more)

### Community 151 - "pos_all_branches_filter_test.dart"
Cohesion: 0.08
Nodes (21): bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, main (+13 more)

### Community 152 - "rental_addons_and_policies_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 153 - "currency_formatter.dart"
Cohesion: 0.29
Nodes (5): DateFormatter, formatFull, formatRelative, formatShort, formatTime

### Community 154 - "device_protection_quarantine_return_test.dart"
Cohesion: 0.08
Nodes (22): androidBooking, appleBooking, build, buildScreen, _FakeCashierRepo, fetchCurrentShift, fetchPaymentMethods, _initialState (+14 more)

### Community 155 - "cashier_and_header_standardization_test.dart"
Cohesion: 0.05
Nodes (32): build, _EmptyBookingRepo, fetchBookings, fetchBookingsForCashier, fetchBranchExpenses, fetchClosingSummary, fetchPaymentMethods, _MockCashierBizNotifier (+24 more)

### Community 156 - "printerProvider"
Cohesion: 0.06
Nodes (39): _printBookingReceipt, ExchangeHistorySheet, _printExchangeReceipt, printBookingReceipt, RentalQueueActions, _showReturnSuccessDialog, _showExpenseOptionsDialog, build (+31 more)

### Community 157 - "navigation_laporan_and_queue_actions_test.dart"
Cohesion: 0.04
Nodes (56): DashboardRepository, _FakeDashboardRepository, build, changeBranch, _FakeCashierRepository, _FakeDashboardRepository, fetchBookingsForCashier, fetchClosingSummary (+48 more)

### Community 158 - "win32_window.cpp"
Cohesion: 0.17
Nodes (5): EnableFullDpiSupportIfAvailable(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 159 - "int?"
Cohesion: 0.07
Nodes (27): PosFilterBranchIdNotifier, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState, _initialValue (+19 more)

### Community 160 - "network_status_provider.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 161 - "booking_provider.dart"
Cohesion: 0.17
Nodes (16): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+8 more)

### Community 162 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 163 - "BookingRepository"
Cohesion: 0.03
Nodes (58): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, build, _FakeSearchBookingRepository, fetchBookings, initialState, lastBranchId (+50 more)

### Community 164 - "home_dashboard_metrics_grid_test.dart"
Cohesion: 0.14
Nodes (13): build, data, _FakeAssetRepo, _FakeBookingRepo, fetchAssets, fetchBookings, fetchCategories, fetchKpi (+5 more)

### Community 165 - "../../auth/providers/business_provider.dart"
Cohesion: 0.14
Nodes (11): build, _buildEmbeddedRentalQueue, HomeScreen, _HomeScreenState, bizState, dashboardKpiProvider, dashboardQueueBookingsProvider, dashboardRepositoryProvider (+3 more)

### Community 166 - "provider_late_initialization_and_store_profile_test.dart"
Cohesion: 0.14
Nodes (13): checkSession, fetchAssets, fetchBusinesses, fetchCustomers, fetchVouchers, loggedInEmail, login, logout (+5 more)

### Community 167 - "rental_duration_multiplier_test.dart"
Cohesion: 0.14
Nodes (13): adjustDuration, build, _FakeDurationMultiplierBookingRepository, fetchBookings, initialState, lastAdditionalFee, lastBookingId, lastBookingItemId (+5 more)

### Community 168 - "AuthNotifier"
Cohesion: 0.23
Nodes (15): build, build, initState, InventoryScreen, _InventoryScreenState, _onUnitsScroll, build, TarifSewaSheet (+7 more)

### Community 169 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.15
Nodes (11): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+3 more)

### Community 170 - "notification_center_test.dart"
Cohesion: 0.17
Nodes (6): build, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead, markAsRead

### Community 171 - "customer_directory_and_governance_test.dart"
Cohesion: 0.18
Nodes (5): createCustomer, dummyCustomers, fetchCustomersPaginated, main, toggleBlacklist

### Community 172 - "logout_and_inventory_detail_test.dart"
Cohesion: 0.18
Nodes (10): build, fetchBusinesses, fetchCategories, fetchProducts, _initial, logout, main, setActiveContext (+2 more)

### Community 173 - "qris_service.dart"
Cohesion: 0.40
Nodes (4): calculateCrc16, generateDynamicQris, isValidQrisPayload, QrisService

### Community 174 - "progressive_checklist_banner.dart"
Cohesion: 0.22
Nodes (3): _buildChecklistItem, onOpenInventory, totalAssetCount

### Community 176 - "payment_repository.dart"
Cohesion: 0.20
Nodes (4): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods

### Community 177 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 178 - "AssetRepository"
Cohesion: 0.20
Nodes (10): AssetRepository, _MockCategoryAssetRepo, _FakeAssetRepository, _TrackingAssetRepository, _ConfigurableAssetRepository, _LivePayloadAssetRepository, _MockAssetRepository, _FakeGateAssetRepository (+2 more)

### Community 179 - "exchange_history_sheet.dart"
Cohesion: 0.15
Nodes (8): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, _printExchangeReceipt, show

### Community 180 - "SingleTickerProviderStateMixin"
Cohesion: 0.29
Nodes (8): AnimatedSuccessCheckmark, _AnimatedSuccessCheckmarkState, SkeletonPulseWrapper, _SkeletonPulseWrapperState, ExpandableInventoryFab, ExpandableInventoryFabState, _PaymentSuccessView, _PaymentSuccessViewState

### Community 181 - "string"
Cohesion: 0.33
Nodes (5): CustomerSearchQueryNotifier, AssetSearchQueryNotifier, AssetStatusFilterNotifier, TransferDirectionNotifier, TransferStatusNotifier

### Community 183 - "direct_rental_streamline_and_multiplier_test.dart"
Cohesion: 0.12
Nodes (16): build, buildScreen, createRental, createRentalCalls, fakeBookingRepo, fakeCashierRepo, _FakeStreamlineBookingRepository, fetchCurrentShift (+8 more)

### Community 184 - "currency_formatter.dart"
Cohesion: 0.33
Nodes (4): CurrencyFormatter, format, _formatter, parse

### Community 185 - "BusinessNotifier"
Cohesion: 0.06
Nodes (31): AuthState, BusinessNotifier, BusinessState, _TestBusinessNotifier, build, FakeCashierRepository, fetchPaymentSettings, _initial (+23 more)

### Community 186 - "NotificationNotifier"
Cohesion: 0.40
Nodes (5): NotificationNotifier, NotificationState, _TrackingNotificationNotifier, _FakeNotificationNotifier, _FakeNotificationNotifier

### Community 187 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 188 - "transfer_provider.dart"
Cohesion: 0.12
Nodes (19): build, _buildDirectionChip, _buildStatusChip, TransfersScreen, _TransfersScreenState, branchRecipientsProvider, build, destinationAffiliatesProvider (+11 more)

### Community 189 - "businessProvider"
Cohesion: 0.11
Nodes (32): checkCurrentSession, _invalidateTenantAndUserData, login, businessProvider, _buildBookingPaymentContext, _buildStep3FinancialAndAuth, _buildActiveShiftTab, _buildBranchSelectorHeader (+24 more)

### Community 190 - "progressive_checklist_banner_test.dart"
Cohesion: 0.10
Nodes (15): ReceiptCustomizationSettings, buildTestableWidget, main, build, dismissedMap, _initial, isChecklistDismissed, main (+7 more)

### Community 191 - "CustomerRepository"
Cohesion: 0.67
Nodes (3): CustomerRepository, MockCustomerRepository, _MockCustomerRepo

### Community 192 - "CustomerNotifier"
Cohesion: 0.67
Nodes (3): CustomerNotifier, customerRepositoryProvider, CustomerState

### Community 194 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.08
Nodes (18): build, createTestWidget, fetchAssets, fetchCategories, fetchProducts, main, _MockAssetRepo, _MockBizNotifier (+10 more)

### Community 196 - "assetRepositoryProvider"
Cohesion: 0.20
Nodes (10): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, _EditAssetSheet, _EditAssetSheetState (+2 more)

### Community 203 - "organization_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 204 - "OrganizationNotifier"
Cohesion: 0.33
Nodes (6): OrganizationNotifier, OrganizationState, _MockOrganizationNotifier, _MockRentalRulesOrgNotifier, _MockOrganizationNotifier, MockOrganizationNotifier

### Community 207 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

## Knowledge Gaps
- **2430 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+2425 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2670 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `win32_window.cpp` to `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `flutter_window.h`, `.Create`, `Size`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _2430 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `CashierRepository` connect `late_return_penalty_pos_test.dart` to `Cashier POS & Register`, `package:flutter/material.dart`, `payment_repository.dart`, `cashier_shift_and_rental_queue_refactor_test.dart`, `pos_all_branches_filter_test.dart`, `BusinessNotifier`, `device_protection_quarantine_return_test.dart`, `cashier_and_header_standardization_test.dart`, `businessProvider`, `navigation_laporan_and_queue_actions_test.dart`, `int?`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.0873015873015873 - nodes in this community are weakly interconnected._
- **Why does `BusinessState` connect `BusinessNotifier` to `notification_and_branch_switcher_simplification_test.dart`, `List`, `package:flutter_test/flutter_test.dart`, `package:flutter/material.dart`, `catalog_card_refactor_test.dart`, `physical_units_empty_state_guided_progression_test.dart`, `inventory_unit_deduplication_test.dart`, `catalog_card_polish_test.dart`, `pos_all_branches_filter_test.dart`, `Home Dashboard & Analytics`, `device_protection_quarantine_return_test.dart`, `home_header_and_unread_badge_test.dart`, `navigation_laporan_and_queue_actions_test.dart`, `int?`, `business_provider.dart`, `inventory_live_payload_test.dart`, `BookingRepository`, `staff_resignation_test.dart`, `rental_duration_multiplier_test.dart`, `logout_and_inventory_detail_test.dart`, `direct_rental_streamline_and_multiplier_test.dart`, `payment_page_test.dart`, `Map`, `late_return_penalty_pos_test.dart`, `late_return_penalty_return_workflow_test.dart`, `inventory_empty_state_test.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.024390243902439025 - nodes in this community are weakly interconnected._