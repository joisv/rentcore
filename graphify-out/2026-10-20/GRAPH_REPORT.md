# Graph Report - rentcore  (2026-10-20)

## Corpus Check
- 122 files · ~102,332 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 52 file(s) not represented in the graph (top: .xml 8, .xcconfig 8, (none) 7)

## Summary
- 1950 nodes · 2870 edges · 139 communities (89 shown, 50 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.83)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7d0632f2`
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
- voucher_detail_dialog.dart
- main.dart
- currency_formatter.dart
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
- Voucher & Discount Rules
- Rental Return Processing
- App Colors Module
- Cashier POS & Register
- AuthNotifier
- cash_drawer_shift_modal.dart
- Organization & Branch Management
- Authentication & User Session
- ../../auth/providers/business_provider.dart
- voucher_screen.dart
- status_badge.dart
- logout_and_inventory_detail_test.dart
- Windows Native Desktop Runner
- business_selector_sheet.dart
- Win32Window
- pos_all_branches_filter_test.dart
- auth_lifecycle_relogin_test.dart
- Size
- Inventory & Asset Catalog
- Authentication & User Session
- Booking Management System
- Authentication & User Session
- printer_settings_screen_test.dart
- package:flutter_riverpod/flutter_riverpod.dart
- Windows Native Desktop Runner
- _CashierScreenState
- login_screen.dart
- pos_transaction_detail_sheet.dart
- Inventory & Asset Catalog
- booking_provider.dart
- assetRepositoryProvider
- pos_numpad.dart
- printer_settings_screen.dart
- Secure Token Storage Module
- exchange_wizard_screen.dart
- Thermal Receipt Printing Service
- Asset Transfer Workflow
- Flutter Web Shell Platform
- Core API & Network Client
- Voucher & Discount Rules
- thermal_receipt_preview_dialog.dart
- auth_lifecycle_relogin_test.dart
- ConsumerState
- add_branch_expense_modal.dart
- Customer Profile Management
- Customer Profile Management
- package:flutter/material.dart
- ../../../core/utils/currency_formatter.dart
- cashierRepositoryProvider
- Cashier POS & Register
- voucherProvider
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
- authProvider
- printer_settings_screen.dart
- organization_test.dart
- transfer_provider.dart
- bookingRepositoryProvider
- payment_repository.dart
- transferRepositoryProvider
- _TransfersScreenState
- authRepositoryProvider
- _DirectRentalScreenState

## God Nodes (most connected - your core abstractions)
1. `businessProvider` - 35 edges
2. `printerProvider` - 24 edges
3. `Win32Window` - 21 edges
4. `authProvider` - 20 edges
5. `AuthNotifier` - 19 edges
6. `BusinessNotifier` - 17 edges
7. `organizationProvider` - 14 edges
8. `logout` - 13 edges
9. `BusinessState` - 13 edges
10. `cashierRepositoryProvider` - 13 edges

## Surprising Connections (you probably didn't know these)
- `_TestBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/pos_all_branches_filter_test.dart → lib/features/auth/providers/business_provider.dart
- `_MockBusinessNotifier` --inherits--> `BusinessNotifier`  [EXTRACTED]
  test/transfers_test.dart → lib/features/auth/providers/business_provider.dart
- `_FakeAuthRepository` --inherits--> `AuthRepository`  [EXTRACTED]
  test/auth_lifecycle_relogin_test.dart → lib/features/auth/data/auth_repository.dart
- `_ThrowingAuthRepository` --inherits--> `AuthRepository`  [EXTRACTED]
  test/logout_and_inventory_detail_test.dart → lib/features/auth/data/auth_repository.dart
- `_FakeAuthRepository` --inherits--> `AuthRepository`  [EXTRACTED]
  test/transferred_inventory_visibility_test.dart → lib/features/auth/data/auth_repository.dart

## Import Cycles
- None detected.

## Communities (139 total, 50 thin omitted)

