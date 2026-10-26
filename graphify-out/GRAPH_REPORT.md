# Graph Report - rentcore  (2026-10-26)

## Corpus Check
- 156 files · ~144,555 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2581 nodes · 3973 edges · 174 communities (120 shown, 54 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `774fa58c`
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
- auth_provider.dart
- bookings_queue_overdue_test.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- Cashier POS & Register
- Payment Gateway & Processing
- Windows Native Desktop Runner
- Printer Bluetooth Driver Module
- cashier_and_header_standardization_test.dart
- Home Dashboard & Analytics
- BusinessNotifier
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- AuthNotifier
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
- inventory_live_payload_test.dart
- voucher_management_test.dart
- Size
- Inventory & Asset Catalog
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
- logout_and_inventory_detail_test.dart
- payment_page_test.dart
- pos_numpad.dart
- auth_lifecycle_relogin_test.dart
- bookings_screen.dart
- exchange_wizard_screen.dart
- store_profile_screen.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- inventory_empty_state_test.dart
- bookingRepositoryProvider
- businessProvider
- add_branch_expense_modal.dart
- customer_provider.dart
- customer_repository.dart
- store_settings_screen.dart
- ../../../core/utils/currency_formatter.dart
- ../../core/constants/app_colors.dart
- Cashier POS & Register
- ../../core/constants/app_colors.dart
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
- customer_directory_and_governance_test.dart
- late_return_penalty_pos_test.dart
- cashierRepositoryProvider
- printer_settings_screen.dart
- organization_test.dart
- exchange_history_sheet.dart
- staff_resignation_sheet.dart
- notification_provider.dart
- categoriesProvider
- package:flutter_riverpod/flutter_riverpod.dart
- notification_center_test.dart
- voucher_screen.dart
- thermal_printer_service_test.dart
- package:flutter_riverpod/flutter_riverpod.dart
- dashboard_cleanup_and_navigation_test.dart
- booking_provider.dart
- pos_all_branches_filter_test.dart
- add_customer_sheet.dart
- organizationProvider
- businessProvider
- cash_suggestion_helper.dart
- network_status_provider.dart
- notification_center_screen.dart
- ../../auth/providers/business_provider.dart
- _InventoryScreenState
- date_formatter.dart
- currency_formatter.dart
- late_return_penalty_return_workflow_test.dart
- branch_revenue_and_dashboard_test.dart
- authRepositoryProvider
- transfer_provider.dart
- _AddBranchBottomSheetState
- _InviteMemberBottomSheetState
- _ManageOrganizationScreenState
- _RentalRulesTabViewState
- List
- payment_repository.dart
- voucherProvider
- MaterialPageRoute
- assetRepositoryProvider
- transferRepositoryProvider
- unit_test.dart
- bookingRepositoryProvider
- AuthRepository
- navigation_keys.dart
- CustomerNotifier
- DashboardRepository

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 61 edges
2. `authProvider` - 31 edges
3. `BusinessNotifier` - 29 edges
4. `organizationProvider` - 26 edges
5. `printerProvider` - 24 edges
6. `AuthNotifier` - 22 edges
7. `Win32Window` - 21 edges
8. `BusinessState` - 20 edges
9. `cashierRepositoryProvider` - 15 edges
10. `BookingRepository` - 14 edges

## Surprising Connections (you probably didn't know these)
- `_MockAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/staff_resignation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/transfers_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockCategoryBizNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/add_category_workflow_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_overdue_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_search_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (174 total, 54 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.09
Nodes (20): _bookingRepo, _buildDirectionChip, _buildStatusChip, _buildTransferCard, createState, dispose, initState, _invalidateAllInventoryAndTransfers (+12 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.03
Nodes (71): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+63 more)

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
Cohesion: 0.06
Nodes (32): _addonsEnabled, _addressController, branches, _buildCard, _buildPendingResignationBanner, _buildRoleBadge, _buildRoleChoice, businessId (+24 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (31): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, _buildPresetChip, _colorController (+23 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (26): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+18 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "int?"
Cohesion: 0.12
Nodes (15): PosFilterBranchIdNotifier, AssetCategoryFilterNotifier, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState (+7 more)

### Community 13 - "main.dart"
Cohesion: 0.11
Nodes (9): networkStatusProvider, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen, _MainShellScreenState (+1 more)

### Community 14 - "auth_provider.dart"
Cohesion: 0.12
Nodes (9): copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository, updatePassword, updateProfile (+1 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.05
Nodes (43): BusinessState, BookingRepository, _FakeBookingRepository, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState (+35 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.05
Nodes (36): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+28 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.04
Nodes (43): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildDrawerButton, _buildNoBusinessView (+35 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.08
Nodes (25): build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading, isSubmitting (+17 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.06
Nodes (32): _buildStep3FinancialAndAuth, booking, build, _buildBookingPosCard, _buildDateFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController (+24 more)

### Community 20 - "Payment Gateway & Processing"
Cohesion: 0.08
Nodes (25): paymentRepositoryProvider, PaymentContext, _buildSuccessView, _cashReceivedController, _completedResult, createState, dispose, _getBadgeBackgroundColor (+17 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.13
Nodes (6): EnableFullDpiSupportIfAvailable(), Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "cashier_and_header_standardization_test.dart"
Cohesion: 0.08
Nodes (11): build, fetchBookingsForCashier, fetchBranchExpenses, fetchClosingSummary, fetchPaymentMethods, _MockCashierBizNotifier, main, attempts (+3 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.08
Nodes (19): _buildActiveContextBanner, _buildAllClearStatusCard, _buildBusinessErrorCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview (+11 more)

### Community 25 - "BusinessNotifier"
Cohesion: 0.10
Nodes (17): BusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, adjustDuration (+9 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.12
Nodes (12): _adapterReturned, booking, build, _cableReturned, _cameraOk, _conditionGrade, createState, _icloudRemoved (+4 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.09
Nodes (21): bizState, build, currentShiftProvider, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+13 more)

### Community 29 - "AuthNotifier"
Cohesion: 0.19
Nodes (15): AuthNotifier, logout, _buildDateFilterChips, _buildDateFilterRow, posDateRangeProvider, customerSearchQueryProvider, build, _TransfersScreenState (+7 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (28): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, CashDrawerShiftModal, _CashDrawerShiftModalState (+20 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.09
Nodes (20): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCentralBranch (+12 more)

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
Cohesion: 0.12
Nodes (15): _addressCtrl, _BusinessOnboardingDialog, _BusinessOnboardingDialogState, BusinessSelectorSheet, _BusinessSelectorSheetState, _cityCtrl, createState, dispose (+7 more)

### Community 39 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 40 - "inventory_live_payload_test.dart"
Cohesion: 0.03
Nodes (51): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage, AssetRepository (+43 more)

### Community 41 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (15): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+7 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "Inventory & Asset Catalog"
Cohesion: 0.13
Nodes (13): AssetSearchQueryNotifier, bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels, fetchProducts (+5 more)

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
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "authProvider"
Cohesion: 0.08
Nodes (29): build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials, _handleSavePassword, _handleSaveProfile (+21 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.12
Nodes (15): build, createState, dispose, _emailController, _getEffectiveServerClientId, _handleGoogleSignIn, _login, LoginScreen (+7 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "logout_and_inventory_detail_test.dart"
Cohesion: 0.18
Nodes (10): build, fetchBusinesses, fetchCategories, fetchProducts, _initial, logout, main, setActiveContext (+2 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.13
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.12
Nodes (14): VoucherRepository, currentUserEmail, _FakeVoucherRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+6 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.06
Nodes (25): _AdjustmentTarget, createState, _currentBookingPage, currentDurationHours, currentPrice, _debounceTimer, dispose, _DurationOption (+17 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (42): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+34 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.14
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

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

### Community 66 - "inventory_empty_state_test.dart"
Cohesion: 0.14
Nodes (13): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+5 more)

### Community 67 - "bookingRepositoryProvider"
Cohesion: 0.24
Nodes (10): build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged, bookingFilterStatusProvider, bookingSearchQueryProvider (+2 more)

### Community 68 - "businessProvider"
Cohesion: 0.13
Nodes (24): businessProvider, BookingsScreen, _BookingsScreenState, ExchangeWizardScreen, _ExchangeWizardScreenState, ReturnWizardScreen, _ReturnWizardScreenState, _buildBranchSelectorHeader (+16 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (17): AddBranchExpenseModal, _amountController, branchId, build, _categories, createState, dispose, _errorMessage (+9 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.08
Nodes (24): copyWith, createCustomer, currentPage, customers, CustomerSearchQueryNotifier, customerSearchResultsProvider, error, hasMore (+16 more)

### Community 71 - "customer_repository.dart"
Cohesion: 0.20
Nodes (7): createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.12
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.15
Nodes (12): build, _buildDateChip, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen, _FinancialActivityLedgerScreenState (+4 more)

### Community 74 - "../../core/constants/app_colors.dart"
Cohesion: 0.17
Nodes (6): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, onTabSelected

### Community 75 - "Cashier POS & Register"
Cohesion: 0.13
Nodes (14): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+6 more)

### Community 77 - "../../core/constants/app_colors.dart"
Cohesion: 0.20
Nodes (7): createState, customer, CustomerDetailSheet, _CustomerDetailSheetState, _getInitials, initState, show

### Community 79 - "StatelessWidget"
Cohesion: 0.29
Nodes (6): DockAwareScaffold, DockClearance, FloatingCapsuleDock, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - "Windows Native Desktop Runner"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 127 - "customer_directory_and_governance_test.dart"
Cohesion: 0.15
Nodes (7): CustomerRepository, createCustomer, dummyCustomers, fetchCustomersPaginated, main, MockCustomerRepository, toggleBlacklist

### Community 128 - "late_return_penalty_pos_test.dart"
Cohesion: 0.13
Nodes (13): build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount (+5 more)

### Community 129 - "cashierRepositoryProvider"
Cohesion: 0.25
Nodes (8): _executePayment, _fetchAndShowReceipt, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, _submitCloseShift, _submitOpenShift, cashierRepositoryProvider

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.10
Nodes (17): _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, _printPaymentReceipt, build, _buildChoiceChip, _buildConnectionStatusCard (+9 more)

### Community 131 - "organization_test.dart"
Cohesion: 0.12
Nodes (16): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+8 more)

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.17
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 133 - "staff_resignation_sheet.dart"
Cohesion: 0.14
Nodes (11): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+3 more)

### Community 134 - "notification_provider.dart"
Cohesion: 0.14
Nodes (12): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+4 more)

### Community 135 - "categoriesProvider"
Cohesion: 0.40
Nodes (6): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider, build, categoriesProvider

### Community 136 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (20): main, buildTestableWidget, main, build, _initialState, loadOrganization, loadResignations, main (+12 more)

### Community 137 - "notification_center_test.dart"
Cohesion: 0.17
Nodes (9): NotificationNotifier, NotificationState, build, _FakeNotificationNotifier, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead (+1 more)

### Community 138 - "voucher_screen.dart"
Cohesion: 0.10
Nodes (13): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher, createState, _debounceTimer (+5 more)

### Community 139 - "thermal_printer_service_test.dart"
Cohesion: 0.18
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.08
Nodes (15): build, changeBranch, fetchAssets, fetchReadyAssets, initialState, main, recordedBranchRequests, stubbedAssets (+7 more)

### Community 141 - "dashboard_cleanup_and_navigation_test.dart"
Cohesion: 0.07
Nodes (21): AppTheme, AuthState, build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone (+13 more)

### Community 142 - "booking_provider.dart"
Cohesion: 0.15
Nodes (11): bizState, BookingSearchQueryNotifier, build, clear, fetchBookings, fetchReadyAssets, repo, searchQuery (+3 more)

### Community 143 - "pos_all_branches_filter_test.dart"
Cohesion: 0.06
Nodes (29): CashierRepository, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+21 more)

### Community 144 - "add_customer_sheet.dart"
Cohesion: 0.15
Nodes (12): AddCustomerSheet, _AddCustomerSheetState, _addressController, createState, dispose, _emailController, _formKey, _idNumberController (+4 more)

### Community 145 - "organizationProvider"
Cohesion: 0.15
Nodes (13): build, _buildBranchesTab, _buildErrorState, _buildMembersTab, _confirmApproveResignation, _confirmDeactivateMember, initState, _saveRules (+5 more)

### Community 146 - "businessProvider"
Cohesion: 0.47
Nodes (4): BookingFilterNotifier, AssetStatusFilterNotifier, TransferDirectionNotifier, TransferStatusNotifier

### Community 147 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 148 - "network_status_provider.dart"
Cohesion: 0.29
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 149 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (15): _buildHeader, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState, _getActionLabel (+7 more)

### Community 150 - "../../auth/providers/business_provider.dart"
Cohesion: 0.29
Nodes (4): bizState, dashboardRepositoryProvider, fetchKpi, repo

### Community 151 - "_InventoryScreenState"
Cohesion: 0.26
Nodes (14): build, _buildCatalogView, _buildFilterDrawer, _buildUnitsView, initState, _InventoryScreenState, _onUnitsScroll, build (+6 more)

### Community 152 - "date_formatter.dart"
Cohesion: 0.33
Nodes (5): DateFormatter, formatFull, formatRelative, formatShort, formatTime

### Community 153 - "currency_formatter.dart"
Cohesion: 0.29
Nodes (4): CurrencyFormatter, format, _formatter, parse

### Community 154 - "late_return_penalty_return_workflow_test.dart"
Cohesion: 0.15
Nodes (11): buildTestScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, main, overdueBooking, processReturn (+3 more)

### Community 155 - "branch_revenue_and_dashboard_test.dart"
Cohesion: 0.15
Nodes (12): build, changeBranch, fetchBookingsForCashier, fetchClosingSummary, fetchKpi, initialState, main, recordedBookingsBranchRequests (+4 more)

### Community 156 - "authRepositoryProvider"
Cohesion: 0.40
Nodes (5): authRepositoryProvider, build, build, _saveStoreProfile, build

### Community 157 - "transfer_provider.dart"
Cohesion: 0.17
Nodes (10): branchRecipientsProvider, build, direction, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, repo, setDirection (+2 more)

### Community 162 - "List"
Cohesion: 0.17
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 163 - "payment_repository.dart"
Cohesion: 0.18
Nodes (5): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods, PaymentRepository

### Community 164 - "voucherProvider"
Cohesion: 0.20
Nodes (10): checkCurrentSession, login, build, _confirmDelete, _submit, VoucherFormDialog, _VoucherFormDialogState, build (+2 more)

### Community 165 - "MaterialPageRoute"
Cohesion: 0.20
Nodes (9): _buildPosTerminalTab, cashierBookingsProvider, build, build, _buildQuickActionsCard, _printPreviewReceipt, build, build (+1 more)

### Community 166 - "assetRepositoryProvider"
Cohesion: 0.20
Nodes (10): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, _EditAssetSheet, _EditAssetSheetState (+2 more)

### Community 167 - "transferRepositoryProvider"
Cohesion: 0.22
Nodes (9): _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer, _InitiateTransferForm, _InitiateTransferFormState, _loadRecipients, _showRejectTransferDialog, destinationAffiliatesProvider (+1 more)

### Community 169 - "bookingRepositoryProvider"
Cohesion: 0.33
Nodes (6): _showDurationAdjustmentDialog, _executeExchangeSubmission, _loadAvailableReplacements, _processReturn, bookingRepositoryProvider, _processOverdueReturn

### Community 170 - "AuthRepository"
Cohesion: 0.40
Nodes (5): AuthRepository, _FakeAuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakeAuthRepository

### Community 172 - "CustomerNotifier"
Cohesion: 0.50
Nodes (4): build, CustomerNotifier, customerRepositoryProvider, CustomerState

### Community 173 - "DashboardRepository"
Cohesion: 0.50
Nodes (4): DashboardRepository, _FakeDashboardRepository, _FakeDashboardRepository, _CapturingDashboardRepository

## Knowledge Gaps
- **1610 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1605 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1837 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **54 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1610 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `AuthRepository` connect `AuthRepository` to `business_provider.dart`, `Organization & Branch Management`, `Authentication & User Session`, `auth_provider.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.08695652173913043 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `businessProvider` to `transfers_screen.dart`, `printer_settings_screen.dart`, `Direct Rental Booking`, `organization_test.dart`, `categoriesProvider`, `int?`, `booking_provider.dart`, `Receipt Customization Settings`, `businessProvider`, `Voucher & Discount Rules`, `notification_center_screen.dart`, `_InventoryScreenState`, `Home Dashboard & Analytics`, `Cashier POS & Register`, `AuthNotifier`, `authRepositoryProvider`, `business_provider.dart`, `voucherProvider`, `MaterialPageRoute`, `assetRepositoryProvider`, `transferRepositoryProvider`, `business_selector_sheet.dart`, `Inventory & Asset Catalog`, `CustomerNotifier`, `authProvider`, `store_profile_screen.dart`, `bookingRepositoryProvider`, `store_settings_screen.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.0273972602739726 - nodes in this community are weakly interconnected._