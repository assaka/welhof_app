# Marello Customizations — Progress

_Custom Marello (Community Edition 3.1) work supporting the Welhof app: multi-warehouse and return/overstock lot intake._

**Instance:** `https://staging-marello.welhof.com` (= `test-marello`) · server `ssh root@116.202.155.231` · app `/var/www/html/test-marello` · Symfony 4.4 / env `dev` · DB `test_marello`.

All custom code lives under `src/Welhof/…` (no vendor files edited). Two custom bundles were added.

**Redeploy after edits:** `chown -R www-data:www-data src/Welhof && php bin/console cache:clear --env=dev`. New entity/migration: `php bin/console oro:migration:load --force` (re-run once if `RefreshExtendCacheMigration` reports a transient failure) then `oro:entity-extend:cache:warmup`.

---

## 1. Multi-warehouse — `Welhof\Bundle\WarehouseBundle` ✅ done

CE gates multiple warehouses behind Enterprise (the CE `WarehouseController` only edits the single default warehouse). This bundle unlocks it, reusing the entities/tables that already ship in CE (no schema change).

| Feature | Status | Notes |
|---|---|---|
| Warehouse CRUD (list/create/edit/delete) | ✅ | `/marello/inventory/warehouses`; datagrid + form; delete guarded (can't delete default / one holding stock) |
| "Warehouses" menu points at the list | ✅ | overrides the CE default-warehouse-only menu |
| Warehouse **group** selector | ✅ | pick an existing group **or** create one inline |
| Per-warehouse **stock** editing | ✅ | inventory-edit screen shows an editable pick-location + qty row **per warehouse**; batch-item edit crash fixed |
| Admin access | ✅ | `ROLE_ADMINISTRATOR` root grants cover the new pages/ACLs |

**Verified:** created `Warehouse NL 1`; product #3 stocked in DE (1 @ D22) + NL (25 @ NL-A-01); product #4 saved NL 7 @ NL-TEST-9 through the real form; created group `NL Group` and assigned it; batch-enabled item 16 edit page renders.

---

## 2. Return/Overstock lots — `Welhof\Bundle\LotIntakeBundle` ✅ done

**Goal:** a supplier emails a manifest (CSV/XLSX/ODS) of a mixed return/overstock lot; most items aren't in our catalog and are matched to products afterwards (in the app or manually).

**Model:** a standalone **`Lot`** (mirrors the Purchase Orders layout) containing **`LotItem`s**. Each item is *allocated* to a catalog product; allocation is a per-item action that happens after intake. (An earlier PO-coupled design was replaced by this — cleaner, and it sidesteps Marello's product-less-PO-line crash entirely, since lot items aren't PO lines.)

**Flow:**

1. **Purchasing → Lots** (`/marello/lots/`) — grid of all lots + **Create**.
2. **Create** = upload manifest (file + optional supplier + optional warehouse + condition). Creates one **Lot**; **every** row becomes a **LotItem** with a temp code (`{lotNumber}-{seq}`). Rows whose SKU matches the catalog are **auto-allocated**; the rest stay **pending**.
3. **Open a lot** → header + an **Items** grid listing all items (temp code, name, manifest SKU, qty, cost, allocated product, status). Each row has an **Allocate** action.
4. **Allocate** a pending item, two ways:
   - **Match existing** — Marello's native product picker: type-ahead SKU/name search **plus** a browse grid showing product **images**. Links the chosen product.
   - **Create new** — one click makes a minimal **disabled draft product** (name + SKU) from the item and allocates it; you complete pricing/channels/images later. (Re-uses an existing product if the SKU is already taken.)

Allocating flips the item to **allocated** and recomputes the lot's status (`new → allocating → allocated`).

**Verified end-to-end:** 5-row manifest → **`LOT000001`** (2 SKU-matched auto-allocated, 3 pending). Match-existing allocation flips item status and recomputes the lot (pending 3→2→1). Create-new produced disabled product `LOT000001-005` from the unmatched "Onbekende pallet" item and allocated it.

**Post to stock** (put-away): the lot view has a **Post to stock** button that, for each allocated item, creates an **inventory batch in the lot's own warehouse** (not Marello's default), stamps the product's **pick location**, and carries the **temp code** on the batch for traceability. Lot → `posted`. Verified end-to-end (correct quantities, one batch per item, right locations); a duplicate-batch bug for new products was found and fixed (enable batch-inventory in its own flush before adding stock).

**Unknown items — the model:** split "receive the goods" (floor, light) from "make it sellable" (office). The **LotItem (temp code + barcode + photo) is the interim identity** — never blocked on full product data. Floor captures barcode/qty/location; the office productizes + posts stock from an **"Items to enrich" queue** (cross-lot list of pending/captured items, with Allocate + Edit actions). Marello product = **SKU only** (no EAN/brand/category), which is *why* unknowns are hard and why identity is captured on the floor.

**Known limitations / not yet built:**
- **Floor capture** (app scans barcode + photo + qty + location → proxy/API updates the LotItem) and **photo storage** — not built; needs the app/proxy plus a photo-storage decision.
- Draft products are intentionally minimal (disabled, name+SKU) — the office completes pricing/channels/images before publishing.

---

## Lot-item lifecycle

```
upload manifest ──► 1 Lot ──► every row = LotItem (temp code, status=pending)
                                 │  SKU matches catalog on import? ─► auto-allocated
   FLOOR (app, ⏳):  scan barcode + photo + confirm qty + assign location  ─► captured
   OFFICE (Marello): "Items to enrich" queue ──► Allocate (match product / create draft)
                                 ▼
                     Post to stock ──► InventoryBatch in lot's warehouse,
                                       level.pickLocation set, status=posted ──► sellable
```

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **1** | Standalone Lot + LotItem; Lots list/create/view; allocation (match / create draft); clarify+notes | ✅ done |
| **1b** | Post to stock: inventory batches in the lot's warehouse + pick location | ✅ done |
| **1c** | Office **"Items to enrich"** queue (cross-lot) | ✅ done |
| **2** | Floor **capture** API (barcode/qty/location) + **photo** storage (proxy + app) | ⏳ not started |
| **3** | App loads a **Lot**, per-item capture on the floor | ⏳ not started |

---

## Demo data left on the instance (safe to delete)

- Warehouses: `Warehouse DE 1` (default), `Warehouse NL 1`; group `NL Group`.
- Inventory: product #3 NL 25 @ `NL-A-01`; product #4 NL 7 @ `NL-TEST-9`.
- Lot `LOT000001` (status **posted**): items 1, 2 (SKU-matched) and item 5 (draft product `LOT000001-005`) were **posted to stock** — batches in Warehouse DE 1 at `DE-A-01` / `DE-A-02` / `DE-B-07`. Items **3 & 4 remain pending** and appear in the **Items to enrich** queue (ready to try allocation in the UI). Upload a fresh manifest to exercise the whole flow incl. the Post-to-stock button.

_Last updated: 2026-07-15._