### Community 0 - "Thermal Printer Data Models"
Cohesion: 0.02
Nodes (88): accessoriesNotes, address, alignment, bookingCode, branchName, cashChange, cashierName, cashReceived (+80 more)

### Community 1 - "transfers_screen.dart"
Cohesion: 0.10
Nodes (17): _bookingRepo, _buildTransferCard, createState, dispose, initState, _invalidateAllInventoryAndTransfers, _isLoading, _isLoadingAssets (+9 more)

### Community 2 - "Core API & Network Client"
Cohesion: 0.04
Nodes (55): ApiConstants, approveExpense, approveTransfer, assetAvailability, assetModels, assets, availableReplacements, bookingDetail (+47 more)

### Community 3 - "Direct Rental Booking"
Cohesion: 0.04
Nodes (53): _addressController, _assetValidationError, _attachIdentityDocument, _basePrice, _buildStep1UnitAndDuration, _buildStep2CustomerAndCollateral, _buildStep3SummaryAndPayment, _buildStepDivider (+45 more)

### Community 4 - "macOS Native Runner App"
Cohesion: 0.06
Nodes (17): Cocoa, Flutter, flutter_secure_storage_darwin, FlutterMacOS, Foundation, google_sign_in_ios, AppDelegate, SceneDelegate (+9 more)

### Community 5 - "Thermal Receipt Printing Service"
Cohesion: 0.05
Nodes (35): _appendFooter, _appendHeader, buildClosingShiftSlipBytes, buildPosPaymentSlipBytes, _buildQrCodeEscPos, buildReceiptDocument, buildRentalBookingSlipBytes, buildRentalReturnSlipBytes (+27 more)

### Community 6 - "Organization & Branch Management"
Cohesion: 0.07
Nodes (33): _AddBranchBottomSheet, _AddBranchBottomSheetState, _addressController, branches, build, _buildBranchesTab, _buildErrorState, _buildMembersTab (+25 more)

### Community 7 - "Payment Gateway & Processing"
Cohesion: 0.06
Nodes (33): additionalHours, amountPaid, assetCode, booking, bookingCode, bookingId, branchId, branchName (+25 more)

### Community 8 - "Inventory & Asset Catalog"
Cohesion: 0.07
Nodes (27): _accessoriesController, _addPresetRate, AddProductSheet, _AddProductSheetState, _addRateRow, _brandController, _buildPresetChip, _colorController (+19 more)

### Community 9 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (26): _barcodeType, branches, build, _codeController, createState, _customerQuotaController, _descController, _discountPercentController (+18 more)

### Community 10 - "Linux Native Desktop Runner"
Cohesion: 0.08
Nodes (14): fl_register_plugins(), main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line() (+6 more)

### Community 11 - "Thermal Printer Management"
Cohesion: 0.07
Nodes (29): PrinterConnectionStatus, ReceiptCustomizationSettings, ThermalPrinterDevice, ThermalPrinterService, build, connectDevice, connectedDevice, copyWith (+21 more)

### Community 12 - "voucher_detail_dialog.dart"
Cohesion: 0.18
Nodes (6): branches, _buildDetailRow, isOwner, onPrintThermal, show, voucher

### Community 13 - "main.dart"
Cohesion: 0.07
Nodes (15): build, checkConnectivity, NetworkStatus, NetworkStatusNotifier, networkStatusProvider, setOffline, setOnline, build (+7 more)

### Community 14 - "currency_formatter.dart"
Cohesion: 0.15
Nodes (9): CurrencyFormatter, format, _formatter, parse, DateFormatter, formatFull, formatRelative, formatShort (+1 more)

### Community 15 - "bookings_queue_overdue_test.dart"
Cohesion: 0.17
Nodes (10): build, changeBranch, fetchBookings, initialState, lastAllBranches, lastBranchId, lastSearch, lastStatus (+2 more)

### Community 16 - "Receipt Customization Settings"
Cohesion: 0.07
Nodes (26): PrintMode, _addressCtrl, _branchNameCtrl, build, _buildChoiceChip, _buildEchoThermalPreview, _buildFieldTogglesCard, _buildFooterSettingsCard (+18 more)

