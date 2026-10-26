# Clever Bill – Flutter mobile app

Billing • Inventory • Growth. Flutter (Android first) client for the existing `clever-bill-api` Spring Boot backend,
following the UX screens shared (Welcome → OTP login → Shop setup → Home / POS / Bills / Inventory / More).

## 1. First-time setup
```bash
# inside this folder (needs Flutter 3.22+ / Dart 3.3+)
flutter create . --org in.cleverbill --project-name clever_bill_mobile   # generates android/ ios/ (keeps lib/)
flutter pub get
```
1. **Android manifest** – copy the permissions/queries from `android_setup/AndroidManifest.additions.xml`
   into `android/app/src/main/AndroidManifest.xml`.
2. **minSdk** – in `android/app/build.gradle(.kts)` set `minSdk = 23`.
3. **Firebase** (same project as the web app, `invoicepro-dasp`):
   Firebase console → Add Android app (package `in.cleverbill.clever_bill_mobile` or your own) →
   add your debug/release **SHA-1 and SHA-256** → download `google-services.json` into `android/app/` →
   enable the Google Services Gradle plugin (`flutterfire configure` does all of this automatically).
   Phone OTP and Google sign-in will not work without the SHA keys.
4. **API URL** – the base URL is passed at build time (default in `lib/core/config/env.dart` is only a placeholder):
```bash
flutter run --dart-define=API_BASE_URL=https://<your-backend-host>
flutter build apk --release --dart-define=API_BASE_URL=https://<your-backend-host>
```

### Running in Chrome (web)
The backend CORS list only allows `http://localhost:3000/5173/5174` and the cleverbill.in domains, so Chrome **must** use a fixed allowed port:
```bash
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://api.cleverbill.in
```
Email + password login works on web. Phone OTP / Google / push need Firebase (Android recommended).
To test on a random port, add that origin to `CorsConfig.java` in the backend.

## 2. Architecture
```
lib/
  core/      theme, Dio ApiClient (envelope unwrap, Firebase/JWT token + 401 refresh, X-Branch-Id), session store, shared widgets
  data/      models.dart (tolerant JSON models), api.dart (every endpoint used by the app)
  providers.dart   Riverpod: auth, branch, products, invoices, customers, cart …
  router.dart      go_router with auth/setup redirect + 5-tab shell (Home, Bills, New Bill, Inventory, More)
  features/  auth · home · pos · invoices · inventory · customers · suppliers · reports · notifications · more
```

## 3. Feature map (web → mobile)
| Area | Included |
|---|---|
| Auth | Phone OTP (Firebase) → `/api/auth/phone`, Google, email+password, shop setup (2 steps), sign-out, delete account |
| Home | Today sales/profit/dues/bills, 7-day chart, quick actions, low-stock alert, recent bills, branch switcher, notification bell |
| POS | Product search + categories, barcode scan (camera), cart, discount, customer select/add, Cash/UPI(QR)/Card/Credit, credit-limit check, success screen: Print / WhatsApp / PDF |
| Bills | Month filter, search, status counts, filters, invoice detail, cancel, return items, receive payment, GST invoice (3-step) |
| Inventory | Products (list/add/edit/delete, photo, barcode), categories, stock overview, adjust stock, movements, reorder → purchase |
| Purchases | List, detail, new purchase (receives stock), cancel |
| Customers | List, ledger/bills/details, add/edit, call/WhatsApp, Payments & Dues with reminders |
| Suppliers | List, details, purchase history, RFQs, quotation accept/reject |
| Returns / Expenses | Returns list + approve/reject; expenses add/edit/delete with categories |
| Reports | Today/Week/Month/Custom, trend chart, top products, Excel/CSV export |
| Settings | Business & tax (Simple/GST), invoice design toggles, Bank & UPI, notifications, backup export, branches & staff |
| Push | FCM token registration + foreground notifications with sound |
| Account | Email sign-up (2 steps), profile (name/phone/photo), forgot password |
| Search | Global search (products, customers, invoices, expenses, categories) |
| Insights | Product / category / customer / invoice / expense analytics (30 days, 6 months, 1 year) |
| Branches | Branch list, staff, per-branch activity dashboard |
| Appearance | Light/Dark mode, 5 brand colours, font size (same as web) |
| Settings+ | GST & tax, business defaults, invoice design, printer layout, privacy policy |
| Quotations | Accept/reject + PDF share |
| Languages | English / हिन्दी / मराठी (Settings → Language, or Welcome screen) – ~660 UI strings translated, others stay English |
| Razorpay | Pay online (UPI/Card) from the payment screen – creates the bill, opens Razorpay checkout, verifies on the server (Android/iOS only) |
| POS extras | % or ₹ discount, bill notes, customer signature, credit-sale payment mode, partial online payment (Razorpay) |
| Expenses | Approve / reject pending expenses (owner) |
| Expiry | Expiring-soon and expired product lists |
| Quotations | All supplier quotations in one list, RFQ PDF, cancel RFQ |
| Invoice design | Template (Classic/Modern/GST), colours, fonts, signature, logo upload |
| Security | App lock with 4-digit PIN + fingerprint (optional) |
| Printing | Bluetooth ESC/POS thermal receipt printing (58/80 mm) |
| Roles | Branch employees (BRANCH_EMPLOYEE) see only the screens the web gives them; owner-only pages are hidden and blocked |
| RFQ detail | Supplier info, delivery & terms, requested items, PDF |
| Phone scanner | More → Settings → Phone scanner for web POS: scan the QR on the web POS and push barcodes live (STOMP WebSocket) |

