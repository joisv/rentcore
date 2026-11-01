# Graph Report - rentcore  (2026-11-01)

## Corpus Check
- 172 files · ~172,179 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2898 nodes · 4538 edges · 176 communities (126 shown, 50 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `e9e94fcf`
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
- package:flutter_secure_storage/flutter_secure_storage.dart
- main.dart
- notification_center_test.dart
- package:flutter/material.dart
- Receipt Customization Settings
- Inventory & Asset Catalog
- Voucher & Discount Rules
- Cashier POS & Register
- payment_page.dart
- Windows Native Desktop Runner
- Printer Bluetooth Driver Module
- thermal_receipt_preview_dialog.dart
- Home Dashboard & Analytics
- shift_schedule_screen.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- string
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- expandable_inventory_fab.dart
- customer_directory_screen.dart
- dock_aware_scaffold.dart
- BusinessNotifier
- Windows Native Desktop Runner
- business_selector_sheet.dart
- ../../core/constants/app_colors.dart
- expandable_inventory_fab_test.dart
- branch_revenue_and_dashboard_test.dart
- Size
- BusinessNotifier
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
- network_status_provider.dart
- Map
- ConsumerState
- add_branch_expense_modal.dart
- customer_provider.dart
- customer_repository.dart
- store_settings_screen.dart
- ../../../core/utils/currency_formatter.dart
- cashier_and_header_standardization_test.dart
- Cashier POS & Register
- inventory_empty_state_test.dart
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
- logout
- ../../core/utils/currency_formatter.dart
- notification_provider.dart
- printer_settings_screen.dart
- inventory_live_payload_test.dart
- exchange_history_sheet.dart
- staff_resignation_sheet.dart
- notification_center_screen.dart
- add_category_workflow_test.dart
- rental_addons_and_policies_test.dart
- voucher_screen.dart
- List
- package:shared_preferences/shared_preferences.dart
- Map
- BusinessNotifier
- booking_provider.dart
- cashierRepositoryProvider
- package:flutter_riverpod/flutter_riverpod.dart
- List
- customer_directory_to_booking_prefill_test.dart
- bookings_queue_overdue_test.dart
- staff_resignation_test.dart
- printerProvider
- ../../auth/providers/business_provider.dart
- auth_lifecycle_relogin_test.dart
- pos_all_branches_filter_test.dart
- currency_formatter.dart
- Map
- customer_directory_and_governance_test.dart
- businessProvider
- date_formatter.dart
- paymentMethodsProvider
- MockPrinterDriver
- int?
- AssetRepository
- booking_rc_261030_0001_late_penalty_bug_fix_test.dart
- bookings_queue_overdue_test.dart
- bookings_queue_search_test.dart
- branch_aware_booking_test.dart
- AuthNotifier
- assetRepositoryProvider
- cash_suggestion_helper.dart
- organization_test.dart
- OrganizationNotifier
- navigation_keys.dart
- authRepositoryProvider
- _BusinessSelectorSheetState
- _DirectRentalScreenState

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 74 edges
2. `BusinessNotifier` - 38 edges
3. `authProvider` - 35 edges
4. `organizationProvider` - 28 edges
5. `AuthNotifier` - 25 edges
6. `BusinessState` - 25 edges
7. `printerProvider` - 24 edges
8. `Win32Window` - 21 edges
9. `BookingRepository` - 19 edges
10. `cashierRepositoryProvider` - 19 edges

## Surprising Connections (you probably didn't know these)
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/home_active_context_banner_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/payment_method_settings_screen_test.dart → lib/features/auth/providers/auth_provider.dart
- `_StaticAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/shift_schedule_screen_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockAuthNotifier` --inherits--> `AuthNotifier`  [EXTRACTED]
  test/staff_resignation_test.dart → lib/features/auth/providers/auth_provider.dart
- `_MockCategoryBizNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/add_category_workflow_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (176 total, 50 thin omitted)

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
Nodes (45): _addonsEnabled, _addressController, branches, build, _buildBranchesTab, _buildCard, _buildErrorState, _buildMembersTab (+37 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.04
Nodes (45): additionalHours, addonSubtotal, amountPaid, assetCode, booking, bookingCode, bookingId, branchId (+37 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (34): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, _buildPresetChip, _colorController (+26 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+20 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "package:flutter_secure_storage/flutter_secure_storage.dart"
Cohesion: 0.17
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 13 - "main.dart"
Cohesion: 0.10
Nodes (9): networkStatusProvider, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen, _MainShellScreenState (+1 more)

### Community 14 - "notification_center_test.dart"
Cohesion: 0.14
Nodes (9): NotificationNotifier, NotificationState, build, _FakeNotificationNotifier, fetchNotifications, fetchUnreadCountOnly, initialState, markAllAsRead (+1 more)

### Community 15 - "package:flutter/material.dart"
Cohesion: 0.11
Nodes (14): build, fakeDashboardData, lastCurrentPassword, lastNewPassword, lastUpdatedName, lastUpdatedPhone, main, updatePassword (+6 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (29): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+21 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.04
Nodes (48): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildDrawerButton, _buildNoBusinessView (+40 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.08
Nodes (25): build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading, isSubmitting (+17 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.06
Nodes (29): booking, _buildBookingPosCard, _buildCompactFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController, createState, dispose (+21 more)

### Community 20 - "payment_page.dart"
Cohesion: 0.04
Nodes (41): _applySelectedPaymentOption, _buildBankBadge, _buildBottomMethodCard, _buildCashBillIconWidget, _buildDanaBadge, _buildDynamicTileGrid, _buildEwalletTile, _buildGopayBadge (+33 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.17
Nodes (5): EnableFullDpiSupportIfAvailable(), Win32Window, child_content_, quit_on_close_, window_handle_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.10
Nodes (15): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+7 more)

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
Cohesion: 0.06
Nodes (28): _accountCleared, _adapterReturned, booking, build, _cableReturned, _cameraOk, _category, _checklistDefs (+20 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.07
Nodes (26): _buildPosTerminalTab, bizState, branchId, build, cashierBookingsProvider, dateRange, effectiveBranchId, endDate (+18 more)

### Community 29 - "string"
Cohesion: 0.12
Nodes (15): build, TarifSewaSheet, bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels (+7 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (28): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, CashDrawerShiftModal, _CashDrawerShiftModalState (+20 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.06
Nodes (29): branches, businessId, businessName, cancelResignation, copyWith, createBranch, error, inviteMember (+21 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.09
Nodes (21): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCategoryRelevant (+13 more)

### Community 33 - "expandable_inventory_fab.dart"
Cohesion: 0.09
Nodes (18): build, _buildActionRow, _buildMainFab, collapse, _controller, createState, dispose, expand (+10 more)

### Community 34 - "customer_directory_screen.dart"
Cohesion: 0.06
Nodes (38): build, _buildCustomerList, _buildFilterChip, createState, CustomerDirectoryScreen, _CustomerDirectoryScreenState, _debounceTimer, dispose (+30 more)

### Community 35 - "dock_aware_scaffold.dart"
Cohesion: 0.11
Nodes (15): appBar, backgroundColor, body, bottomSheet, build, DockEdgeInsetsExtension, DockFloatingActionButtonLocation, extra (+7 more)

### Community 36 - "BusinessNotifier"
Cohesion: 0.17
Nodes (11): buildTestScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, main, overdueBooking, processReturn (+3 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.07
Nodes (27): _addressCtrl, _availableCategories, _branchCodeCtrl, _branchNameCtrl, _branchSituation, _buildCurrentStepBody, _buildStep1Identity, _buildStep2Branch (+19 more)

### Community 39 - "../../core/constants/app_colors.dart"
Cohesion: 0.17
Nodes (7): onAddNewModel, onSelectProduct, build, _buildDockItem, currentIndex, FloatingCapsuleDock, onTabSelected

### Community 40 - "expandable_inventory_fab_test.dart"
Cohesion: 0.09
Nodes (16): build, createTestWidget, fetchAssets, fetchCategories, fetchProducts, main, _MockBizNotifier, payload (+8 more)

### Community 41 - "branch_revenue_and_dashboard_test.dart"
Cohesion: 0.08
Nodes (23): DashboardRepository, _FakeDashboardRepository, build, changeBranch, _FakeDashboardRepository, fetchBookingsForCashier, fetchClosingSummary, fetchKpi (+15 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "BusinessNotifier"
Cohesion: 0.06
Nodes (25): AppTheme, executePayment, lastContext, main, mockCategories, mockPaymentMethods, mockReadyAssets, main (+17 more)

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
Cohesion: 0.09
Nodes (25): _handleGoogleSignIn, build, _confirmPasswordController, createState, _currentPasswordController, dispose, _getInitials, _handleSavePassword (+17 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.13
Nodes (12): build, createState, dispose, _emailController, _getEffectiveServerClientId, _login, _obscurePassword, _passwordController (+4 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (25): booking, bookingId, build, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer (+17 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (16): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, deleteAsset, _extractList (+8 more)

### Community 54 - "auth_provider.dart"
Cohesion: 0.11
Nodes (9): copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository, updatePassword, updateProfile (+1 more)

### Community 55 - "payment_page_test.dart"
Cohesion: 0.07
Nodes (27): adjustDuration, build, businessState, createRental, extendRental, fetchPaymentMethods, _initialState, lastAdjustAdditionalFee (+19 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.12
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "payment_method_settings_screen.dart"
Cohesion: 0.08
Nodes (23): _bankTransferEnabled, _buildProviderTile, _cashEnabled, createState, _danaEnabled, _ewalletMasterEnabled, _isInitialized, _isSaving (+15 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.05
Nodes (31): _AdjustmentTarget, assetCode, catName, combined, createState, _currentBookingPage, currentDurationHours, currentPrice (+23 more)

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (44): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+36 more)

### Community 60 - "store_profile_screen.dart"
Cohesion: 0.13
Nodes (14): _addressController, build, createState, dispose, _formKey, initState, _isInitLoaded, _isLoading (+6 more)

### Community 61 - "voucher_management_test.dart"
Cohesion: 0.07
Nodes (25): VoucherRepository, _FakeVoucherRepository, alerts, build, fetchKpi, fetchVouchers, main, _MockVoucherRepo (+17 more)

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

### Community 66 - "network_status_provider.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 67 - "Map"
Cohesion: 0.12
Nodes (15): build, fetchCategories, fetchModels, fetchProducts, _initial, lastUpdatedAssetId, lastUpdatedAssetPayload, lastUpdatedProductId (+7 more)

### Community 68 - "ConsumerState"
Cohesion: 0.20
Nodes (12): LoginScreen, _LoginScreenState, _AddBranchBottomSheet, _AddBranchBottomSheetState, _InviteMemberBottomSheet, _InviteMemberBottomSheetState, ManageOrganizationScreen, _ManageOrganizationScreenState (+4 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.11
Nodes (18): AddBranchExpenseModal, _AddBranchExpenseModalState, _amountController, branchId, build, _categories, createState, dispose (+10 more)

### Community 70 - "customer_provider.dart"
Cohesion: 0.08
Nodes (27): build, copyWith, createCustomer, currentPage, CustomerNotifier, customerRepositoryProvider, customers, customerSearchResultsProvider (+19 more)

### Community 71 - "customer_repository.dart"
Cohesion: 0.14
Nodes (9): createCustomer, _dio, fetchCustomersPaginated, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument, _client (+1 more)

### Community 72 - "store_settings_screen.dart"
Cohesion: 0.11
Nodes (8): _buildDivider, _buildGroupHeader, _buildListTile, _buildSettingsCard, _confirmLogout, _getInitials, SettingsScreen, StoreSettingsScreen

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.12
Nodes (17): _buildCustomDateFilterChip, _buildDateFilterChips, build, _buildDateChip, _buildDateFilterRow, _buildFilterChip, _buildLedgerTile, createState (+9 more)

### Community 74 - "cashier_and_header_standardization_test.dart"
Cohesion: 0.06
Nodes (26): CashierRepository, _FakeCashierRepoForLatePenalty, _FakeCashierRepository, build, fetchBookingsForCashier, fetchBranchExpenses, fetchClosingSummary, fetchPaymentMethods (+18 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.11
Nodes (18): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+10 more)

### Community 77 - "inventory_empty_state_test.dart"
Cohesion: 0.13
Nodes (14): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+6 more)

### Community 79 - "StatelessWidget"
Cohesion: 0.33
Nodes (5): DockAwareScaffold, DockClearance, PosNumpad, RentCoreBackButton, StatusBadge

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - ".Create"
Cohesion: 0.14
Nodes (8): Point, x, y, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 127 - "logout"
Cohesion: 0.25
Nodes (16): logout, build, build, _buildCatalogView, _buildFilterDrawer, _buildUnitsView, initState, InventoryScreen (+8 more)

### Community 128 - "../../core/utils/currency_formatter.dart"
Cohesion: 0.20
Nodes (4): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods

### Community 129 - "notification_provider.dart"
Cohesion: 0.14
Nodes (12): build, copyWith, errorMessage, fetchNotifications, fetchUnreadCountOnly, isLoading, markAllAsRead, markAsRead (+4 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.17
Nodes (8): _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, initState, PrinterSettingsScreen, _PrinterSettingsScreenState

### Community 131 - "inventory_live_payload_test.dart"
Cohesion: 0.13
Nodes (14): bizState, build, buildScreen, fetchAssets, fetchCategories, fetchModels, fetchProducts, _initial (+6 more)

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.17
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 133 - "staff_resignation_sheet.dart"
Cohesion: 0.14
Nodes (12): businessId, businessName, _confirmCancel, _confirmSubmit, createState, dispose, initState, _reasonController (+4 more)

### Community 134 - "notification_center_screen.dart"
Cohesion: 0.12
Nodes (15): _buildHeader, build, _buildBody, _buildCategoryTabs, _buildDateHeader, _buildNotificationCard, createState, _getActionLabel (+7 more)

### Community 135 - "add_category_workflow_test.dart"
Cohesion: 0.22
Nodes (6): build, _categories, createCategory, fetchCategories, main, _MockCategoryBizNotifier

### Community 136 - "rental_addons_and_policies_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 137 - "voucher_screen.dart"
Cohesion: 0.07
Nodes (23): checkCurrentSession, login, ExchangeHistorySheet, branches, build, _buildDetailRow, _confirmDelete, isOwner (+15 more)

### Community 138 - "List"
Cohesion: 0.17
Nodes (9): copyWith, currentPage, empty, hasMore, items, lastPage, PaginatedResult, perPage (+1 more)

### Community 139 - "package:shared_preferences/shared_preferences.dart"
Cohesion: 0.12
Nodes (6): buildTestableWidget, main, connect, isConnected, main, writeBytes

### Community 140 - "Map"
Cohesion: 0.07
Nodes (23): AuthRepository, _FakeAuthRepository, fakeAuthRepo, _FakeAuthRepository, fetchBusinesses, main, setActiveContext, storedContext (+15 more)

### Community 141 - "BusinessNotifier"
Cohesion: 0.07
Nodes (27): AuthState, BusinessNotifier, BusinessState, _TestBusinessNotifier, _TestBusinessNotifier, _TestBusinessNotifier, build, FakeCashierRepository (+19 more)

### Community 142 - "booking_provider.dart"
Cohesion: 0.09
Nodes (28): BookingsScreen, _BookingsScreenState, build, _buildFilterChip, _clearSearch, initState, _onBookingsScroll, _onSearchChanged (+20 more)

### Community 143 - "cashierRepositoryProvider"
Cohesion: 0.22
Nodes (9): _executePayment, _fetchAndShowReceipt, _handleVoidSubmit, _printBookingReceipt, _submitCloseShift, _submitOpenShift, cashierRepositoryProvider, _saveSettings (+1 more)

### Community 144 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.11
Nodes (11): bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, main (+3 more)

### Community 145 - "List"
Cohesion: 0.13
Nodes (13): build, fetchBookingDetail, fetchBookings, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount (+5 more)

### Community 146 - "customer_directory_to_booking_prefill_test.dart"
Cohesion: 0.05
Nodes (29): PaymentRepository, PaymentContext, PaymentResult, MockPaymentRepository, executePayment, lastContext, lastResult, main (+21 more)

### Community 147 - "bookings_queue_overdue_test.dart"
Cohesion: 0.17
Nodes (11): build, changeBranch, fetchBookings, initialState, lastAllBranches, lastBranchId, lastSearch, lastStatus (+3 more)

### Community 148 - "staff_resignation_test.dart"
Cohesion: 0.20
Nodes (8): build, _initialState, loadOrganization, loadResignations, main, _MockAuthNotifier, _MockBusinessNotifier, _mockState

### Community 149 - "printerProvider"
Cohesion: 0.13
Nodes (15): _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, build, _printPaymentReceipt, build, _buildQuickActionsCard (+7 more)

### Community 150 - "../../auth/providers/business_provider.dart"
Cohesion: 0.20
Nodes (7): build, HomeScreen, bizState, dashboardKpiProvider, dashboardRepositoryProvider, fetchKpi, repo

### Community 151 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.17
Nodes (11): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+3 more)

### Community 152 - "pos_all_branches_filter_test.dart"
Cohesion: 0.17
Nodes (11): build, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastBookingsAllBranches, lastBookingsBranchId, lastClosingAllBranches (+3 more)

### Community 153 - "currency_formatter.dart"
Cohesion: 0.29
Nodes (4): CurrencyFormatter, format, _formatter, parse

### Community 154 - "Map"
Cohesion: 0.09
Nodes (17): androidBooking, appleBooking, buildScreen, fetchPaymentMethods, main, processReturn, submittedPayload, _TestBusinessNotifier (+9 more)

### Community 155 - "customer_directory_and_governance_test.dart"
Cohesion: 0.14
Nodes (7): CustomerRepository, createCustomer, dummyCustomers, fetchCustomersPaginated, main, MockCustomerRepository, toggleBlacklist

### Community 156 - "businessProvider"
Cohesion: 0.15
Nodes (20): businessProvider, BookingFilterNotifier, BookingSearchQueryNotifier, _buildBranchSelectorHeader, _buildClosingShiftTab, _buildStickyClosingBottomBar, CashierScreen, _CashierScreenState (+12 more)

### Community 157 - "date_formatter.dart"
Cohesion: 0.33
Nodes (5): DateFormatter, formatFull, formatRelative, formatShort, formatTime

### Community 158 - "paymentMethodsProvider"
Cohesion: 0.24
Nodes (10): _buildStep3FinancialAndAuth, build, paymentMethodsProvider, paymentSettingsProvider, build, paymentRepositoryProvider, build, _executePaymentProcess (+2 more)

### Community 159 - "MockPrinterDriver"
Cohesion: 0.40
Nodes (5): MockPrinterDriver, PlatformBluetoothDriver, PrinterBluetoothDriver, _FailingConnectMockDriver, _FailingWriteMockDriver

### Community 160 - "int?"
Cohesion: 0.11
Nodes (16): attempts, main, voidTransaction, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+8 more)

### Community 161 - "AssetRepository"
Cohesion: 0.20
Nodes (10): AssetRepository, _MockCategoryAssetRepo, _FakeAssetRepository, _FakeAssetRepository, _MockAssetRepo, _TrackingAssetRepository, _ConfigurableAssetRepository, _Repo (+2 more)

### Community 162 - "booking_rc_261030_0001_late_penalty_bug_fix_test.dart"
Cohesion: 0.14
Nodes (13): bookingRC2610300001, build, buildReturnScreen, businessState, fakeBookingRepo, fakeCashierRepo, fetchPaymentMethods, _initialState (+5 more)

### Community 163 - "bookings_queue_overdue_test.dart"
Cohesion: 0.06
Nodes (31): BookingRepository, _FakeBookingRepository, _FakeBookingRepoForLatePenalty, _FakeBookingRepository, _FakeBookingRepo, _FakeBookingRepositoryForQueue, _FakeBookingRepositoryForReturn, _FakeBookingRepo (+23 more)

### Community 164 - "bookings_queue_search_test.dart"
Cohesion: 0.18
Nodes (10): build, _FakeSearchBookingRepository, fetchBookings, initialState, lastBranchId, lastSearch, lastStatus, main (+2 more)

### Community 165 - "branch_aware_booking_test.dart"
Cohesion: 0.18
Nodes (10): build, changeBranch, _FakeBookingRepository, fetchAssets, fetchReadyAssets, initialState, main, recordedBranchRequests (+2 more)

### Community 166 - "AuthNotifier"
Cohesion: 0.29
Nodes (7): AuthNotifier, customerSearchQueryProvider, _MockGoogleAuthNotifier, _MockPasswordAuthNotifier, _MockAuthNotifier, _FixedAuthNotifier, MockAuthNotifier

### Community 167 - "assetRepositoryProvider"
Cohesion: 0.20
Nodes (10): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, _confirmDelete, _confirmDeleteFromCard, _EditAssetSheet, _EditAssetSheetState (+2 more)

### Community 168 - "cash_suggestion_helper.dart"
Cohesion: 0.22
Nodes (6): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts

### Community 169 - "organization_test.dart"
Cohesion: 0.29
Nodes (5): build, loadOrganization, main, _mockInitialState, refresh

### Community 170 - "OrganizationNotifier"
Cohesion: 0.33
Nodes (6): OrganizationNotifier, OrganizationState, _MockOrganizationNotifier, _MockRentalRulesOrgNotifier, _MockOrganizationNotifier, MockOrganizationNotifier

### Community 173 - "authRepositoryProvider"
Cohesion: 0.40
Nodes (5): authRepositoryProvider, build, build, _saveStoreProfile, build

### Community 179 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

## Knowledge Gaps
- **1843 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1838 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2076 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **50 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Windows Native Desktop Runner` to `Windows Native Desktop Runner`, `Size`, `flutter_window.h`, `Windows Native Desktop Runner`, `.Create`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1843 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.02127659574468085 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `businessProvider` to `transfers_screen.dart`, `Direct Rental Booking`, `staff_resignation_sheet.dart`, `notification_center_screen.dart`, `Inventory & Asset Catalog`, `voucher_screen.dart`, `booking_provider.dart`, `Receipt Customization Settings`, `Voucher & Discount Rules`, `printerProvider`, `../../auth/providers/business_provider.dart`, `Home Dashboard & Analytics`, `shift_schedule_screen.dart`, `Rental Return Processing`, `Cashier POS & Register`, `string`, `paymentMethodsProvider`, `business_provider.dart`, `AuthNotifier`, `assetRepositoryProvider`, `business_selector_sheet.dart`, `OrganizationNotifier`, `authRepositoryProvider`, `_BusinessSelectorSheetState`, `authProvider`, `_DirectRentalScreenState`, `payment_method_settings_screen.dart`, `store_profile_screen.dart`, `ConsumerState`, `add_branch_expense_modal.dart`, `customer_provider.dart`, `store_settings_screen.dart`, `logout`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05411764705882353 - nodes in this community are weakly interconnected._
- **Why does `CashierRepository` connect `cashier_and_header_standardization_test.dart` to `../../core/utils/currency_formatter.dart`, `Cashier POS & Register`, `BusinessNotifier`, `package:flutter_riverpod/flutter_riverpod.dart`, `customer_directory_to_booking_prefill_test.dart`, `Cashier POS & Register`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.02531645569620253 - nodes in this community are weakly interconnected._