### Community 17 - "Inventory & Asset Catalog"
Cohesion: 0.08
Nodes (23): asset, _batteryController, _buildAssetCard, _codeController, createState, dispose, _EditAssetSheet, _EditAssetSheetState (+15 more)

### Community 18 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (28): VoucherRepository, build, copyWith, createVoucher, deleteVoucher, error, fetchVouchers, isLoading (+20 more)

### Community 19 - "Cashier POS & Register"
Cohesion: 0.07
Nodes (25): booking, _buildBookingPosCard, _buildDateFilterChip, _calcCashTotal, _calcNonCashTotal, _cashReceivedController, createState, dispose (+17 more)

### Community 20 - "Payment Gateway & Processing"
Cohesion: 0.08
Nodes (25): paymentRepositoryProvider, PaymentContext, _buildSuccessView, _cashReceivedController, _completedResult, createState, dispose, _getBadgeBackgroundColor (+17 more)

### Community 21 - "Windows Native Desktop Runner"
Cohesion: 0.13
Nodes (6): EnableFullDpiSupportIfAvailable(), Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, instance_

### Community 22 - "Printer Bluetooth Driver Module"
Cohesion: 0.09
Nodes (17): checkAndRequestPermissions, connect, _connected, _connectedAddress, disconnect, _fallbackMock, getBondedDevices, isBluetoothAvailable (+9 more)

### Community 23 - "Payment Page Test Module"
Cohesion: 0.06
Nodes (30): BookingRepository, _FakeBookingRepository, _FakeBookingRepository, _FakeBookingRepository, build, businessState, createRental, extendRental (+22 more)

### Community 24 - "Home Dashboard & Analytics"
Cohesion: 0.08
Nodes (19): _buildActiveContextBanner, _buildAllClearStatusCard, _buildDailySummary, _buildDashboardContent, _buildErrorCard, _buildImminentReturnsSection, _buildInventoryOverview, _buildKpiCard (+11 more)

### Community 25 - "Voucher & Discount Rules"
Cohesion: 0.07
Nodes (16): main, build, createVoucher, deleteVoucher, fetchVouchers, isOwner, lastCreatedPayload, lastDeletedId (+8 more)

### Community 26 - "Rental Return Processing"
Cohesion: 0.09
Nodes (14): _adapterReturned, booking, build, _cableReturned, _cameraOk, _conditionGrade, createState, _icloudRemoved (+6 more)

### Community 27 - "App Colors Module"
Cohesion: 0.09
Nodes (20): AppColors, background, border, borderSubtle, danger, dangerLight, info, infoLight (+12 more)

### Community 28 - "Cashier POS & Register"
Cohesion: 0.09
Nodes (21): bizState, build, currentShiftProvider, dateRange, effectiveBranchId, endDate, fetchBookingDetail, fetchBookingsForCashier (+13 more)

### Community 29 - "AuthNotifier"
Cohesion: 0.16
Nodes (19): AuthNotifier, AuthState, logout, customerSearchQueryProvider, build, build, _buildCategoryFilterChip, _buildFilterChip (+11 more)

### Community 30 - "cash_drawer_shift_modal.dart"
Cohesion: 0.07
Nodes (28): activeShift, branchId, build, _buildCloseShiftContent, _buildDenominationRow, _buildOpenShiftContent, CashDrawerShiftModal, _CashDrawerShiftModalState (+20 more)

### Community 31 - "Organization & Branch Management"
Cohesion: 0.11
Nodes (16): branches, businessId, businessName, copyWith, createBranch, error, inviteMember, isLoading (+8 more)

### Community 32 - "Authentication & User Session"
Cohesion: 0.10
Nodes (19): activeBranchId, activeBranchName, activeBusinessId, activeBusinessName, businesses, copyWith, error, isCentralBranch (+11 more)

