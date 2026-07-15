# Floor Capture Phase — Scope

_The warehouse-floor half of the lot workflow: a worker, physically holding a lot, uses the app to capture each item (barcode + photo + qty + location). Productization happens later at the office ("Items to enrich" queue)._

## Goal / flow

The floor does **best-effort identification** (an escalating cascade), then captures; the office finalizes.

```
App loads a Lot ──► for each item:

  IDENTIFY (cascade, stop at first hit):
    1. scan barcode  ──► look up product by barcode ─┐
    2. else photo of product NAME ──► OCR ──► search products by name ─┤─► matched product?
    3. else type the product name manually ──────────┘
  CAPTURE always: product photo · qty · pick location

        └─► POST capture endpoint ─► LotItem updated (barcode, name/product, photo,
                                     qty, location), status = captured
Office later: "Items to enrich" queue ─► confirm/allocate product ─► post to stock
```

The floor never blocks — an unmatched item is still captured (barcode + photo + name + qty + location); the office finalizes productization.

## Current integration (grounding)

- **App** (Flutter; also web at `assaka.github.io`) reaches Marello two ways: **direct** to Oro JSON:API with client-side WSSE, or via **`public/welhof-proxy.php`** — a **read-only, GET-only** reverse proxy that injects a server-side WSSE credential and is CORS-locked to the web app. Product images come from a sibling `welhof-image.php`.
- **Marello** exposes entities as Oro JSON:API at `/api/<resource>` (localhost, WSSE). Orders are already consumed this way.
- **LotItem already has** the fields we need except the photo: `barcode`, `pickLocation`, `quantity`, `status` (pending/captured/allocated/posted), `tempCode`, `name`, `cost`, `notes`, `allocatedProduct`.

## Work breakdown

### A. Expose Lots + LotItems to the app (READ)  ·  _server, small_
- Add Oro `Resources/config/oro/api.yml` in `LotIntakeBundle` exposing **Lot** and **LotItem** as JSON:API resources (GET), with filters (by lot, by status) and the fields the app needs.
- The proxy is GET-only already, but only targets `marelloorders` — generalize it (or add `welhof-lots-proxy.php`) to also pass `GET /api/welhoflots` and `/api/welhoflotitems`.
- **App:** `MarelloLot` + `MarelloLotItem` models; service `fetchLots()`, `fetchLotItems(lotId)`.

### B. Capture endpoint (WRITE + photo)  ·  _server, medium_
- A **dedicated capture endpoint** (custom controller in `LotIntakeBundle`, e.g. `POST /api/welhof/lot-items/{id}/capture`) accepting **multipart**: `barcode`, `quantity`, `pickLocation`, `photo` (file). It validates, sets `status = captured`, saves the photo (see C), returns the updated item.
  - Preferred over a raw Oro JSON:API `PATCH` because JSON:API doesn't carry file uploads and we want the status transition + validation encapsulated server-side.
- **Auth:** writes must not expose the key to the browser → route through a **write-capable proxy** that injects WSSE (mirror `welhof-proxy.php`, add POST + the capture path + CORS `POST`/multipart headers). A native app with stored creds could call direct.

### C. Photo storage  ·  _decision needed — see below_
1. **Marello Attachment (File entity)** — attach the photo to the LotItem via Oro AttachmentBundle; stored in Marello's configured storage. Office sees the photo right on the item / enrich queue. No extra infra. **(Recommended.)**
2. **Proxy filesystem** — endpoint writes the file to a dir, stores a URL/path column on LotItem. Simple, but outside Marello's asset management (office UI won't show it without extra work).
3. **Object storage (S3/…)** — upload to S3, store URL. Scalable, but needs bucket + credentials.

### C-bis. Product identification (barcode + name search)  ·  _server, medium_
The identification cascade needs product lookup that Marello can't do today:
- **Add a `barcode`/EAN field to Product** (Marello has only SKU) — a custom extend field or a small column, indexed. This is what barcode scanning matches against, and closes the loop for the office too.
- **Search endpoints** (exposed to the app via the proxy):
  - `GET …/products?barcode=<ean>` — exact barcode match.
  - `GET …/products?name=<text>` — fuzzy name search (Marello already has a `products` autocomplete handler searching sku/name; reuse it).
- On a match, the capture payload references the matched product; on no match, it carries the raw name.

### C-ter. OCR of the product-name photo  ·  _client (web now) / device (native later)_
- Worker photographs the product name; OCR extracts text → feeds the name search.
- **Web (now):** browser-side OCR — `Tesseract.js`, or a server-side OCR endpoint if accuracy needs it.
- **Native (later):** on-device ML Kit text recognition (fast, offline).
- Keep OCR **pluggable** behind one `recognizeText(image)` call so web→native swaps cleanly.

### D. App screens  ·  _app, medium/large_
- **Lots list** → **Lot detail** (items) → **Item capture** screen running the identify cascade (scan → name-photo/OCR → manual) + product photo, qty, location, submit.
- **Web now** (assaka.github.io): barcode scan via a JS lib / the browser `BarcodeDetector` API; OCR via Tesseract.js; camera via web file/camera input; all traffic through the proxy (CORS).
- **Native later:** `mobile_scanner` (barcode), ML Kit (OCR), `image_picker`/`camera` (photo). Keep the capture/identify logic platform-agnostic so only the scanner/OCR/camera adapters change.

### E. Cross-cutting
- **CORS:** extend the proxy's allowed methods/headers for the capture POST + product-search GETs (web).
- **Offline/retry:** floor connectivity can be flaky — capture should queue + retry (the app already persists on-device via `shared_preferences`; reuse the pattern).

## Decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Photo storage | **Marello attachment** (office sees it on the item) |
| 2 | Platform | **Web-first** (assaka.github.io, via proxy) for dev speed; **native eventually** — keep adapters swappable |
| 3 | Identification | **Cascade:** barcode match → name-photo OCR search → manual name |
| — | Remaining | (a) OCR location — browser (Tesseract.js) vs server endpoint; (b) product barcode field — extend field vs plain column |

## Suggested sequence

1. **A** — expose Lots/LotItems (read) so the app can load a Lot.
2. **C-bis** — Product `barcode` field + barcode/name search endpoints.
3. **B** + **C** — capture endpoint (multipart) + photo as Marello attachment + write-capable proxy.
4. **C-ter** + **D** — app screens with the identify cascade (web OCR/scan first), the largest piece and the only part in this repo.

_Draft scope — 2026-07-15._
