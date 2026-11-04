# Graph Report - rentcore  (2026-11-04)

## Corpus Check
- 179 files · ~183,500 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2993 nodes · 4718 edges · 165 communities (110 shown, 55 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b2c4ce6d`
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
- asset_provider.dart
- main.dart
- notification_provider.dart
- package:flutter/material.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- cashier_screen.dart
- payment_page.dart
- Win32Window
- Printer Bluetooth Driver Module
- thermal_receipt_preview_dialog.dart
- Home Dashboard & Analytics
- shift_schedule_screen.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- VoucherRepository
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- customer_directory_screen.dart
- dock_aware_scaffold.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- home_dashboard_refactor_test.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- notification_item.dart
- Booking Management System
- Authentication & User Session
- rentcore_app_bar.dart
- status_badge.dart
- Windows Native Desktop Runner
- authProvider
- staff_resignation_test.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- auth_provider.dart
- payment_page_test.dart
- pos_numpad.dart
- payment_method_settings_screen.dart
- bookings_screen.dart
- exchange_wizard_screen.dart
- store_profile_screen.dart
- voucher_management_test.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- package:flutter/material.dart
- Map
- ConsumerState
- add_branch_expense_modal.dart
- customer_provider.dart
- customer_repository.dart
- store_settings_screen.dart
- package:flutter_test/flutter_test.dart
- Cashier POS & Register
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
- logout
- ../../core/utils/currency_formatter.dart
- exchange_history_sheet.dart
- staff_resignation_sheet.dart
- notification_center_screen.dart
- booking_provider.dart
- organization_test.dart
- voucher_screen.dart
- List
- package:shared_preferences/shared_preferences.dart
- BusinessNotifier
- add_customer_sheet.dart
- late_return_penalty_pos_test.dart
- late_return_penalty_return_workflow_test.dart
- catalog_card_refactor_test.dart
- ui_layout_typography_cleanup_test.dart
- ../../auth/providers/business_provider.dart
- secure_token_storage.dart
- currency_formatter.dart
- device_protection_quarantine_return_test.dart
- booking_rc_261030_0001_late_penalty_bug_fix_test.dart
- .MessageHandler
- unit_test.dart
- int?
- Point
- bookings_queue_overdue_test.dart
- printerProvider
- branch_revenue_and_dashboard_test.dart
- customer_directory_and_governance_test.dart
- organizationProvider
- customerProvider
- navigation_keys.dart
- qris_service.dart
- package:flutter_riverpod/flutter_riverpod.dart
- network_status_provider.dart
- businessProvider
- DashboardRepository
- AuthRepository
- ExpandableInventoryFabState
- _AddBranchBottomSheetState
- _InviteMemberBottomSheetState
- _ManageOrganizationScreenState
- _RentalRulesTabViewState
- assetRepositoryProvider

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 76 edges
2. `BusinessNotifier` - 43 edges
3. `authProvider` - 35 edges
4. `BusinessState` - 29 edges
5. `AuthNotifier` - 28 edges
6. `organizationProvider` - 28 edges
7. `printerProvider` - 24 edges
8. `BookingRepository` - 22 edges
9. `Win32Window` - 21 edges
10. `CashierRepository` - 20 edges

## Surprising Connections (you probably didn't know these)
- `_MockGoogleAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockPasswordAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/dashboard_cleanup_and_navigation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_TestAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_dashboard_refactor_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/payment_method_settings_screen_test.dart → lib/features/auth/providers/auth_provider.dart

## Import Cycles
- None detected.

## Communities (165 total, 55 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.05
Nodes (47): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+39 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.02
Nodes (79): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+71 more)

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
Cohesion: 0.06
Nodes (32): _addonsEnabled, _addressController, branches, _buildCard, _buildPendingResignationBanner, _buildRoleBadge, _buildRoleChoice, businessId (+24 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.04
Nodes (45): additionalHours, addonSubtotal, amountPaid, assetCode, booking, bookingCode, bookingId, branchId (+37 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (32): _accessoriesController, _addPresetRate, _addRateRow, _brandController, _buildPresetChip, _colorController, createState, _descriptionController (+24 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (26): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+18 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "asset_provider.dart"
Cohesion: 0.14
Nodes (12): bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels, fetchProducts, repo (+4 more)

### Community 13 - "main.dart"
Cohesion: 0.10
Nodes (9): networkStatusProvider, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen, _MainShellScreenState (+1 more)

### Community 14 - "notification_provider.dart"
Cohesion: 0.08
Nodes (21): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+13 more)

### Community 15 - "package:flutter/material.dart"
Cohesion: 0.13
Nodes (13): activeShiftData, bookings, build, closedShiftResult, closeShift, fetchBookingDetail, fetchBookings, fetchClosingSummary (+5 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.05
Nodes (32): PrintMode, _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, _addressCtrl, _branchNameCtrl (+24 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.03
Nodes (56): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildAvatarFallback, _buildBranchBar, _buildCatalogView, _buildChip (+48 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.08
Nodes (25): build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading, isSubmitting (+17 more)

### Community 19 - "cashier_screen.dart"
Cohesion: 0.05
Nodes (43): build, _buildActiveShiftTab, _buildCompactFilterChip, _buildCustomDateFilterChip, _buildCustomShiftHistoryDateFilterChip, _buildDateFilterChips, _buildDetailRow, _buildShiftHistoryCard (+35 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.04
Nodes (43): _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile, _buildGopayBadge (+35 more)

### Community 21 - "Win32Window"
Cohesion: 0.14
Nodes (8): RegisterPlugins(), Size, height, width, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.13
Nodes (9): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+1 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.06
Nodes (26): _buildBusinessErrorCard, _buildDailyOperationsGrid, _buildDashboardContent, _buildErrorCard, _buildOnboardingBanner, _buildOperationCard, _buildOverdueAlertCard, _buildQueueCard (+18 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (23): _branchClosingTime, _branchOpeningTime, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard, _buildTimePickerTile, _closingTime (+15 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.07
Nodes (26): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _category, _checklistDefs (+18 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.08
Nodes (26): bizState, build, cashierBookingsProvider, effectiveBranchId, endDate, fetchCurrentShift, isConsolidated, label (+18 more)

### Community 29 - "VoucherRepository"
Cohesion: 0.50
Nodes (4): VoucherRepository, _FakeVoucherRepository, _MockVoucherRepo, MockVoucherRepository

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (26): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, _closeNotesController, _coinController (+18 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.09
Nodes (21): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCategoryRelevant (+13 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.11
Nodes (16): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+8 more)

### Community 34 - "customer_directory_screen.dart"
Cohesion: 0.15
Nodes (9): createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose, _getInitials, initState, _scrollController (+1 more)

### Community 35 - "dock_aware_scaffold.dart"
Cohesion: 0.11
Nodes (15): appBar, backgroundColor, body, bottomSheet, build, DockEdgeInsetsExtension, DockFloatingActionButtonLocation, extra (+7 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.07
Nodes (27): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildCurrentStepBody, _buildStep1Identity, _buildStep2Branch (+19 more)

### Community 41 - "home_dashboard_refactor_test.dart"
Cohesion: 0.07
Nodes (26): build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main, _MockGoogleAuthNotifier (+18 more)

### Community 43 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.03
Nodes (68): AssetRepository, build, _categories, createCategory, fetchCategories, main, _MockCategoryAssetRepo, _MockCategoryBizNotifier (+60 more)

### Community 44 - "notification_item.dart"
Cohesion: 0.11
Nodes (16): actionPayload, actionRoute, affiliate, affiliateId, body, businessId, category, copyWith (+8 more)

### Community 45 - "Booking Management System"
Cohesion: 0.17
Nodes (11): adjustDuration, _client, createRental, exchangeRentalUnit, extendRental, fetchAvailableReplacements, fetchBookingDetail, fetchBookings (+3 more)

### Community 46 - "Authentication & User Session"
Cohesion: 0.07
Nodes (28): approveResignation, cancelResignation, checkSession, _client, createBranch, createBusiness, fetchBranches, fetchBusinesses (+20 more)

### Community 47 - "rentcore_app_bar.dart"
Cohesion: 0.11
Nodes (15): actions, automaticallyImplyLeading, backgroundColor, bottom, build, centerTitle, color, leading (+7 more)

### Community 48 - "status_badge.dart"
Cohesion: 0.11
Nodes (15): backgroundColor, borderColor, borderRadius, build, fontSize, icon, inventory, isLineThrough (+7 more)

### Community 49 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "authProvider"
Cohesion: 0.05
Nodes (47): build, createState, dispose, _emailController, _getEffectiveServerClientId, _handleGoogleSignIn, _login, LoginScreen (+39 more)

### Community 51 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (23): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+15 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.10
Nodes (14): authRepositoryProvider, build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository (+6 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.08
Nodes (20): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, onTabSelected, build, _buildActionKey (+12 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.07
Nodes (24): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _hasValidQrisPayload, _isDynamicQrisEnabled (+16 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.04
Nodes (38): 7, _AdjustmentTarget, assetCode, catName, combined, createState, _currentBookingPage, currentDurationHours (+30 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (43): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+35 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.14
Nodes (12): _addressController, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading, _loadStoreData (+4 more)

### Community 61 - "voucher_management_test.dart"
Cohesion: 0.12
Nodes (15): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+7 more)

### Community 62 - "Asset Transfer Workflow"
Cohesion: 0.18
Nodes (10): approveTransfer, cancelTransfer, _client, createTransfer, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, receiveTransfer (+2 more)

### Community 63 - "Flutter Web Shell Platform"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 64 - "Core API & Network Client"
Cohesion: 0.18
Nodes (7): ApiClient, _baseUrl, currentBaseUrl, dio, init, _instance, updateBaseUrl

### Community 65 - "Voucher & Discount Rules"
Cohesion: 0.20
Nodes (9): _client, createVoucher, deleteVoucher, fetchPrintSlip, fetchVouchers, getVoucher, toggleVoucherStatus, updateVoucher (+1 more)

### Community 66 - "package:flutter/material.dart"
Cohesion: 0.04
Nodes (39): AppTheme, PaymentRepository, PaymentContext, PaymentResult, executePayment, lastContext, mockCategories, mockPaymentMethods (+31 more)

### Community 67 - "Map"
Cohesion: 0.12
Nodes (15): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+7 more)

### Community 68 - "ConsumerState"
Cohesion: 0.09
Nodes (28): DirectRentalScreen, _DirectRentalScreenState, ExchangeWizardScreen, _ExchangeWizardScreenState, ReturnWizardScreen, _ReturnWizardScreenState, _VoidTransactionDialog, _VoidTransactionDialogState (+20 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.07
Nodes (23): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts, AddBranchExpenseModal, _amountController (+15 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.07
Nodes (29): CustomerRepository, build, copyWith, createCustomer, currentPage, CustomerNotifier, customerRepositoryProvider, customers (+21 more)

### Community 71 - "customer_repository.dart"
Cohesion: 0.14
Nodes (9): createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument, _client (+1 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 74 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.11
Nodes (15): authStateOwner, build, businessStateOwner, fetchPaymentMethods, fetchPaymentSettings, hasPayload, _initial, isDynamicQris (+7 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.10
Nodes (19): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+11 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.29
Nodes (6): DockAwareScaffold, DockClearance, FloatingCapsuleDock, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.18
Nodes (5): Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "logout"
Cohesion: 0.22
Nodes (15): build, build, initState, InventoryScreen, _InventoryScreenState, _onUnitsScroll, build, TarifSewaSheet (+7 more)

### Community 128 - "../../core/utils/currency_formatter.dart"
Cohesion: 0.20
Nodes (4): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.12
Nodes (10): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, ExchangeHistorySheet, show (+2 more)

### Community 133 - "staff_resignation_sheet.dart"
Cohesion: 0.15
Nodes (11): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+3 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (16): _buildHeader, _handleRefresh, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState (+8 more)

### Community 135 - "booking_provider.dart"
Cohesion: 0.09
Nodes (28): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+20 more)

### Community 136 - "organization_test.dart"
Cohesion: 0.12
Nodes (16): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+8 more)

### Community 137 - "voucher_screen.dart"
Cohesion: 0.10
Nodes (13): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher, createState, _debounceTimer (+5 more)

### Community 138 - "List"
Cohesion: 0.17
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.12
Nodes (9): MockPrinterDriver, buildTestableWidget, main, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main (+1 more)

### Community 141 - "BusinessNotifier"
Cohesion: 0.06
Nodes (35): AuthState, BusinessNotifier, BusinessState, _TestBusinessNotifier, _FakeBusinessNotifier, build, _initial, main (+27 more)

### Community 143 - "add_customer_sheet.dart"
Cohesion: 0.14
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 144 - "late_return_penalty_pos_test.dart"
Cohesion: 0.12
Nodes (14): build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount (+6 more)

### Community 145 - "late_return_penalty_return_workflow_test.dart"
Cohesion: 0.13
Nodes (14): build, buildTestScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, _initialState, main (+6 more)

### Community 148 - "catalog_card_refactor_test.dart"
Cohesion: 0.17
Nodes (10): build, buildCatalogScreen, fetchCategories, fetchModels, fetchProducts, _initial, main, products (+2 more)

### Community 149 - "ui_layout_typography_cleanup_test.dart"
Cohesion: 0.18
Nodes (7): alerts, build, fetchKpi, fetchVouchers, _FixedBusinessNotifier, main, mockVouchers

### Community 150 - "../../auth/providers/business_provider.dart"
Cohesion: 0.22
Nodes (6): _buildEmbeddedRentalQueue, bizState, dashboardQueueBookingsProvider, dashboardRepositoryProvider, fetchKpi, repo

### Community 151 - "secure_token_storage.dart"
Cohesion: 0.18
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 153 - "currency_formatter.dart"
Cohesion: 0.15
Nodes (9): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+1 more)

### Community 154 - "device_protection_quarantine_return_test.dart"
Cohesion: 0.07
Nodes (22): createState, customer, _getInitials, initState, show, androidBooking, appleBooking, buildScreen (+14 more)

### Community 157 - "booking_rc_261030_0001_late_penalty_bug_fix_test.dart"
Cohesion: 0.14
Nodes (13): bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, _initialState (+5 more)

### Community 160 - "int?"
Cohesion: 0.04
Nodes (52): CashierRepository, PosFilterBranchIdNotifier, _FakeCashierRepoForLatePenalty, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary (+44 more)

### Community 162 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 163 - "bookings_queue_overdue_test.dart"
Cohesion: 0.03
Nodes (73): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState (+65 more)

### Community 164 - "printerProvider"
Cohesion: 0.07
Nodes (31): _printBookingReceipt, _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, CashDrawerShiftModal (+23 more)

### Community 166 - "branch_revenue_and_dashboard_test.dart"
Cohesion: 0.14
Nodes (13): build, changeBranch, _FakeCashierRepository, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main (+5 more)

### Community 167 - "customer_directory_and_governance_test.dart"
Cohesion: 0.18
Nodes (5): createCustomer, dummyCustomers, fetchCustomersPaginated, main, toggleBlacklist

### Community 168 - "organizationProvider"
Cohesion: 0.15
Nodes (13): build, _buildBranchesTab, _buildErrorState, _buildMembersTab, _confirmApproveResignation, _confirmDeactivateMember, initState, _saveRules (+5 more)

### Community 170 - "customerProvider"
Cohesion: 0.22
Nodes (9): build, _buildCustomerList, _buildFilterChip, _onScroll, _onSearchChanged, build, _submit, _handleBlacklistToggle (+1 more)

### Community 173 - "qris_service.dart"
Cohesion: 0.40
Nodes (4): calculateCrc16, generateDynamicQris, isValidQrisPayload, QrisService

### Community 174 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.05
Nodes (41): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+33 more)

### Community 179 - "network_status_provider.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 184 - "businessProvider"
Cohesion: 0.10
Nodes (29): AuthNotifier, checkCurrentSession, login, logout, businessProvider, BookingFilterNotifier, BookingSearchQueryNotifier, _buildBranchSelectorHeader (+21 more)

### Community 185 - "DashboardRepository"
Cohesion: 0.33
Nodes (6): DashboardRepository, _FakeDashboardRepository, _FakeDashboardRepository, _CapturingDashboardRepository, _FakeDashboardRepo, _MockDashboardRepo

### Community 186 - "AuthRepository"
Cohesion: 0.40
Nodes (5): AuthRepository, _FakeAuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakeAuthRepository

### Community 193 - "assetRepositoryProvider"
Cohesion: 0.25
Nodes (8): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, allCatalogModelsProvider, assetRepositoryProvider

## Knowledge Gaps
- **1907 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1902 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2141 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **55 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Point`, `Windows Native Desktop Runner`, `.Create`, `Windows Native Desktop Runner`, `.MessageHandler`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1907 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `Windows Native Desktop Runner` to `Windows Native Desktop Runner`, `Win32Window`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05279034690799397 - nodes in this community are weakly interconnected._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.024691358024691357 - nodes in this community are weakly interconnected._
- **Should `Direct Rental Booking` be split into smaller, more focused modules?**
  _Cohesion score 0.024691358024691357 - nodes in this community are weakly interconnected._