### Community 33 - "../../auth/providers/business_provider.dart"
Cohesion: 0.18
Nodes (8): DashboardRepository, bizState, dashboardRepositoryProvider, fetchKpi, repo, _FakeDashboardRepository, _FakeDashboardRepository, _CapturingDashboardRepository

### Community 34 - "voucher_screen.dart"
Cohesion: 0.18
Nodes (5): createState, dispose, _isSearchExpanded, _searchController, _showThermalSlipModal

### Community 35 - "status_badge.dart"
Cohesion: 0.05
Nodes (32): appBar, backgroundColor, body, bottomSheet, build, DockAwareScaffold, DockClearance, DockEdgeInsetsExtension (+24 more)

### Community 36 - "logout_and_inventory_detail_test.dart"
Cohesion: 0.07
Nodes (22): AuthRepository, _FakeAuthRepository, build, fetchBusinesses, fetchCategories, fetchProducts, _initial, logout (+14 more)

### Community 37 - "Windows Native Desktop Runner"
Cohesion: 0.12
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 38 - "business_selector_sheet.dart"
Cohesion: 0.12
Nodes (14): _addressCtrl, _BusinessOnboardingDialog, _BusinessOnboardingDialogState, BusinessSelectorSheet, _BusinessSelectorSheetState, _cityCtrl, createState, dispose (+6 more)

### Community 39 - "Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 40 - "pos_all_branches_filter_test.dart"
Cohesion: 0.07
Nodes (26): CashierRepository, _FakeCashierRepository, bookings, build, _FakeCashierRepoForSuggestions, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods (+18 more)

### Community 41 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.06
Nodes (32): BusinessNotifier, BusinessState, _TestBusinessNotifier, _TestBusinessNotifier, build, changeBranch, fetchBookingsForCashier, fetchClosingSummary (+24 more)

### Community 42 - "Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 43 - "Inventory & Asset Catalog"
Cohesion: 0.12
Nodes (15): AssetSearchQueryNotifier, bizState, build, catalogModelsProvider, categoryId, fetchAssets, fetchCategories, fetchModels (+7 more)

### Community 44 - "Authentication & User Session"
Cohesion: 0.13
Nodes (7): copyWith, errorMessage, googleSignIn, isAuthenticated, isLoading, _repository, user

### Community 45 - "Booking Management System"
Cohesion: 0.20
Nodes (9): _client, createRental, exchangeRentalUnit, extendRental, fetchAvailableReplacements, fetchBookingDetail, fetchBookings, fetchReadyAssets (+1 more)

### Community 46 - "Authentication & User Session"
Cohesion: 0.14
Nodes (12): checkSession, _client, createBranch, createBusiness, fetchBranches, fetchBusinesses, fetchMembers, googleSignIn (+4 more)

### Community 48 - "package:flutter_riverpod/flutter_riverpod.dart"
Cohesion: 0.07
Nodes (16): main, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, _initialState, lastAmount (+8 more)

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
Cohesion: 0.15
Nodes (12): calculatePrice, checkAssetAvailability, _client, createAsset, createCategory, createProduct, fetchAssets, fetchCategories (+4 more)

### Community 54 - "booking_provider.dart"
Cohesion: 0.16
Nodes (12): BookingsScreen, build, _buildFilterChip, bizState, bookingFilterStatusProvider, bookingsListProvider, build, fetchBookings (+4 more)

### Community 55 - "assetRepositoryProvider"
Cohesion: 0.33
Nodes (6): _showQuickAddCategoryDialog, _submitProduct, _AddAssetForm, _AddAssetFormState, allCatalogModelsProvider, assetRepositoryProvider

### Community 56 - "pos_numpad.dart"
Cohesion: 0.13
Nodes (14): build, _buildActionKey, _buildKey, controller, exactAmount, _handleBackspace, _handleClear, _handleDigit (+6 more)

