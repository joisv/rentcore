# Graph Report - rentcore  (2026-11-11)

## Corpus Check
- 199 files · ~205,145 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 3356 nodes · 5340 edges · 185 communities (134 shown, 51 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c50f1b9c`
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
- financial_activity_ledger_screen.dart
- pos_revenue_consolidation_widget_test.dart
- businessProvider
- customer_directory_to_booking_prefill_test.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- cashier_screen.dart
- payment_page.dart
- Size
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
- ../../core/constants/app_colors.dart
- dock_aware_scaffold.dart
- generate_onboarding_figcraft.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- main.dart
- _PaymentPageState
- auth_lifecycle_relogin_test.dart
- cashier_shift_and_rental_queue_refactor_test.dart
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
- booking_rc_261030_0001_late_penalty_bug_fix_test.dart
- Map
- voucher_management_test.dart
- add_branch_expense_modal.dart
- customer_provider.dart
- customer_repository.dart
- store_settings_screen.dart
- login_screen.dart
- feature_walkthrough_screen.dart
- Cashier POS & Register
- bookings_queue_overdue_test.dart
- Windows Native Desktop Runner
- StatelessWidget
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
- ../../core/utils/currency_formatter.dart
- onboarding_provider.dart
- network_status_provider.dart
- customer_detail_sheet.dart
- notification_center_test.dart
- notification_center_screen.dart
- booking_provider.dart
- string
- voucher_screen.dart
- quick_open_shift_modal.dart
- package:shared_preferences/shared_preferences.dart
- onboarding_routing_gate_test.dart
- dynamic_qris_end_to_end_test.dart
- _DirectRentalScreenState
- customer_directory_screen.dart
- notification_provider.dart
- late_return_penalty_return_workflow_test.dart
- printer_settings_screen.dart
- home_dashboard_kpi_test.dart
- ConsumerState
- inventory_live_payload_test.dart
- ../../auth/providers/business_provider.dart
- customer_directory_and_governance_test.dart
- dashboard_cleanup_and_navigation_test.dart
- currency_formatter.dart
- device_protection_quarantine_return_test.dart
- staff_resignation_test.dart
- catalog_card_polish_test.dart
- home_dashboard_refactor_test.dart
- win32_window.cpp
- List
- direct_rental_refactor_test.dart
- _BookingsScreenState
- AuthNotifier
- BookingRepository
- AuthRepository
- logout_and_inventory_detail_test.dart
- MaterialPageRoute
- unit_test.dart
- PaymentRepository
- package:flutter/material.dart
- List
- navigation_keys.dart
- inventory_unit_deduplication_test.dart
- qris_service.dart
- _EditAssetSheetState
- exchange_history_sheet.dart
- cashierRepositoryProvider
- branch_revenue_and_dashboard_test.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- progressive_checklist_banner.dart
- cash_suggestion_helper.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- progressive_checklist_banner_test.dart
- rental_addons_and_policies_test.dart
- OrganizationNotifier

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 88 edges
2. `BusinessNotifier` - 47 edges
3. `authProvider` - 44 edges
4. `BusinessState` - 32 edges
5. `AuthNotifier` - 29 edges
6. `organizationProvider` - 28 edges
7. `printerProvider` - 24 edges
8. `BookingRepository` - 23 edges
9. `CashierRepository` - 23 edges
10. `Win32Window` - 21 edges

## Surprising Connections (you probably didn't know these)
- `_FakeWalkthroughAuthRepository` --inherits--> `AuthRepository`  [EXTRACTED]
  test/feature_walkthrough_test.dart → lib/features/auth/data/auth_repository.dart
- `_MockGoogleAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockPasswordAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_dashboard_refactor_test.dart → lib/features/auth/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (185 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.08
Nodes (34): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+26 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.02
Nodes (80): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+72 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.03
Nodes (76): _addonSubtotal, _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildAddonsSelectionSection, _buildNavigationButtonRow, _buildStep1UnitAndDuration (+68 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.05
Nodes (18): Cocoa, file_selector_macos, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate (+10 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.04
Nodes (58): _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard, _buildErrorState, _buildMembersTab (+50 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.04
Nodes (45): additionalHours, addonSubtotal, amountPaid, assetCode, booking, bookingCode, bookingId, branchId (+37 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (32): _accessoriesController, _addPresetRate, _addRateRow, _brandController, _buildPresetChip, _colorController, createState, _descriptionController (+24 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+20 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (27): PrinterConnectionStatus, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith, disconnect (+19 more)

### Community 12 - "financial_activity_ledger_screen.dart"
Cohesion: 0.11
Nodes (17): _buildActiveShiftTab, _buildDateFilterChips, build, _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState (+9 more)

### Community 13 - "pos_revenue_consolidation_widget_test.dart"
Cohesion: 0.14
Nodes (13): build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState, _initialValue, lastEndDate (+5 more)

### Community 14 - "businessProvider"
Cohesion: 0.17
Nodes (16): businessProvider, _buildBookingPaymentContext, BookingFilterNotifier, BookingSearchQueryNotifier, _buildBranchSelectorHeader, _buildStickyClosingBottomBar, _submit, posFilterBranchIdProvider (+8 more)

### Community 15 - "customer_directory_to_booking_prefill_test.dart"
Cohesion: 0.13
Nodes (7): executePayment, lastContext, main, mockCategories, mockPaymentMethods, mockReadyAssets, main

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
Nodes (25): build, _buildCompactFilterChip, _buildCustomDateFilterChip, _buildCustomShiftHistoryDateFilterChip, _buildDetailRow, _buildShiftHistoryCard, _buildShiftHistoryDateFilterChips, _buildShiftHistoryTab (+17 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.04
Nodes (44): _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile, _buildGopayBadge (+36 more)

### Community 21 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.13
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.06
Nodes (26): _buildBusinessErrorCard, _buildDailyOperationsGrid, _buildDashboardContent, _buildErrorCard, _buildOnboardingBanner, _buildOperationCard, _buildOverdueAlertCard, _buildQueueCard (+18 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (26): shiftScheduleProvider, _branchClosingTime, _branchOpeningTime, build, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard (+18 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.06
Nodes (28): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _category, _checklistDefs (+20 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "cashier_provider.dart"
Cohesion: 0.10
Nodes (20): bizState, build, cashierBookingsProvider, effectiveBranchId, endDate, fetchCurrentShift, isConsolidated, label (+12 more)

### Community 29 - "printerProvider"
Cohesion: 0.14
Nodes (16): ExchangeHistorySheet, _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, build, ProgressiveChecklistBanner, _finishWalkthrough, onboardingProvider (+8 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.04
Nodes (48): activeShift, branchId, build, _buildCloseShiftMiddleContent, _buildCoinRow, _buildDenominationRow, _buildDirectTotalInput, _buildHeader (+40 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.07
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.09
Nodes (21): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCategoryRelevant (+13 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.08
Nodes (20): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+12 more)

### Community 34 - "../../core/constants/app_colors.dart"
Cohesion: 0.17
Nodes (7): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, FloatingCapsuleDock, onTabSelected

### Community 35 - "dock_aware_scaffold.dart"
Cohesion: 0.11
Nodes (15): appBar, backgroundColor, body, bottomSheet, build, DockEdgeInsetsExtension, DockFloatingActionButtonLocation, extra (+7 more)

### Community 36 - "generate_onboarding_figcraft.dart"
Cohesion: 0.03
Nodes (74): archCard, authCard, avtBtn, b1, bellBtn, bizPill, btnBack3, btnBack4 (+66 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.07
Nodes (26): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildCurrentStepBody, _buildStep1Identity, _buildStep2Branch (+18 more)

### Community 39 - "main.dart"
Cohesion: 0.09
Nodes (9): networkStatusProvider, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen, _MainShellScreenState (+1 more)

### Community 40 - "_PaymentPageState"
Cohesion: 0.26
Nodes (12): currentShiftByBranchProvider, currentShiftProvider, paymentSettingsProvider, build, paymentRepositoryProvider, build, _executePaymentProcess, PaymentPage (+4 more)

### Community 41 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.08
Nodes (22): VoucherRepository, currentUserEmail, _FakeVoucherRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+14 more)

### Community 42 - "cashier_shift_and_rental_queue_refactor_test.dart"
Cohesion: 0.05
Nodes (33): activeShiftData, bookings, build, closedShiftResult, closeShift, fetchBookingDetail, fetchBookings, fetchClosingSummary (+25 more)

### Community 43 - "Map"
Cohesion: 0.09
Nodes (18): completeWalkthrough, _FakeWalkthroughAuthRepository, isWalkthroughCompleted, main, walkthroughApiCalled, buildTestApp, main, completeWalkthrough (+10 more)

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
Cohesion: 0.12
Nodes (15): actions, automaticallyImplyLeading, backgroundColor, bottom, build, centerTitle, color, leading (+7 more)

### Community 48 - "status_badge.dart"
Cohesion: 0.11
Nodes (15): backgroundColor, borderColor, borderRadius, build, fontSize, icon, inventory, isLineThrough (+7 more)

### Community 49 - "Windows Native Desktop Runner"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "authProvider"
Cohesion: 0.09
Nodes (25): build, _handleGoogleSignIn, build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials (+17 more)

### Community 51 - "business_setup_wizard_screen.dart"
Cohesion: 0.06
Nodes (37): authRepositoryProvider, build, build, _boundUserId, _branchStructure, _buildBottomActionBar, _buildBranchOptionCard, _buildStep1BusinessName (+29 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.12
Nodes (9): copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository, updatePassword, updateProfile (+1 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (28): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+20 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.12
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.07
Nodes (24): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _hasValidQrisPayload, _isDynamicQrisEnabled (+16 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.04
Nodes (38): 7, _AdjustmentTarget, assetCode, catName, combined, createState, _currentBookingPage, currentDurationHours (+30 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.04
Nodes (46): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+38 more)

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

### Community 66 - "booking_rc_261030_0001_late_penalty_bug_fix_test.dart"
Cohesion: 0.04
Nodes (48): CashierRepository, bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, _FakeCashierRepoForLatePenalty (+40 more)

### Community 67 - "Map"
Cohesion: 0.12
Nodes (15): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+7 more)

### Community 68 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (16): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+8 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (18): AddBranchExpenseModal, _AddBranchExpenseModalState, _amountController, branchId, build, _categories, createState, dispose (+10 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.08
Nodes (27): build, copyWith, createCustomer, currentPage, CustomerNotifier, customerRepositoryProvider, customers, customerSearchResultsProvider (+19 more)

### Community 71 - "customer_repository.dart"
Cohesion: 0.15
Nodes (10): ApiClient, createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument (+2 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "login_screen.dart"
Cohesion: 0.13
Nodes (13): createState, dispose, _emailController, _getEffectiveServerClientId, _login, LoginScreen, _LoginScreenState, _obscurePassword (+5 more)

### Community 74 - "feature_walkthrough_screen.dart"
Cohesion: 0.11
Nodes (16): build, _buildBottomControls, _buildMetricTile, _buildSlide1Preview, _buildSlide2Preview, _buildSlide3Preview, _buildSlide4Preview, _buildSlideContainer (+8 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.10
Nodes (19): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+11 more)

### Community 77 - "bookings_queue_overdue_test.dart"
Cohesion: 0.15
Nodes (12): build, changeBranch, _FakeBookingRepository, fetchBookings, initialState, lastAllBranches, lastBranchId, lastSearch (+4 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.33
Nodes (5): DockAwareScaffold, DockClearance, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.14
Nodes (8): Point, x, y, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "asset_provider.dart"
Cohesion: 0.10
Nodes (19): bizState, catalogModelsProvider, categoryId, copyWith, error, fetchCategories, fetchModels, fetchProducts (+11 more)

### Community 128 - "../../core/utils/currency_formatter.dart"
Cohesion: 0.20
Nodes (4): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods

### Community 129 - "onboarding_provider.dart"
Cohesion: 0.13
Nodes (14): checkStatus, completeWalkthrough, copyWith, dismissChecklist, hasCompletedWalkthrough, isChecklistDismissed, isLoading, OnboardingNotifier (+6 more)

### Community 130 - "network_status_provider.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 132 - "customer_detail_sheet.dart"
Cohesion: 0.18
Nodes (9): build, createState, customer, CustomerDetailSheet, _CustomerDetailSheetState, _getInitials, _handleBlacklistToggle, initState (+1 more)

### Community 133 - "notification_center_test.dart"
Cohesion: 0.14
Nodes (9): NotificationNotifier, NotificationState, build, _FakeNotificationNotifier, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead (+1 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (16): _buildHeader, _handleRefresh, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState (+8 more)

### Community 135 - "booking_provider.dart"
Cohesion: 0.17
Nodes (10): bizState, build, clear, fetchBookings, fetchReadyAssets, repo, searchQuery, setFilter (+2 more)

### Community 136 - "string"
Cohesion: 0.15
Nodes (11): branchRecipientsProvider, build, direction, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, repo, setDirection (+3 more)

### Community 137 - "voucher_screen.dart"
Cohesion: 0.09
Nodes (22): checkCurrentSession, login, branches, build, _buildDetailRow, _confirmDelete, isOwner, onPrintThermal (+14 more)

### Community 138 - "quick_open_shift_modal.dart"
Cohesion: 0.12
Nodes (17): branchId, build, createState, dispose, _errorMessage, _floatController, _focusNode, _formatInput (+9 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "onboarding_routing_gate_test.dart"
Cohesion: 0.13
Nodes (12): checkSession, fetchAssetModels, fetchAssets, fetchBookings, fetchBusinesses, fetchCategories, fetchProducts, fetchReadyAssets (+4 more)

### Community 141 - "dynamic_qris_end_to_end_test.dart"
Cohesion: 0.08
Nodes (20): authStateOwner, build, businessStateOwner, fetchPaymentMethods, fetchPaymentSettings, hasPayload, _initial, isDynamicQris (+12 more)

### Community 142 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

### Community 143 - "customer_directory_screen.dart"
Cohesion: 0.12
Nodes (17): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+9 more)

### Community 144 - "notification_provider.dart"
Cohesion: 0.14
Nodes (12): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+4 more)

### Community 145 - "late_return_penalty_return_workflow_test.dart"
Cohesion: 0.13
Nodes (14): build, buildTestScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, _initialState, main (+6 more)

### Community 146 - "printer_settings_screen.dart"
Cohesion: 0.17
Nodes (8): build, _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, PrinterSettingsScreen, _PrinterSettingsScreenState

### Community 147 - "home_dashboard_kpi_test.dart"
Cohesion: 0.14
Nodes (12): DashboardRepository, _FakeDashboardRepository, _FakeDashboardRepository, _ActiveBusinessNotifier, build, _CapturingDashboardRepository, fetchKpi, lastBranchId (+4 more)

### Community 148 - "ConsumerState"
Cohesion: 0.18
Nodes (13): InventoryScreen, _AddBranchBottomSheet, _AddBranchBottomSheetState, _InviteMemberBottomSheet, _InviteMemberBottomSheetState, ManageOrganizationScreen, _ManageOrganizationScreenState, _RentalRulesTabView (+5 more)

### Community 149 - "inventory_live_payload_test.dart"
Cohesion: 0.13
Nodes (14): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+6 more)

### Community 150 - "../../auth/providers/business_provider.dart"
Cohesion: 0.15
Nodes (10): build, _buildEmbeddedRentalQueue, HomeScreen, _HomeScreenState, bizState, dashboardKpiProvider, dashboardQueueBookingsProvider, dashboardRepositoryProvider (+2 more)

### Community 151 - "customer_directory_and_governance_test.dart"
Cohesion: 0.17
Nodes (7): CustomerRepository, createCustomer, dummyCustomers, fetchCustomersPaginated, main, MockCustomerRepository, toggleBlacklist

### Community 152 - "dashboard_cleanup_and_navigation_test.dart"
Cohesion: 0.10
Nodes (16): build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main, _MockGoogleAuthNotifier (+8 more)

### Community 153 - "currency_formatter.dart"
Cohesion: 0.15
Nodes (9): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+1 more)

### Community 154 - "device_protection_quarantine_return_test.dart"
Cohesion: 0.09
Nodes (18): androidBooking, appleBooking, buildScreen, fetchPaymentMethods, main, processReturn, submittedPayload, _TestBusinessNotifier (+10 more)

### Community 155 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 156 - "catalog_card_polish_test.dart"
Cohesion: 0.17
Nodes (10): build, buildTestApp, fetchAssets, fetchCategories, fetchProducts, _initial, main, products (+2 more)

### Community 157 - "home_dashboard_refactor_test.dart"
Cohesion: 0.17
Nodes (10): bookings, build, data, _FakeBookingRepoForDashboard, fetchBookingDetail, fetchBookings, fetchKpi, main (+2 more)

### Community 158 - "win32_window.cpp"
Cohesion: 0.17
Nodes (5): EnableFullDpiSupportIfAvailable(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 159 - "List"
Cohesion: 0.18
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 160 - "direct_rental_refactor_test.dart"
Cohesion: 0.20
Nodes (9): PaymentContext, PaymentResult, executePayment, lastContext, lastResult, main, mockCategories, mockPaymentMethods (+1 more)

### Community 161 - "_BookingsScreenState"
Cohesion: 0.17
Nodes (16): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+8 more)

### Community 162 - "AuthNotifier"
Cohesion: 0.11
Nodes (31): AuthNotifier, logout, customerSearchQueryProvider, AddProductSheet, _AddProductSheetState, build, _showQuickAddCategoryDialog, _submitProduct (+23 more)

### Community 163 - "BookingRepository"
Cohesion: 0.03
Nodes (65): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, build, _FakeSearchBookingRepository, fetchBookings, initialState, lastBranchId (+57 more)

### Community 164 - "AuthRepository"
Cohesion: 0.22
Nodes (9): AuthRepository, _FakeAuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakePolishAuthRepository, _FakeGateAuthRepository, _FakeAuthRepository, _FakeChecklistAuthRepository (+1 more)

### Community 165 - "logout_and_inventory_detail_test.dart"
Cohesion: 0.17
Nodes (11): build, fetchBusinesses, fetchCategories, fetchProducts, _initial, logout, main, _MockAssetRepository (+3 more)

### Community 166 - "MaterialPageRoute"
Cohesion: 0.22
Nodes (8): _processOverdueReturn, build, _openShiftMenu, _buildQuickActionsCard, _printPreviewReceipt, build, _openOnboardingDialog, build

### Community 168 - "PaymentRepository"
Cohesion: 0.40
Nodes (5): PaymentRepository, MockPaymentRepository, MockPaymentRepository, _FakePaymentRepoForSelection, MockPaymentRepoForVisibility

### Community 169 - "package:flutter/material.dart"
Cohesion: 0.07
Nodes (21): AppTheme, bookings, build, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, main (+13 more)

### Community 170 - "List"
Cohesion: 0.03
Nodes (68): AssetRepository, build, _categories, createCategory, fetchCategories, main, _MockCategoryAssetRepo, _MockCategoryBizNotifier (+60 more)

### Community 172 - "inventory_unit_deduplication_test.dart"
Cohesion: 0.09
Nodes (18): main, build, duplicateUnitsList, fetchAssets, fetchAssetsPaginated, fetchCategories, fetchModels, fetchProducts (+10 more)

### Community 173 - "qris_service.dart"
Cohesion: 0.40
Nodes (4): calculateCrc16, generateDynamicQris, isValidQrisPayload, QrisService

### Community 175 - "exchange_history_sheet.dart"
Cohesion: 0.17
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 178 - "cashierRepositoryProvider"
Cohesion: 0.17
Nodes (12): _printBookingReceipt, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, CashDrawerShiftModal, _CashDrawerShiftModalState, _submitCloseShift, _submitOpenShift (+4 more)

### Community 180 - "branch_revenue_and_dashboard_test.dart"
Cohesion: 0.14
Nodes (13): build, changeBranch, _FakeCashierRepository, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main (+5 more)

### Community 182 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.04
Nodes (41): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage, build (+33 more)

### Community 183 - "progressive_checklist_banner.dart"
Cohesion: 0.20
Nodes (3): _buildChecklistItem, onOpenInventory, totalAssetCount

### Community 184 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 185 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.06
Nodes (30): AuthState, BusinessNotifier, BusinessState, _TestBusinessNotifier, _FakeBusinessNotifier, _TestBusinessNotifier, build, FakeCashierRepository (+22 more)

### Community 190 - "progressive_checklist_banner_test.dart"
Cohesion: 0.09
Nodes (18): ReceiptCustomizationSettings, PrinterNotifier, PrinterState, buildTestableWidget, main, build, dismissedMap, _initial (+10 more)

### Community 193 - "rental_addons_and_policies_test.dart"
Cohesion: 0.25
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 195 - "OrganizationNotifier"
Cohesion: 0.33
Nodes (6): OrganizationNotifier, OrganizationState, _MockOrganizationNotifier, _MockRentalRulesOrgNotifier, _MockOrganizationNotifier, MockOrganizationNotifier

## Knowledge Gaps
- **2180 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+2175 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2421 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `win32_window.cpp` to `flutter_window.h`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `.Create`, `Size`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _2180 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `AuthRepository` connect `AuthRepository` to `business_provider.dart`, `onboarding_provider.dart`, `Map`, `Authentication & User Session`, `auth_provider.dart`, `Organization & Branch Management`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.07657657657657657 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `businessProvider` to `onboarding_provider.dart`, `transfers_screen.dart`, `notification_center_screen.dart`, `booking_provider.dart`, `Inventory & Asset Catalog`, `voucher_screen.dart`, `Organization & Branch Management`, `financial_activity_ledger_screen.dart`, `_DirectRentalScreenState`, `Receipt Customization Settings`, `Voucher & Discount Rules`, `cashier_screen.dart`, `ConsumerState`, `../../auth/providers/business_provider.dart`, `Home Dashboard & Analytics`, `shift_schedule_screen.dart`, `Rental Return Processing`, `cashier_provider.dart`, `printerProvider`, `business_provider.dart`, `_BookingsScreenState`, `AuthNotifier`, `MaterialPageRoute`, `main.dart`, `_PaymentPageState`, `business_selector_sheet.dart`, `_EditAssetSheetState`, `cashierRepositoryProvider`, `business_setup_wizard_screen.dart`, `store_profile_screen.dart`, `OrganizationNotifier`, `add_branch_expense_modal.dart`, `customer_provider.dart`, `store_settings_screen.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.024390243902439025 - nodes in this community are weakly interconnected._