## 3b. Extra setup for the newest features
* `android_setup/AndroidManifest.additions.xml` – Bluetooth + biometric permissions (and the MainActivity note for fingerprint).
* Icons / splash:  `dart run flutter_launcher_icons`  then  `dart run flutter_native_splash:create`  (assets are in `assets/icon/`).
* iOS: `flutter create . --platforms=ios`, then add `ios_setup/Info.plist.additions.xml` to `ios/Runner/Info.plist`.

## 5. Release notes – stabilisation pass
* **Sign-up fixed:** the `/auth/register` route was missing from `router.dart`, so *Create an account* crashed. Route added,
  Welcome screen now has *Create account with email* and *Already have an account? Sign in*.
* Sign-up recovers from a half-finished earlier attempt (Firebase user exists but backend registration failed) and blocks double taps.
* Phone OTP: send/resend no longer leave the button spinning on errors; OTP auto-submit + button can no longer verify twice.
* **Categories:** category filter chips on Inventory → Products, and a *New category* shortcut inside Add/Edit product
  (auto-selects the new category). Dropdowns can no longer crash when a product has an unknown category/unit,
  and Edit expense no longer crashes on an unknown expense category.
* Expense category colours now follow the selected brand colour; theme polish (smooth page transitions, rounded snackbars/buttons).
* **Tests:** `flutter test` (logic + route tests) and `dart run tool/check_routes.dart` (fails if any screen links to a missing route).

## 4. Known gaps / things to verify on first run
* **Walk-in cash bills:** the backend (`/api/pos/checkout`, `/api/invoices`) requires a customer mobile number, so the app attaches
  walk-in bills to one shared customer “Walk-in Customer” (mobile 9999999999, created on first use). A small backend change
  (optional mobile / null customer) would be cleaner.
* Supplier *payable* amounts, “Collected” on Home and per-period *gross profit* are not exposed by the API, so the UI shows
  Profit (today), purchases total and “Sales − expenses” instead.
* Language switch (Hindi/Marathi) is a placeholder – strings are English only.
* The backend has no batch-wise stock, purchase-return API or per-staff permission model, so those are not in the app (expiry is per product).
* Stock *Movements* tab asks you to pick a product first (API is per-product).
* Logo/product images upload through `/api/products/upload-image`.
* Settings payload keys were taken from the backend DTOs; if a save returns 400, check the field name in `lib/features/more`.
* This code was written without a Flutter SDK available to compile it. All files pass a Dart parser check,
  but expect to fix a few analyzer messages on the first `flutter analyze`.