### Community 57 - "printer_settings_screen.dart"
Cohesion: 0.11
Nodes (20): businessProvider, _proceedToPayment, _printExchangeReceipt, _showReturnSuccessDialog, _showClosingPrintDialog, _buildBusinessErrorCard, _buildHeader, _buildQuickActionBar (+12 more)

### Community 58 - "Secure Token Storage Module"
Cohesion: 0.17
Nodes (7): clearToken, getToken, _instance, _keyToken, saveToken, SecureTokenStorage, _storage

### Community 59 - "exchange_wizard_screen.dart"
Cohesion: 0.05
Nodes (41): booking, build, _buildBillingRow, _buildBottomNavigationBar, _buildCandidateFilterChip, _buildCashChip, _buildCurrentUnitHeader, _buildHandoverRow (+33 more)

### Community 60 - "Thermal Receipt Printing Service"
Cohesion: 0.20
Nodes (7): MockPrinterDriver, connect, _FailingConnectMockDriver, _FailingWriteMockDriver, isConnected, main, writeBytes

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

### Community 66 - "thermal_receipt_preview_dialog.dart"
Cohesion: 0.12
Nodes (11): branchName, content, createState, escposBytes, _handlePrint, _isPrinting, _printerService, qrData (+3 more)

### Community 67 - "auth_lifecycle_relogin_test.dart"
Cohesion: 0.06
Nodes (24): AssetRepository, currentUserEmail, _FakeAssetRepository, fetchAssets, fetchBookings, fetchBusinesses, fetchKpi, fetchVouchers (+16 more)

### Community 68 - "ConsumerState"
Cohesion: 0.21
Nodes (10): LoginScreen, _LoginScreenState, _PosPaymentModalSheet, _PosPaymentModalSheetState, ManageOrganizationScreen, _ManageOrganizationScreenState, ReceiptCustomizationScreen, _ReceiptCustomizationScreenState (+2 more)

### Community 69 - "add_branch_expense_modal.dart"
Cohesion: 0.07
Nodes (24): banknoteDenominations, calculateChange, calculateShortage, CashPaymentSuggestionHelper, format, getSuggestedAmounts, AddBranchExpenseModal, _AddBranchExpenseModalState (+16 more)

### Community 70 - "Customer Profile Management"
Cohesion: 0.20
Nodes (8): CustomerRepository, build, customerRepositoryProvider, customerSearchResultsProvider, query, repo, searchCustomers, setQuery

### Community 71 - "Customer Profile Management"
Cohesion: 0.18
Nodes (8): ApiClient, _dio, lookupCustomer, searchCustomers, toggleBlacklist, uploadIdentityDocument, _client, fetchKpi

### Community 73 - "../../../core/utils/currency_formatter.dart"
Cohesion: 0.15
Nodes (11): build, _buildFilterChip, _buildLedgerTile, createState, dispose, FinancialActivityLedgerScreen, _FinancialActivityLedgerScreenState, _searchController (+3 more)

### Community 74 - "cashierRepositoryProvider"
Cohesion: 0.20
Nodes (10): _executePayment, _fetchAndShowReceipt, build, _handleVoidSubmit, PosTransactionDetailSheet, _printBookingReceipt, _submitCloseShift, _submitOpenShift (+2 more)

### Community 75 - "Cashier POS & Register"
Cohesion: 0.14
Nodes (13): _client, closeShift, createExpense, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchCurrentShift, fetchExpenses (+5 more)

### Community 77 - "voucherProvider"
Cohesion: 0.22
Nodes (9): checkCurrentSession, login, build, _confirmDelete, _submit, VoucherFormDialog, _VoucherFormDialogState, _buildFilterChip (+1 more)

### Community 79 - "string"
Cohesion: 0.38
Nodes (5): BookingFilterNotifier, CustomerSearchQueryNotifier, AssetStatusFilterNotifier, TransferDirectionNotifier, TransferStatusNotifier

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
Cohesion: 0.13
Nodes (14): PosFilterBranchIdNotifier, AssetCategoryFilterNotifier, build, fetchBookingDetail, fetchBookingsForCashier, fetchClosingSummary, fetchPaymentMethods, initialState (+6 more)

