# Graph Report - rentcore  (2026-10-26)

## Corpus Check
- 151 files · ~138,453 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2486 nodes · 3811 edges · 157 communities (106 shown, 51 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e2e99982`
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
- auth_provider.dart
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
- package:rentcore_mobile/features/auth/providers/business_provider.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- logout
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- int?
- dock_aware_scaffold.dart
- inventory_editing_test.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- Win32Window
- package:flutter_test/flutter_test.dart
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
- package:flutter_test/flutter_test.dart
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
- ConsumerState
- add_branch_expense_modal.dart
- Customer Profile Management
- core/network/api_client.dart
- store_settings_screen.dart
- ../../../core/utils/currency_formatter.dart
- ../../core/constants/app_colors.dart
- Cashier POS & Register
- transfer_provider.dart
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
- paginated_result.dart
- cashier_and_header_standardization_test.dart
- cashierRepositoryProvider
- printer_settings_screen.dart
- organization_test.dart
- exchange_history_sheet.dart
- staff_resignation_sheet.dart
- notification_provider.dart
- _TransfersScreenState
- unit_test.dart
- printer_settings_screen_test.dart
- voucher_screen.dart
- thermal_printer_service_test.dart
- package:flutter_riverpod/flutter_riverpod.dart
- dashboard_cleanup_and_navigation_test.dart
- booking_provider.dart
- pos_all_branches_filter_test.dart
- AuthNotifier
- paymentMethodsProvider
- businessProvider
- cash_suggestion_helper.dart
- printerProvider
- notification_center_screen.dart
- navigation_keys.dart
- assetRepositoryProvider
- date_formatter.dart
- currency_formatter.dart
- _CashierScreenState
- AuthRepository
- authRepositoryProvider

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 59 edges
2. `authProvider` - 31 edges
3. `BusinessNotifier` - 28 edges
4. `organizationProvider` - 26 edges
5. `printerProvider` - 24 edges
6. `AuthNotifier` - 22 edges
7. `Win32Window` - 21 edges
8. `BusinessState` - 20 edges
9. `cashierRepositoryProvider` - 15 edges
10. `logout` - 13 edges

## Surprising Connections (you probably didn't know these)
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockCategoryBizNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/add_category_workflow_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_overdue_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_search_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/branch_aware_booking_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (157 total, 51 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (89): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+81 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.08
Nodes (26): _bookingRepo, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer, createState, dispose, _InitiateTransferForm (+18 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.03
Nodes (71): adjustBookingDuration, ApiConstants, approveExpense, approveResignation, approveTransfer, assetAvailability, assetModels, assets (+63 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.03
Nodes (61): _addonSubtotal, _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildAddonsSelectionSection, _buildStep1UnitAndDuration, _buildStep2CustomerAndCollateral (+53 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.06
Nodes (17): Cocoa, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate, SceneDelegate (+9 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.05
Nodes (45): _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard, _buildErrorState, _buildMembersTab (+37 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (32): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, build, _buildPresetChip (+24 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+20 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.12
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 13 - "main.dart"
Cohesion: 0.08
Nodes (15): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, networkStatusProvider, setOffline, setOnline, build (+7 more)

### Community 14 - "auth_provider.dart"
Cohesion: 0.12
Nodes (9): copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository, updatePassword, updateProfile (+1 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.04
Nodes (41): BookingRepository, _FakeBookingRepository, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState, lastAllBranches (+33 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (28): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+20 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.04
Nodes (43): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildDrawerButton, _buildNoBusinessView (+35 more)

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
Nodes (19): AppTheme, main, build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+11 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.08
Nodes (18): _buildActiveContextBanner, _buildAllClearStatusCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview, _buildKpiCard (+10 more)

### Community 25 - "package:rentcore_mobile/features/auth/providers/business_provider.dart"
Cohesion: 0.06
Nodes (35): AuthState, BusinessNotifier, BusinessState, build, _initial, main, _StaticAuthNotifier, _StaticBusinessNotifier (+27 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.11
Nodes (14): _adapterReturned, booking, build, _cableReturned, _cameraOk, _conditionGrade, createState, _icloudRemoved (+6 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.09
Nodes (21): bizState, build, currentShiftProvider, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+13 more)

### Community 29 - "logout"
Cohesion: 0.32
Nodes (13): logout, build, _buildCatalogView, _buildFilterDrawer, _buildUnitsView, initState, _InventoryScreenState, _onUnitsScroll (+5 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (26): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, _closeNotesController, _coinController (+18 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.09
Nodes (20): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCentralBranch (+12 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.09
Nodes (18): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+10 more)

### Community 34 - "int?"
Cohesion: 0.08
Nodes (24): PosFilterBranchIdNotifier, AssetCategoryFilterNotifier, build, fetchBookings, initialState, lastBranchId, lastSearch, lastStatus (+16 more)

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

### Community 40 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.07
Nodes (25): AssetRepository, _MockCategoryAssetRepo, _FakeAssetRepository, _FakeAssetRepository, build, createTestWidget, fetchAssets, fetchCategories (+17 more)

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
Cohesion: 0.15
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
Cohesion: 0.09
Nodes (26): _handleGoogleSignIn, build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials, _handleSavePassword (+18 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.12
Nodes (14): build, createState, dispose, _emailController, _getEffectiveServerClientId, _login, LoginScreen, _LoginScreenState (+6 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.06
Nodes (24): build, _categories, createCategory, fetchCategories, main, _MockCategoryBizNotifier, bizState, build (+16 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.12
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.05
Nodes (33): DashboardRepository, currentUserEmail, _FakeDashboardRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+25 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.06
Nodes (25): _AdjustmentTarget, createState, _currentBookingPage, currentDurationHours, currentPrice, _debounceTimer, dispose, _DurationOption (+17 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (44): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+36 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (13): _addressController, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading, _loadStoreData (+5 more)

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

### Community 66 - "inventory_empty_state_test.dart"
Cohesion: 0.14
Nodes (13): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+5 more)

### Community 67 - "bookingRepositoryProvider"
Cohesion: 0.15
Nodes (17): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+9 more)

### Community 68 - "ConsumerState"
Cohesion: 0.18
Nodes (13): CashDrawerShiftModal, _CashDrawerShiftModalState, InventoryScreen, _AddBranchBottomSheet, _AddBranchBottomSheetState, _InviteMemberBottomSheet, _InviteMemberBottomSheetState, ManageOrganizationScreen (+5 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.12
Nodes (16): _amountController, branchId, build, _categories, createState, dispose, _errorMessage, _formKey (+8 more)

### Community 70 - "Customer Profile Management"
Cohesion: 0.20
Nodes (8): CustomerRepository, build, customerRepositoryProvider, customerSearchResultsProvider, query, repo, searchCustomers, setQuery

### Community 71 - "core/network/api_client.dart"
Cohesion: 0.18
Nodes (8): ApiClient, _dio, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument, _client, fetchKpi

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.12
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.14
Nodes (14): _buildClosingShiftTab, build, _buildDateChip, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen (+6 more)

### Community 74 - "../../core/constants/app_colors.dart"
Cohesion: 0.14
Nodes (9): build, onAddNewModel, onSelectProduct, TarifSewaSheet, productsProvider, build, _buildDockItem, currentIndex (+1 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.13
Nodes (14): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+6 more)

### Community 77 - "transfer_provider.dart"
Cohesion: 0.17
Nodes (10): branchRecipientsProvider, build, direction, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, repo, setDirection (+2 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.29
Nodes (6): DockAwareScaffold, DockClearance, FloatingCapsuleDock, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - "Windows Native Desktop Runner"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 127 - "paginated_result.dart"
Cohesion: 0.18
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 128 - "cashier_and_header_standardization_test.dart"
Cohesion: 0.09
Nodes (13): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage, build (+5 more)

### Community 129 - "cashierRepositoryProvider"
Cohesion: 0.15
Nodes (14): _buildBranchSelectorHeader, _executePayment, _fetchAndShowReceipt, _showBranchFilterModal, _showExpenseOptionsDialog, _handleVoidSubmit, _printBookingReceipt, AddBranchExpenseModal (+6 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.11
Nodes (16): _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, _printPaymentReceipt, build, _buildChoiceChip, _buildConnectionStatusCard (+8 more)

### Community 131 - "organization_test.dart"
Cohesion: 0.12
Nodes (16): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+8 more)

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.12
Nodes (10): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, ExchangeHistorySheet, show (+2 more)

### Community 133 - "staff_resignation_sheet.dart"
Cohesion: 0.15
Nodes (12): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+4 more)

### Community 134 - "notification_provider.dart"
Cohesion: 0.08
Nodes (21): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+13 more)

### Community 135 - "_TransfersScreenState"
Cohesion: 0.32
Nodes (8): build, _buildDirectionChip, _buildStatusChip, TransfersScreen, _TransfersScreenState, selectedTransferDirectionProvider, selectedTransferStatusProvider, transfersListProvider

### Community 138 - "voucher_screen.dart"
Cohesion: 0.08
Nodes (20): checkCurrentSession, login, branches, build, _buildDetailRow, _confirmDelete, isOwner, onPrintThermal (+12 more)

### Community 139 - "thermal_printer_service_test.dart"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

### Community 140 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (19): bizState, dashboardRepositoryProvider, fetchKpi, repo, build, changeBranch, fetchAssets, fetchReadyAssets (+11 more)

### Community 141 - "dashboard_cleanup_and_navigation_test.dart"
Cohesion: 0.17
Nodes (9): build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main, updatePassword (+1 more)

### Community 142 - "booking_provider.dart"
Cohesion: 0.12
Nodes (15): build, DirectRentalScreen, _DirectRentalScreenState, bizState, BookingSearchQueryNotifier, build, clear, fetchBookings (+7 more)

### Community 143 - "pos_all_branches_filter_test.dart"
Cohesion: 0.06
Nodes (28): CashierRepository, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+20 more)

### Community 144 - "AuthNotifier"
Cohesion: 0.29
Nodes (7): AuthNotifier, customerSearchQueryProvider, _MockGoogleAuthNotifier, _MockPasswordAuthNotifier, _MockAuthNotifier, _MockAuthNotifier, MockAuthNotifier

### Community 145 - "paymentMethodsProvider"
Cohesion: 0.33
Nodes (6): _buildStep3FinancialAndAuth, build, _PosPaymentModalSheet, _PosPaymentModalSheetState, paymentMethodsProvider, build

### Community 146 - "businessProvider"
Cohesion: 0.38
Nodes (5): BookingFilterNotifier, CustomerSearchQueryNotifier, AssetStatusFilterNotifier, TransferDirectionNotifier, TransferStatusNotifier

### Community 147 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 148 - "printerProvider"
Cohesion: 0.14
Nodes (16): businessProvider, _proceedToPayment, build, _buildBusinessErrorCard, HomeScreen, dashboardKpiProvider, _handleAction, build (+8 more)

### Community 149 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (15): _buildHeader, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState, _getActionLabel (+7 more)

### Community 151 - "assetRepositoryProvider"
Cohesion: 0.20
Nodes (10): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, _EditAssetSheet, _EditAssetSheetState (+2 more)

### Community 152 - "date_formatter.dart"
Cohesion: 0.33
Nodes (5): DateFormatter, formatFull, formatRelative, formatShort, formatTime

### Community 153 - "currency_formatter.dart"
Cohesion: 0.29
Nodes (4): CurrencyFormatter, format, _formatter, parse

### Community 154 - "_CashierScreenState"
Cohesion: 0.29
Nodes (7): _buildDateFilterChips, _buildPosTerminalTab, CashierScreen, _CashierScreenState, _buildDateFilterRow, cashierBookingsProvider, posDateRangeProvider

### Community 155 - "AuthRepository"
Cohesion: 0.40
Nodes (5): AuthRepository, _FakeAuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakeAuthRepository

### Community 156 - "authRepositoryProvider"
Cohesion: 0.40
Nodes (5): authRepositoryProvider, build, build, _saveStoreProfile, build

## Knowledge Gaps
- **1554 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1549 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1774 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **51 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.029) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1554 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `printerProvider` to `cashierRepositoryProvider`, `printer_settings_screen.dart`, `organization_test.dart`, `transfers_screen.dart`, `staff_resignation_sheet.dart`, `_TransfersScreenState`, `voucher_screen.dart`, `booking_provider.dart`, `AuthNotifier`, `Receipt Customization Settings`, `businessProvider`, `Voucher & Discount Rules`, `notification_center_screen.dart`, `assetRepositoryProvider`, `_CashierScreenState`, `Rental Return Processing`, `Cashier POS & Register`, `logout`, `authRepositoryProvider`, `business_provider.dart`, `int?`, `business_selector_sheet.dart`, `Inventory & Asset Catalog`, `authProvider`, `store_profile_screen.dart`, `bookingRepositoryProvider`, `ConsumerState`, `store_settings_screen.dart`, `../../../core/utils/currency_formatter.dart`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.08374384236453201 - nodes in this community are weakly interconnected._
- **Why does `AuthRepository` connect `AuthRepository` to `business_provider.dart`, `Organization & Branch Management`, `Authentication & User Session`, `auth_provider.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.0273972602739726 - nodes in this community are weakly interconnected._