# Graph Report - rentcore  (2026-10-28)

## Corpus Check
- 162 files · ~154,566 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2717 nodes · 4203 edges · 165 communities (114 shown, 51 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `055819c3`
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
- int?
- main.dart
- AuthNotifier
- bookings_queue_overdue_test.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- Cashier POS & Register
- Payment Gateway & Processing
- Windows Native Desktop Runner
- Printer Bluetooth Driver Module
- thermal_receipt_preview_dialog.dart
- Home Dashboard & Analytics
- shift_schedule_screen.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- asset_provider.dart
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- customer_directory_screen.dart
- dock_aware_scaffold.dart
- inventory_editing_test.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- Win32Window
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- voucher_management_test.dart
- Size
- late_return_penalty_pos_test.dart
- notification_item.dart
- Booking Management System
- Authentication & User Session
- rentcore_app_bar.dart
- status_badge.dart
- Windows Native Desktop Runner
- authProvider
- login_screen.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- add_customer_sheet.dart
- payment_page_test.dart
- pos_numpad.dart
- payment_method_settings_screen.dart
- bookings_screen.dart
- exchange_wizard_screen.dart
- store_profile_screen.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- inventory_empty_state_test.dart
- customer_directory_and_governance_test.dart
- ConsumerState
- add_branch_expense_modal.dart
- customer_provider.dart
- customer_repository.dart
- store_settings_screen.dart
- ../../../core/utils/currency_formatter.dart
- bookingRepositoryProvider
- Cashier POS & Register
- branch_aware_booking_test.dart
- Windows Native Desktop Runner
- StatelessWidget
- Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?
- Windows Native Desktop Runner
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
- ../../core/constants/app_colors.dart
- pos_all_branches_filter_test.dart
- notification_center_test.dart
- printer_settings_screen.dart
- notification_provider.dart
- exchange_history_sheet.dart
- staff_resignation_sheet.dart
- notification_center_screen.dart
- printerProvider
- package:flutter/material.dart
- inventory_live_payload_test.dart
- voucher_screen.dart
- thermal_printer_service_test.dart
- package:flutter_riverpod/flutter_riverpod.dart
- BusinessNotifier
- booking_provider.dart
- cashierRepositoryProvider
- businessProvider
- List
- voucherProvider
- cash_suggestion_helper.dart
- bookingFilterStatusProvider
- assetRepositoryProvider
- ../../auth/providers/business_provider.dart
- dashboard_cleanup_and_navigation_test.dart
- voucher_detail_dialog.dart
- currency_formatter.dart
- Map
- package:flutter_test/flutter_test.dart
- _CashierScreenState
- staff_resignation_test.dart
- printer_settings_screen_test.dart
- unit_test.dart
- paymentMethodsProvider
- _DirectRentalScreenState
- PosTransactionDetailSheet
- payment_repository.dart
- navigation_keys.dart

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 70 edges
2. `authProvider` - 35 edges
3. `BusinessNotifier` - 32 edges
4. `organizationProvider` - 28 edges
5. `AuthNotifier` - 24 edges
6. `printerProvider` - 24 edges
7. `BusinessState` - 22 edges
8. `Win32Window` - 21 edges
9. `cashierRepositoryProvider` - 19 edges
10. `BookingRepository` - 15 edges

## Surprising Connections (you probably didn't know these)
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/staff_resignation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/transfers_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockCategoryBizNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/add_category_workflow_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_overdue_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (165 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.05
Nodes (46): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+38 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.03
Nodes (77): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+69 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.03
Nodes (62): _addonSubtotal, _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildAddonsSelectionSection, _buildStep1UnitAndDuration, _buildStep2CustomerAndCollateral (+54 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.06
Nodes (17): Cocoa, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate, SceneDelegate (+9 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.05
Nodes (47): _AddBranchBottomSheet, _AddBranchBottomSheetState, _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard (+39 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

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
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "int?"
Cohesion: 0.13
Nodes (14): PosFilterBranchIdNotifier, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState, _initialValue (+6 more)

### Community 13 - "main.dart"
Cohesion: 0.07
Nodes (15): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, networkStatusProvider, setOffline, setOnline, build (+7 more)

### Community 14 - "AuthNotifier"
Cohesion: 0.16
Nodes (23): AuthNotifier, logout, customerSearchQueryProvider, build, build, _buildCatalogView, _buildFilterDrawer, _buildUnitsView (+15 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.03
Nodes (54): AppTheme, BookingRepository, _FakeBookingRepository, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState (+46 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (29): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+21 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.04
Nodes (48): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildDrawerButton, _buildNoBusinessView (+40 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): VoucherRepository, build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading (+20 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.06
Nodes (27): booking, _buildBookingPosCard, _buildDateFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController, createState, dispose (+19 more)

### Community 20 - "Payment Gateway & Processing"
Cohesion: 0.07
Nodes (25): PaymentContext, _buildSuccessView, _cashReceivedController, _completedResult, createState, dispose, _getBadgeBackgroundColor, _getBadgeTextColor (+17 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.13
Nodes (6): EnableFullDpiSupportIfAvailable(), Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.13
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.08
Nodes (19): _buildActiveContextBanner, _buildAllClearStatusCard, _buildBusinessErrorCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview (+11 more)

### Community 25 - "shift_schedule_screen.dart"
Cohesion: 0.08
Nodes (26): shiftScheduleProvider, _branchClosingTime, _branchOpeningTime, build, _buildBranchOverrideCard, _buildMetricItem, _buildScheduleSettingsCard, _buildStatusCard (+18 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.10
Nodes (17): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _conditionGrade, createState (+9 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.08
Nodes (23): bizState, branchId, build, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+15 more)

### Community 29 - "asset_provider.dart"
Cohesion: 0.14
Nodes (12): bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels, fetchProducts, repo (+4 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (28): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, CashDrawerShiftModal, _CashDrawerShiftModalState (+20 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.05
Nodes (35): authRepositoryProvider, build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository (+27 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.09
Nodes (18): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+10 more)

### Community 34 - "customer_directory_screen.dart"
Cohesion: 0.11
Nodes (18): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+10 more)

### Community 35 - "dock_aware_scaffold.dart"
Cohesion: 0.11
Nodes (15): appBar, backgroundColor, body, bottomSheet, build, DockEdgeInsetsExtension, DockFloatingActionButtonLocation, extra (+7 more)

### Community 36 - "inventory_editing_test.dart"
Cohesion: 0.13
Nodes (14): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+6 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.07
Nodes (25): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildCurrentStepBody, _buildStep1Identity, _buildStep2Branch (+17 more)

### Community 39 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 40 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.04
Nodes (34): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage, build (+26 more)

### Community 41 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (15): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+7 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "late_return_penalty_pos_test.dart"
Cohesion: 0.06
Nodes (32): CashierRepository, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+24 more)

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
Nodes (26): build, _handleGoogleSignIn, build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials (+18 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.13
Nodes (13): createState, dispose, _emailController, _getEffectiveServerClientId, _login, LoginScreen, _LoginScreenState, _obscurePassword (+5 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (22): booking, bookingId, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer, createState (+14 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "add_customer_sheet.dart"
Cohesion: 0.14
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.05
Nodes (32): main, attempts, main, voidTransaction, adjustDuration, build, businessState, createRental (+24 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.12
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.09
Nodes (22): paymentSettingsProvider, _bankTransferEnabled, build, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled (+14 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.06
Nodes (25): _AdjustmentTarget, createState, _currentBookingPage, currentDurationHours, currentPrice, _debounceTimer, dispose, _DurationOption (+17 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (44): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+36 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

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
Cohesion: 0.14
Nodes (12): ApiClient, _client, fetchKpi, _client, createVoucher, deleteVoucher, fetchPrintSlip, fetchVouchers (+4 more)

### Community 66 - "inventory_empty_state_test.dart"
Cohesion: 0.13
Nodes (14): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+6 more)

### Community 67 - "customer_directory_and_governance_test.dart"
Cohesion: 0.18
Nodes (5): createCustomer, dummyCustomers, fetchCustomersPaginated, main, toggleBlacklist

### Community 68 - "ConsumerState"
Cohesion: 0.20
Nodes (12): CustomerDetailSheet, _CustomerDetailSheetState, _InviteMemberBottomSheet, _InviteMemberBottomSheetState, ManageOrganizationScreen, _ManageOrganizationScreenState, _RentalRulesTabView, _RentalRulesTabViewState (+4 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (18): AddBranchExpenseModal, _AddBranchExpenseModalState, _amountController, branchId, build, _categories, createState, dispose (+10 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.07
Nodes (26): build, copyWith, createCustomer, currentPage, customerRepositoryProvider, customers, CustomerSearchQueryNotifier, customerSearchResultsProvider (+18 more)

### Community 71 - "customer_repository.dart"
Cohesion: 0.17
Nodes (9): createCustomer, CustomerRepository, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument (+1 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.13
Nodes (16): _buildDateFilterChips, build, _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState, dispose (+8 more)

### Community 74 - "bookingRepositoryProvider"
Cohesion: 0.33
Nodes (6): _showDurationAdjustmentDialog, _executeExchangeSubmission, _loadAvailableReplacements, _processReturn, bookingRepositoryProvider, _processOverdueReturn

### Community 75 - "Cashier POS & Register"
Cohesion: 0.11
Nodes (18): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+10 more)

### Community 77 - "branch_aware_booking_test.dart"
Cohesion: 0.10
Nodes (19): AssetRepository, _MockCategoryAssetRepo, _FakeAssetRepository, build, changeBranch, _FakeAssetRepository, fetchAssets, fetchReadyAssets (+11 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.29
Nodes (6): DockAwareScaffold, DockClearance, FloatingCapsuleDock, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - "Windows Native Desktop Runner"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 127 - "../../core/constants/app_colors.dart"
Cohesion: 0.15
Nodes (9): build, onAddNewModel, onSelectProduct, TarifSewaSheet, productsProvider, build, _buildDockItem, currentIndex (+1 more)

### Community 128 - "pos_all_branches_filter_test.dart"
Cohesion: 0.17
Nodes (11): build, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastBookingsAllBranches, lastBookingsBranchId, lastClosingAllBranches (+3 more)

### Community 129 - "notification_center_test.dart"
Cohesion: 0.14
Nodes (9): NotificationNotifier, NotificationState, build, _FakeNotificationNotifier, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead (+1 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.18
Nodes (7): _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, PrinterSettingsScreen, _PrinterSettingsScreenState

### Community 131 - "notification_provider.dart"
Cohesion: 0.14
Nodes (12): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+4 more)

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.15
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 133 - "staff_resignation_sheet.dart"
Cohesion: 0.15
Nodes (12): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+4 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (15): _buildHeader, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState, _getActionLabel (+7 more)

### Community 135 - "printerProvider"
Cohesion: 0.12
Nodes (17): _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, build, build, _printPaymentReceipt, build (+9 more)

### Community 136 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (16): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+8 more)

### Community 137 - "inventory_live_payload_test.dart"
Cohesion: 0.14
Nodes (13): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+5 more)

### Community 138 - "voucher_screen.dart"
Cohesion: 0.18
Nodes (8): createState, _debounceTimer, dispose, _isSearchExpanded, _searchController, _showThermalSlipModal, VoucherScreen, _VoucherScreenState

### Community 139 - "thermal_printer_service_test.dart"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.05
Nodes (35): AuthRepository, currentUserEmail, _FakeAuthRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+27 more)

### Community 141 - "BusinessNotifier"
Cohesion: 0.07
Nodes (26): AuthState, BusinessNotifier, BusinessState, _ActiveBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, build (+18 more)

### Community 142 - "booking_provider.dart"
Cohesion: 0.17
Nodes (10): bizState, build, clear, fetchBookings, fetchReadyAssets, repo, searchQuery, setFilter (+2 more)

### Community 143 - "cashierRepositoryProvider"
Cohesion: 0.20
Nodes (10): _executePayment, _fetchAndShowReceipt, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, _submitCloseShift, _submitOpenShift, cashierRepositoryProvider (+2 more)

### Community 144 - "businessProvider"
Cohesion: 0.29
Nodes (10): businessProvider, BookingFilterNotifier, BookingSearchQueryNotifier, CustomerNotifier, CustomerState, AssetCategoryFilterNotifier, AssetSearchQueryNotifier, AssetStatusFilterNotifier (+2 more)

### Community 145 - "List"
Cohesion: 0.17
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 146 - "voucherProvider"
Cohesion: 0.17
Nodes (11): checkCurrentSession, login, ExchangeHistorySheet, build, _confirmDelete, VoucherDetailDialog, _submit, build (+3 more)

### Community 147 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 148 - "bookingFilterStatusProvider"
Cohesion: 0.23
Nodes (12): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+4 more)

### Community 149 - "assetRepositoryProvider"
Cohesion: 0.17
Nodes (12): AddProductSheet, _AddProductSheetState, _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard (+4 more)

### Community 150 - "../../auth/providers/business_provider.dart"
Cohesion: 0.14
Nodes (11): DashboardRepository, build, HomeScreen, bizState, dashboardKpiProvider, dashboardRepositoryProvider, fetchKpi, repo (+3 more)

### Community 151 - "dashboard_cleanup_and_navigation_test.dart"
Cohesion: 0.17
Nodes (9): build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main, updatePassword (+1 more)

### Community 152 - "voucher_detail_dialog.dart"
Cohesion: 0.20
Nodes (6): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher

### Community 153 - "currency_formatter.dart"
Cohesion: 0.15
Nodes (9): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+1 more)

### Community 154 - "Map"
Cohesion: 0.06
Nodes (26): createState, customer, _getInitials, initState, show, androidBooking, appleBooking, buildScreen (+18 more)

### Community 155 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (24): build, changeBranch, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main, recordedBookingsBranchRequests (+16 more)

### Community 156 - "_CashierScreenState"
Cohesion: 0.22
Nodes (10): _buildBranchSelectorHeader, _buildClosingShiftTab, _buildPosTerminalTab, CashierScreen, _CashierScreenState, _showBranchFilterModal, _submit, cashierBookingsProvider (+2 more)

### Community 157 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 160 - "paymentMethodsProvider"
Cohesion: 0.33
Nodes (6): _buildStep3FinancialAndAuth, build, _PosPaymentModalSheet, _PosPaymentModalSheetState, paymentMethodsProvider, build

### Community 161 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

### Community 162 - "PosTransactionDetailSheet"
Cohesion: 0.67
Nodes (3): build, PosTransactionDetailSheet, bookingDetailProvider

### Community 163 - "payment_repository.dart"
Cohesion: 0.15
Nodes (7): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods, PaymentRepository, paymentRepositoryProvider, _processPayment

## Knowledge Gaps
- **1708 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1703 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1939 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1708 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `businessProvider` to `transfers_screen.dart`, `Direct Rental Booking`, `staff_resignation_sheet.dart`, `notification_center_screen.dart`, `printerProvider`, `Inventory & Asset Catalog`, `package:flutter/material.dart`, `voucher_screen.dart`, `int?`, `AuthNotifier`, `booking_provider.dart`, `Receipt Customization Settings`, `voucherProvider`, `Voucher & Discount Rules`, `bookingFilterStatusProvider`, `assetRepositoryProvider`, `../../auth/providers/business_provider.dart`, `Home Dashboard & Analytics`, `shift_schedule_screen.dart`, `Rental Return Processing`, `Cashier POS & Register`, `_CashierScreenState`, `asset_provider.dart`, `business_provider.dart`, `_DirectRentalScreenState`, `business_selector_sheet.dart`, `authProvider`, `payment_method_settings_screen.dart`, `store_profile_screen.dart`, `ConsumerState`, `add_branch_expense_modal.dart`, `customer_provider.dart`, `store_settings_screen.dart`?**
  _High betweenness centrality (0.014) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05411764705882353 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `Windows Native Desktop Runner` to `Windows Native Desktop Runner`, `Win32Window`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.02531645569620253 - nodes in this community are weakly interconnected._