### Community 129 - "authProvider"
Cohesion: 0.20
Nodes (11): build, _handleGoogleSignIn, _login, authProvider, _printClosingReceipt, build, _confirmLogout, HomeScreen (+3 more)

### Community 130 - "printer_settings_screen.dart"
Cohesion: 0.18
Nodes (8): _buildChoiceChip, _buildConnectionStatusCard, _buildDiscoveredDevicesSection, _buildHardwareOptionsCard, createState, initState, PrinterSettingsScreen, _PrinterSettingsScreenState

### Community 131 - "organization_test.dart"
Cohesion: 0.18
Nodes (9): OrganizationNotifier, OrganizationState, build, loadOrganization, main, _mockInitialState, _MockOrganizationNotifier, refresh (+1 more)

### Community 132 - "transfer_provider.dart"
Cohesion: 0.17
Nodes (10): branchRecipientsProvider, build, direction, fetchDestinationAffiliates, fetchRecipients, fetchTransfers, repo, setDirection (+2 more)

### Community 133 - "bookingRepositoryProvider"
Cohesion: 0.17
Nodes (12): _showExtendDialog, _buildStep3FinancialAndAuth, ExchangeWizardScreen, _ExchangeWizardScreenState, _executeExchangeSubmission, _loadAvailableReplacements, _processReturn, bookingRepositoryProvider (+4 more)

### Community 134 - "payment_repository.dart"
Cohesion: 0.18
Nodes (5): _bookingRepo, _cashierRepo, executePayment, fetchPaymentMethods, PaymentRepository

### Community 135 - "transferRepositoryProvider"
Cohesion: 0.22
Nodes (9): _confirmApproveTransfer, _confirmCancelTransfer, _confirmReceiveTransfer, _InitiateTransferForm, _InitiateTransferFormState, _loadRecipients, _showRejectTransferDialog, destinationAffiliatesProvider (+1 more)

### Community 136 - "_TransfersScreenState"
Cohesion: 0.32
Nodes (8): build, _buildDirectionChip, _buildStatusChip, TransfersScreen, _TransfersScreenState, selectedTransferDirectionProvider, selectedTransferStatusProvider, transfersListProvider

### Community 137 - "authRepositoryProvider"
Cohesion: 0.50
Nodes (4): authRepositoryProvider, build, build, build

### Community 138 - "_DirectRentalScreenState"
Cohesion: 0.50
Nodes (4): build, DirectRentalScreen, _DirectRentalScreenState, readyAssetsProvider

## Knowledge Gaps
- **1183 isolated node(s):** `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl`, `currentLanPcBaseUrl`, `usbReverseBaseUrl` (+1178 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1381 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **50 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Win32Window` connect `Win32Window` to `Windows Native Desktop Runner`, `Size`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`, `Windows Native Desktop Runner`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **What connects `ApiConstants`, `defaultBaseUrl`, `lanPcBaseUrl` to the rest of the system?**
  _1183 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Thermal Printer Data Models` be split into smaller, more focused modules?**
  _Cohesion score 0.021505376344086023 - nodes in this community are weakly interconnected._
- **Why does `businessProvider` connect `printer_settings_screen.dart` to `Authentication & User Session`, `authProvider`, `organization_test.dart`, `ConsumerState`, `add_branch_expense_modal.dart`, `Organization & Branch Management`, `transferRepositoryProvider`, `_TransfersScreenState`, `business_selector_sheet.dart`, `_DirectRentalScreenState`, `voucherProvider`, `_CashierScreenState`, `Rental Return Processing`, `AuthNotifier`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Should `transfers_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Why does `FlutterWindow` connect `Windows Native Desktop Runner` to `Windows Native Desktop Runner`, `Win32Window`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Should `Core API & Network Client` be split into smaller, more focused modules?**
  _Cohesion score 0.03508771929824561 - nodes in this community are weakly interconnected._