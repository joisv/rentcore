# Graph Report - rentcore  (2026-10-21)

## Corpus Check
- 133 files · ~325,081 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 53 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 2092 nodes · 3125 edges · 140 communities (90 shown, 50 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a1930885`
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
- Payment Page Test Module
- Home Dashboard & Analytics
- voucher_management_test.dart
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- AuthNotifier
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- business_provider.dart
- ../../auth/providers/business_provider.dart
- voucher_detail_dialog.dart
- status_badge.dart
- inventory_editing_test.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- Win32Window
- logout_and_inventory_detail_test.dart
- auth_lifecycle_relogin_test.dart
- Size
- Inventory & Asset Catalog
- inventory_live_payload_test.dart
- Booking Management System
- Authentication & User Session
- organization_test.dart
- auth_provider.dart
- Windows Native Desktop Runner
- _CashierScreenState
- login_screen.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- booking_provider.dart
- package:flutter_test/flutter_test.dart
- pos_numpad.dart
- businessProvider
- bookings_screen.dart
- exchange_wizard_screen.dart
- late_return_penalty_pos_test.dart
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- payment_repository.dart
- branch_aware_booking_test.dart
- ConsumerState
- add_branch_expense_modal.dart
- Customer Profile Management
- ../../../core/constants/api_constants.dart
- authProvider
- ../../../core/utils/currency_formatter.dart
- cashierRepositoryProvider
- Cashier POS & Register
- test_dio_fetch.dart
- Windows Native Desktop Runner
- string
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
- pos_revenue_consolidation_widget_test.dart
- organizationProvider
- printer_settings_screen.dart
- package:flutter_riverpod/flutter_riverpod.dart
- exchange_history_sheet.dart
- paymentMethodsProvider
- AuthRepository
- voucher_screen.dart
- package:flutter/material.dart
- toPluginPayload
- assetRepositoryProvider
- dart:convert

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 36 edges
2. `printerProvider` - 26 edges
3. `BusinessNotifier` - 22 edges
4. `Win32Window` - 21 edges
5. `authProvider` - 20 edges
6. `AuthNotifier` - 19 edges
7. `BusinessState` - 17 edges
8. `organizationProvider` - 16 edges
9. `logout` - 13 edges
10. `cashierRepositoryProvider` - 13 edges

## Surprising Connections (you probably didn't know these)
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/bookings_queue_overdue_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/branch_revenue_and_dashboard_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/cash_payment_suggestion_test.dart → lib/features/auth/providers/business_provider.dart
- `_ActiveBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/home_dashboard_kpi_test.dart → lib/features/auth/providers/business_provider.dart
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/late_return_penalty_pos_test.dart → lib/features/auth/providers/business_provider.dart

## Import Cycles
- None detected.

## Communities (140 total, 50 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (88): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+80 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.06
Nodes (45): _bookingRepo, build, _buildDirectionChip, _buildStatusChip, _buildTransferCard, _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer (+37 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.03
Nodes (58): ApiConstants, approveExpense, approveTransfer, assetAvailability, assetModels, assets, availableReplacements, bookingDetail (+50 more)

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
Cohesion: 0.06
Nodes (31): _addonsEnabled, _addressController, branches, _buildCard, _buildRoleBadge, _buildRoleChoice, businessId, businessName (+23 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (30): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, _buildPresetChip, _colorController (+22 more)

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
Cohesion: 0.05
Nodes (19): networkStatusProvider, MockPrinterDriver, build, createState, _currentTabIndex, initializeDateFormatting, main, MainShellScreen (+11 more)

### Community 14 - "AuthNotifier"
Cohesion: 0.09
Nodes (19): BusinessNotifier, BusinessState, _TestBusinessNotifier, build, _initial, main, _StaticBusinessNotifier, _TestBusinessNotifier (+11 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.06
Nodes (29): BookingRepository, _FakeBookingRepository, build, changeBranch, _FakeBookingRepository, fetchBookings, initialState, lastAllBranches (+21 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (26): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+18 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.06
Nodes (31): asset, _assetCodeController, _batteryHealthController, _buildAssetCard, _buildBranchBar, _buildChip, _buildNoBusinessView, _buildProductCard (+23 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): VoucherRepository, build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading (+20 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.07
Nodes (25): booking, _buildBookingPosCard, _buildDateFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController, createState, dispose (+17 more)

### Community 20 - "Payment Gateway & Processing"
Cohesion: 0.08
Nodes (21): PaymentContext, _buildSuccessView, _cashReceivedController, _completedResult, createState, dispose, _getBadgeBackgroundColor, _getBadgeTextColor (+13 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.13
Nodes (6): EnableFullDpiSupportIfAvailable(), Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.10
Nodes (16): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+8 more)

### Community 23 - "Payment Page Test Module"
Cohesion: 0.06
Nodes (24): main, attempts, main, voidTransaction, build, businessState, createRental, extendRental (+16 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.07
Nodes (19): _buildActiveContextBanner, _buildAllClearStatusCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview, _buildKpiCard (+11 more)

### Community 25 - "voucher_management_test.dart"
Cohesion: 0.11
Nodes (15): build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId, lastToggledId (+7 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.10
Nodes (19): _showExtendDialog, _executeExchangeSubmission, _loadAvailableReplacements, _adapterReturned, booking, build, _cableReturned, _cameraOk (+11 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.09
Nodes (21): bizState, build, currentShiftProvider, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+13 more)

### Community 29 - "AuthNotifier"
Cohesion: 0.29
Nodes (13): logout, build, build, _buildCatalogView, _buildUnitsView, initState, _InventoryScreenState, assetSearchQueryProvider (+5 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (28): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, CashDrawerShiftModal, _CashDrawerShiftModalState (+20 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.10
Nodes (18): branches, businessId, businessName, copyWith, createBranch, error, inviteMember, isLoading (+10 more)

### Community 32 - "business_provider.dart"
Cohesion: 0.10
Nodes (19): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCentralBranch (+11 more)

### Community 33 - "../../auth/providers/business_provider.dart"
Cohesion: 0.29
Nodes (4): bizState, dashboardRepositoryProvider, fetchKpi, repo

### Community 34 - "voucher_detail_dialog.dart"
Cohesion: 0.12
Nodes (14): checkCurrentSession, login, branches, build, _buildDetailRow, _confirmDelete, isOwner, onPrintThermal (+6 more)

### Community 35 - "status_badge.dart"
Cohesion: 0.05
Nodes (32): appBar, backgroundColor, body, bottomSheet, build, DockAwareScaffold, DockClearance, DockEdgeInsetsExtension (+24 more)

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

### Community 40 - "logout_and_inventory_detail_test.dart"
Cohesion: 0.09
Nodes (16): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage, build (+8 more)

### Community 41 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.08
Nodes (22): DashboardRepository, _FakeDashboardRepository, build, changeBranch, _FakeDashboardRepository, fetchBookingsForCashier, fetchClosingSummary, fetchKpi (+14 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "Inventory & Asset Catalog"
Cohesion: 0.13
Nodes (13): AssetSearchQueryNotifier, bizState, build, catalogModelsProvider, categoryId, fetchCategories, fetchModels, fetchProducts (+5 more)

### Community 44 - "inventory_live_payload_test.dart"
Cohesion: 0.07
Nodes (27): AssetRepository, _FakeAssetRepository, _FakeAssetRepository, _TrackingAssetRepository, _ConfigurableAssetRepository, build, fetchAssets, fetchCategories (+19 more)

### Community 45 - "Booking Management System"
Cohesion: 0.20
Nodes (9): _client, createRental, exchangeRentalUnit, extendRental, fetchAvailableReplacements, fetchBookingDetail, fetchBookings, fetchReadyAssets (+1 more)

### Community 46 - "Authentication & User Session"
Cohesion: 0.12
Nodes (14): checkSession, _client, createBranch, createBusiness, fetchBranches, fetchBusinesses, fetchMembers, fetchRentalRules (+6 more)

### Community 47 - "organization_test.dart"
Cohesion: 0.13
Nodes (15): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+7 more)

### Community 48 - "auth_provider.dart"
Cohesion: 0.09
Nodes (17): AuthNotifier, authRepositoryProvider, AuthState, build, copyWith, errorMessage, googleSignIn, isAuthenticated (+9 more)

### Community 49 - "Windows Native Desktop Runner"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 50 - "_CashierScreenState"
Cohesion: 0.18
Nodes (12): _buildBranchSelectorHeader, _buildClosingShiftTab, _buildDateFilterChips, _buildPosTerminalTab, CashierScreen, _CashierScreenState, _showBranchFilterModal, _submit (+4 more)

### Community 51 - "login_screen.dart"
Cohesion: 0.15
Nodes (10): createState, dispose, _emailController, _getEffectiveServerClientId, _obscurePassword, _passwordController, _quickFill, _showConfigGoogleClientIdDialog (+2 more)

### Community 52 - "pos_transaction_detail_sheet.dart"
Cohesion: 0.08
Nodes (22): booking, bookingId, _buildContent, _buildPriceRow, _buildStatusChip, _buildTimelineRow, _countdownTimer, createState (+14 more)

### Community 53 - "Inventory & Asset Catalog"
Cohesion: 0.13
Nodes (14): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, _extractList, fetchAssets (+6 more)

### Community 54 - "booking_provider.dart"
Cohesion: 0.15
Nodes (11): build, DirectRentalScreen, _DirectRentalScreenState, bizState, build, fetchBookings, fetchReadyAssets, readyAssetsProvider (+3 more)

### Community 55 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.08
Nodes (18): assetsToReturn, baseBusinessState, build, categoriesToReturn, createTestWidget, fetchAssets, fetchCategories, fetchModels (+10 more)

### Community 56 - "pos_numpad.dart"
Cohesion: 0.13
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "businessProvider"
Cohesion: 0.11
Nodes (22): businessProvider, _proceedToPayment, _printExchangeReceipt, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, _buildBusinessErrorCard, _buildHeader (+14 more)

### Community 58 - "bookings_screen.dart"
Cohesion: 0.16
Nodes (6): BookingsScreen, build, _buildFilterChip, bookingFilterStatusProvider, bookingsListProvider, PaymentResult

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (42): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+34 more)

### Community 60 - "late_return_penalty_pos_test.dart"
Cohesion: 0.14
Nodes (12): build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount, lastPaymentType (+4 more)

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
Cohesion: 0.18
Nodes (10): ApiClient, _client, createVoucher, deleteVoucher, fetchPrintSlip, fetchVouchers, getVoucher, toggleVoucherStatus (+2 more)

### Community 66 - "payment_repository.dart"
Cohesion: 0.18
Nodes (5): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods, PaymentRepository

### Community 67 - "branch_aware_booking_test.dart"
Cohesion: 0.07
Nodes (20): currentUserEmail, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers, isLoggedOut, login (+12 more)

### Community 68 - "ConsumerState"
Cohesion: 0.18
Nodes (13): LoginScreen, _LoginScreenState, _PosPaymentModalSheet, _PosPaymentModalSheetState, InventoryScreen, _AddBranchBottomSheet, _AddBranchBottomSheetState, _InviteMemberBottomSheet (+5 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.07
Nodes (24): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts, AddBranchExpenseModal, _AddBranchExpenseModalState (+16 more)

### Community 70 - "Customer Profile Management"
Cohesion: 0.22
Nodes (7): build, customerRepositoryProvider, customerSearchResultsProvider, query, repo, searchCustomers, setQuery

### Community 71 - "../../../core/constants/api_constants.dart"
Cohesion: 0.18
Nodes (8): CustomerRepository, _dio, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument, _client, fetchKpi

### Community 72 - "authProvider"
Cohesion: 0.18
Nodes (12): build, _handleGoogleSignIn, _login, authProvider, ExchangeHistorySheet, _printClosingReceipt, build, _confirmLogout (+4 more)

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.15
Nodes (11): build, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen, _FinancialActivityLedgerScreenState, _searchController (+3 more)

### Community 74 - "cashierRepositoryProvider"
Cohesion: 0.20
Nodes (10): _executePayment, _fetchAndShowReceipt, build, _handleVoidSubmit, PosTransactionDetailSheet, _printBookingReceipt, _submitCloseShift, _submitOpenShift (+2 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.14
Nodes (13): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+5 more)

### Community 77 - "test_dio_fetch.dart"
Cohesion: 0.20
Nodes (9): authedDio, dio, loginRes, main, res1, resAll, resBranch1, resBranch2 (+1 more)

### Community 79 - "string"
Cohesion: 0.47
Nodes (4): BookingFilterNotifier, CustomerSearchQueryNotifier, AssetStatusFilterNotifier, TransferStatusNotifier

### Community 80 - "Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?, Source Nodes

### Community 81 - "Windows Native Desktop Runner"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 127 - "../../core/constants/app_colors.dart"
Cohesion: 0.29
Nodes (4): build, _buildDockItem, currentIndex, onTabSelected

### Community 128 - "pos_revenue_consolidation_widget_test.dart"
Cohesion: 0.05
Nodes (41): CashierRepository, PosFilterBranchIdNotifier, AssetCategoryFilterNotifier, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier (+33 more)

### Community 129 - "organizationProvider"
Cohesion: 0.18
Nodes (10): build, _buildBranchesTab, _buildErrorState, _buildMembersTab, initState, ManageOrganizationScreen, _ManageOrganizationScreenState, _saveRules (+2 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.18
Nodes (8): _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, initState, PrinterSettingsScreen, _PrinterSettingsScreenState

### Community 131 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.25
Nodes (6): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, setOffline, setOnline

### Community 132 - "exchange_history_sheet.dart"
Cohesion: 0.17
Nodes (7): booking, build, _buildEmptyState, _buildExchangeCard, _categoryIcons, _categoryLabels, show

### Community 133 - "paymentMethodsProvider"
Cohesion: 0.20
Nodes (10): _buildStep3FinancialAndAuth, ExchangeWizardScreen, _ExchangeWizardScreenState, build, paymentMethodsProvider, paymentRepositoryProvider, build, PaymentPage (+2 more)

### Community 134 - "AuthRepository"
Cohesion: 0.50
Nodes (4): AuthRepository, _FakeAuthRepository, _ThrowingAuthRepository, _FakeAuthRepository

### Community 135 - "voucher_screen.dart"
Cohesion: 0.20
Nodes (5): createState, dispose, _isSearchExpanded, _searchController, _showThermalSlipModal

### Community 138 - "assetRepositoryProvider"
Cohesion: 0.33
Nodes (6): _showQuickAddCategoryDialog, _submitProduct, _AddAssetSheet, _AddAssetSheetState, allCatalogModelsProvider, assetRepositoryProvider

### Community 139 - "dart:convert"
Cohesion: 0.33
Nodes (4): decoded, listFromDio, main, mapFromDio

## Knowledge Gaps
- **1295 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1290 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1491 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **50 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.013) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1295 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.021505376344086023 - nodes in this community are weakly interconnected._
- **Why does `AssetRepository` connect `inventory_live_payload_test.dart` to `Inventory & Asset Catalog`, `Inventory & Asset Catalog`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05551020408163265 - nodes in this community are weakly interconnected._
- **Why does `BookingRepository` connect `bookings_queue_overdue_test.dart` to `transfers_screen.dart`, `payment_repository.dart`, `Booking Management System`, `booking_provider.dart`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.03333333333333333 - nodes in this community are weakly interconnected._