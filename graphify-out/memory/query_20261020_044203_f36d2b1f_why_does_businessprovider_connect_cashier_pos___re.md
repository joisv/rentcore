---
type: "query"
date: "2026-10-20T04:42:03.797593+00:00"
question: "Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["businessProvider", "BusinessState", "BusinessNotifier", "_CashierScreenState", "_DirectRentalScreenState", "_TransfersScreenState", "_InventoryScreenState", "_VoucherScreenState"]
---

# Q: Why does businessProvider connect Cashier POS & Register to Authentication & User Session, Asset Transfer Workflow, Voucher & Discount Rules, Business Selector Sheet Module, Booking Management System, and Inventory & Asset Catalog?

## Answer

Expanded from original query via vocab: ['business', 'provider', 'cashier', 'pos', 'auth', 'session', 'transfer', 'voucher', 'booking', 'inventory', 'branch']. businessProvider in lib/features/auth/providers/business_provider.dart (L247) acts as the multi-tenant context hub maintaining BusinessState (activeBusinessId, activeBranchId). Because every operation across POS, bookings, transfers, inventory, and vouchers is scoped to the current business tenant and active branch, businessProvider forms a central high-betweenness bridge node across all these feature communities.

## Outcome

- Signal: useful

## Source Nodes

- businessProvider
- BusinessState
- BusinessNotifier
- _CashierScreenState
- _DirectRentalScreenState
- _TransfersScreenState
- _InventoryScreenState
- _VoucherScreenState