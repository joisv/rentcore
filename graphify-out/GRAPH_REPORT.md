# Graph Report - rentcore  (2026-10-23)

## Corpus Check
- 141 files · ~126,199 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2275 nodes · 3450 edges · 146 communities (95 shown, 51 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c1377906`
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
- thermal_receipt_preview_dialog.dart
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
- package:flutter/material.dart
- Home Dashboard & Analytics
- voucher_management_test.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- logout
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- voucher_screen.dart
- dock_aware_scaffold.dart
- inventory_editing_test.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- Win32Window
- inventory_empty_state_test.dart
- BusinessNotifier
- Size
- Inventory & Asset Catalog
- inventory_live_payload_test.dart
- Booking Management System
- Authentication & User Session
- rentcore_app_bar.dart
- status_badge.dart
- Windows Native Desktop Runner
- authProvider
- login_screen.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- booking_provider.dart
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- pos_numpad.dart
- auth_provider.dart
- late_return_penalty_pos_test.dart
- exchange_wizard_screen.dart
- store_profile_screen.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- expandable_inventory_fab_test.dart
- rental_addons_and_policies_test.dart
- ConsumerState
- add_branch_expense_modal.dart
- Customer Profile Management
- ../../../core/constants/api_constants.dart
- store_settings_screen.dart
- ../../../core/utils/currency_formatter.dart
- paymentMethodsProvider
- Cashier POS & Register
- auth_lifecycle_relogin_test.dart
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
- printer_settings_screen_test.dart
- pos_revenue_consolidation_widget_test.dart
- AuthNotifier
- printer_settings_screen.dart
- pos_revenue_consolidation_widget_test.dart
- exchange_history_sheet.dart
- ../../auth/providers/business_provider.dart
- _CashierScreenState
- secure_token_storage.dart
- ExpandableInventoryFabState
- cashierRepositoryProvider
- assetRepositoryProvider
- thermal_printer_service_test.dart
- AuthRepository
- MaterialPageRoute
- _DirectRentalScreenState
- HomeScreen
- string
- navigation_keys.dart

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 41 edges
2. `authProvider` - 29 edges
3. `BusinessNotifier` - 25 edges
4. `printerProvider` - 24 edges
5. `AuthNotifier` - 21 edges
6. `Win32Window` - 21 edges
7. `organizationProvider` - 19 edges
8. `BusinessState` - 17 edges
9. `cashierRepositoryProvider` - 15 edges
10. `logout` - 13 edges

## Surprising Connections (you probably didn't know these)
- `_MockCategoryBizNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/add_category_workflow_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_overdue_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/branch_aware_booking_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/branch_revenue_and_dashboard_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/cash_payment_suggestion_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (146 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.06
Nodes (45): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+37 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.03
Nodes (66): ApiConstants, approveExpense, approveTransfer, assetAvailability, assetModels, assets, availableReplacements, bookingDetail (+58 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.03
Nodes (60): _addonSubtotal, _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildAddonsSelectionSection, _buildStep1UnitAndDuration, _buildStep2CustomerAndCollateral (+52 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.06
Nodes (17): Cocoa, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate, SceneDelegate (+9 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.05
Nodes (50): _AddBranchBottomSheet, _AddBranchBottomSheetState, _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard (+42 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.07
Nodes (29): _accessoriesController, _addPresetRate, _addRateRow, _brandController, build, _buildPresetChip, _colorController, createState (+21 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.05
Nodes (37): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+29 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.13
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 13 - "main.dart"
Cohesion: 0.07
Nodes (15): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, networkStatusProvider, setOffline, setOnline, build (+7 more)

### Community 14 - "AuthNotifier"
Cohesion: 0.09
Nodes (19): AuthState, BusinessNotifier, BusinessState, _MockBizNotifier, build, _initial, main, _StaticBusinessNotifier (+11 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.05
Nodes (39): BookingRepository, _FakeBookingRepository, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState, lastAllBranches (+31 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (26): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+18 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.05
Nodes (36): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildDrawerButton, _buildNoBusinessView (+28 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): VoucherRepository, build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading (+20 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.06
Nodes (25): booking, _buildBookingPosCard, _buildDateFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController, createState, dispose (+17 more)

### Community 20 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (30): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods, PaymentRepository, paymentRepositoryProvider, PaymentContext, _buildSuccessView (+22 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.13
Nodes (6): EnableFullDpiSupportIfAvailable(), Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "package:flutter/material.dart"
Cohesion: 0.06
Nodes (25): AppTheme, main, attempts, main, voidTransaction, build, businessState, createRental (+17 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.09
Nodes (18): _buildActiveContextBanner, _buildAllClearStatusCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview, _buildKpiCard (+10 more)

### Community 25 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (15): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+7 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.08
Nodes (18): _ExtensionOption, hours, label, price, _adapterReturned, booking, build, _cableReturned (+10 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.09
Nodes (21): bizState, build, currentShiftProvider, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+13 more)

### Community 29 - "logout"
Cohesion: 0.25
Nodes (15): logout, build, _buildCatalogView, _buildFilterDrawer, _buildUnitsView, initState, _InventoryScreenState, build (+7 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (26): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, _closeNotesController, _coinController (+18 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.08
Nodes (22): branches, businessId, businessName, copyWith, createBranch, error, inviteMember, isLoading (+14 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.10
Nodes (19): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCentralBranch (+11 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.10
Nodes (16): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+8 more)

### Community 34 - "voucher_screen.dart"
Cohesion: 0.08
Nodes (21): checkCurrentSession, login, branches, build, _buildDetailRow, _confirmDelete, isOwner, onPrintThermal (+13 more)

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
Cohesion: 0.12
Nodes (14): _addressCtrl, _BusinessOnboardingDialog, _BusinessOnboardingDialogState, BusinessSelectorSheet, _BusinessSelectorSheetState, _cityCtrl, createState, dispose (+6 more)

### Community 39 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 40 - "inventory_empty_state_test.dart"
Cohesion: 0.08
Nodes (23): AssetRepository, _MockCategoryAssetRepo, _FakeAssetRepository, _FakeAssetRepository, _MockAssetRepo, _TrackingAssetRepository, assetsToReturn, baseBusinessState (+15 more)

### Community 41 - "BusinessNotifier"
Cohesion: 0.09
Nodes (18): build, changeBranch, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main, recordedBookingsBranchRequests (+10 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "Inventory & Asset Catalog"
Cohesion: 0.13
Nodes (13): AssetSearchQueryNotifier, bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels, fetchProducts (+5 more)

### Community 44 - "inventory_live_payload_test.dart"
Cohesion: 0.14
Nodes (13): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+5 more)

### Community 45 - "Booking Management System"
Cohesion: 0.14
Nodes (12): ApiClient, _client, createRental, exchangeRentalUnit, extendRental, fetchAvailableReplacements, fetchBookingDetail, fetchBookings (+4 more)

### Community 46 - "Authentication & User Session"
Cohesion: 0.08
Nodes (23): checkSession, _client, createBranch, createBusiness, fetchBranches, fetchBusinesses, fetchMembers, fetchRentalRules (+15 more)

### Community 47 - "rentcore_app_bar.dart"
Cohesion: 0.11
Nodes (15): actions, automaticallyImplyLeading, backgroundColor, bottom, build, centerTitle, color, leading (+7 more)

### Community 48 - "status_badge.dart"
Cohesion: 0.11
Nodes (15): backgroundColor, borderColor, borderRadius, build, fontSize, icon, inventory, isLineThrough (+7 more)

### Community 49 - "Windows Native Desktop Runner"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "authProvider"
Cohesion: 0.08
Nodes (27): build, _handleGoogleSignIn, _login, build, _confirmPasswordController, createState, _currentPasswordController, dispose (+19 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.15
Nodes (10): createState, dispose, _emailController, _getEffectiveServerClientId, _obscurePassword, _passwordController, _quickFill, _showConfigGoogleClientIdDialog (+2 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.07
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (15): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+7 more)

### Community 54 - "booking_provider.dart"
Cohesion: 0.12
Nodes (18): BookingsScreen, build, _buildFilterChip, _showExtendDialog, _executeExchangeSubmission, _loadAvailableReplacements, _processReturn, bizState (+10 more)

### Community 55 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.09
Nodes (14): build, fetchBusinesses, fetchCategories, fetchProducts, _initial, logout, main, setActiveContext (+6 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.08
Nodes (20): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, onTabSelected, build, _buildActionKey (+12 more)

### Community 57 - "auth_provider.dart"
Cohesion: 0.10
Nodes (14): authRepositoryProvider, build, copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository (+6 more)

### Community 58 - "late_return_penalty_pos_test.dart"
Cohesion: 0.13
Nodes (13): build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount (+5 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (42): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+34 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.10
Nodes (21): businessProvider, _proceedToPayment, _showReturnSuccessDialog, _buildBusinessErrorCard, _addressController, build, createState, dispose (+13 more)

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

### Community 66 - "expandable_inventory_fab_test.dart"
Cohesion: 0.05
Nodes (28): build, _categories, createCategory, fetchCategories, main, _MockCategoryBizNotifier, build, fetchBookingsForCashier (+20 more)

### Community 67 - "rental_addons_and_policies_test.dart"
Cohesion: 0.13
Nodes (15): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+7 more)

### Community 68 - "ConsumerState"
Cohesion: 0.21
Nodes (11): LoginScreen, _LoginScreenState, ExchangeWizardScreen, _ExchangeWizardScreenState, CashDrawerShiftModal, _CashDrawerShiftModalState, AddProductSheet, _AddProductSheetState (+3 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.07
Nodes (24): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts, AddBranchExpenseModal, _AddBranchExpenseModalState (+16 more)

### Community 70 - "Customer Profile Management"
Cohesion: 0.20
Nodes (8): CustomerRepository, build, customerRepositoryProvider, customerSearchResultsProvider, query, repo, searchCustomers, setQuery

### Community 71 - "../../../core/constants/api_constants.dart"
Cohesion: 0.25
Nodes (5): _dio, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.12
Nodes (7): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.13
Nodes (15): _buildDateFilterChips, build, _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState, dispose (+7 more)

### Community 74 - "paymentMethodsProvider"
Cohesion: 0.33
Nodes (6): _buildStep3FinancialAndAuth, build, _PosPaymentModalSheet, _PosPaymentModalSheetState, paymentMethodsProvider, build

### Community 75 - "Cashier POS & Register"
Cohesion: 0.13
Nodes (14): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+6 more)

### Community 77 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.14
Nodes (11): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+3 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.29
Nodes (6): DockAwareScaffold, DockClearance, FloatingCapsuleDock, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - "Windows Native Desktop Runner"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 128 - "pos_revenue_consolidation_widget_test.dart"
Cohesion: 0.06
Nodes (28): CashierRepository, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+20 more)

### Community 129 - "AuthNotifier"
Cohesion: 0.11
Nodes (16): AuthNotifier, customerSearchQueryProvider, build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone (+8 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.11
Nodes (16): _printExchangeReceipt, _printExchangeReceipt, _showClosingPrintDialog, _printPaymentReceipt, build, _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection (+8 more)

### Community 131 - "pos_revenue_consolidation_widget_test.dart"
Cohesion: 0.15
Nodes (12): build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState, _initialValue, lastEndDate (+4 more)

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.12
Nodes (10): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, ExchangeHistorySheet, show (+2 more)

### Community 133 - "../../auth/providers/business_provider.dart"
Cohesion: 0.18
Nodes (8): DashboardRepository, bizState, dashboardRepositoryProvider, fetchKpi, repo, _FakeDashboardRepository, _FakeDashboardRepository, _CapturingDashboardRepository

### Community 134 - "_CashierScreenState"
Cohesion: 0.22
Nodes (10): _buildBranchSelectorHeader, _buildClosingShiftTab, _buildPosTerminalTab, CashierScreen, _CashierScreenState, _showBranchFilterModal, _submit, cashierBookingsProvider (+2 more)

### Community 135 - "secure_token_storage.dart"
Cohesion: 0.18
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 137 - "cashierRepositoryProvider"
Cohesion: 0.25
Nodes (8): _executePayment, _fetchAndShowReceipt, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, _submitCloseShift, _submitOpenShift, cashierRepositoryProvider

### Community 138 - "assetRepositoryProvider"
Cohesion: 0.20
Nodes (10): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, _EditAssetSheet, _EditAssetSheetState (+2 more)

### Community 139 - "thermal_printer_service_test.dart"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "AuthRepository"
Cohesion: 0.50
Nodes (4): AuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakeAuthRepository

### Community 141 - "MaterialPageRoute"
Cohesion: 0.25
Nodes (7): _buildHeader, build, _buildQuickActionsCard, _printPreviewReceipt, build, build, main

### Community 142 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

### Community 143 - "HomeScreen"
Cohesion: 0.67
Nodes (3): build, HomeScreen, dashboardKpiProvider

### Community 146 - "string"
Cohesion: 0.27
Nodes (7): BookingFilterNotifier, PosFilterBranchIdNotifier, CustomerSearchQueryNotifier, AssetCategoryFilterNotifier, AssetStatusFilterNotifier, TransferStatusNotifier, _TestPosFilterBranchIdNotifier

## Knowledge Gaps
- **1411 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1406 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1620 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.021) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1411 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `AssetRepository` connect `inventory_empty_state_test.dart` to `Inventory & Asset Catalog`, `Inventory & Asset Catalog`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05551020408163265 - nodes in this community are weakly interconnected._
- **Why does `AuthRepository` connect `AuthRepository` to `business_provider.dart`, `auth_provider.dart`, `Authentication & User Session`, `Organization & Branch Management`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.029411764705882353 - nodes in this community are weakly interconnected._