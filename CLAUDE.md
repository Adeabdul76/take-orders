# CLAUDE.md - Take Orders App - ZYWELL Bluetooth Printer Edition

## Project Overview
- Build a mobile-first "Take Orders" app for my cafe in Bukit Mertajam, Penang.
- Printer: ZYWELL Portable Bluetooth Thermal Printer - Black round model in photo, battery powered, blue Bluetooth light on front.
- Core Rules: NO hardcoded products. NO hardcoded prices. App starts EMPTY. User adds products themselves inside app.
- After checkout, print receipt via Bluetooth to ZYWELL printer.

## Printer Hardware - LOCKED - DO NOT CHANGE
- Brand: ZYWELL
- Type: Portable Thermal Receipt Printer, Direct Thermal, No Ink
- Paper: 80mm thermal paper roll - DEFAULT. Also supports 58mm if user changes roll. App must ask: "What paper is in your ZYWELL now? 80mm or 58mm?"
- Resolution: 203 dpi, 8 dots/mm
- Print Width: 80mm = 72mm printable = 48 characters per line. 58mm = 32 characters per line. (Implemented with ESC/POS Font A: 576 dots / 12 = 48, 384 / 12 = 32.)
- Command Language: ESC/POS ONLY. Must be in Receipt Mode / ESC Mode. NOT in Label Mode / TSPL Mode.
- Connection: Bluetooth Classic (SPP) + BLE. Android: Pair INSIDE the app, not in Android Settings. iOS: Pair inside app.
- Bluetooth Name: Usually shows as ZY306, ZYWELL, ZM01, ZM04, or Printer_xxxx. App must show all nearby devices, do not filter to only one name.
- PIN: Usually 0000 or 1234 if asked. App must show hint: "If asked for PIN, try 0000"
- Battery: Rechargeable Li-ion. If battery low, printing gets faint. App must warn if printer disconnects.
- Buttons on printer: Power button + Feed button. Blue light = Bluetooth connected. If blue light blinking, it is NOT connected yet.

## Tech Stack - ZYWELL Optimized
- Framework: Flutter
- Packages: `print_bluetooth_thermal` for ZYWELL Bluetooth Classic (ESC/POS bytes).
- BLE scan/connect/print: `flutter_reactive_ble` (BSD-3). Do NOT use `flutter_blue_plus`: its licence now requires a paid commercial licence for business use.
- ESC/POS bytes are built by hand in `zywell_printer_service.dart` (no esc_pos_utils needed).
- Storage: `DataRepository` interface with two versions:
  - this phone only: SQLite (`sqflite`) + `shared_preferences` (database_service.dart)
  - shared cafe: Firebase Firestore with offline persistence (cloud_service.dart). Phones sign in anonymously and join with cafe code + PIN, enforced by firestore.rules. Firebase settings live in lib/firebase_config.dart (empty = sharing off).
- Cloud writes are never awaited (they queue offline). Order numbers = device letter + per-phone counter (A001, B001), so they are unique offline.
- Images: `image` package. Product photos are stored as small base64 JPEG inside the product (shared). Logo is stored as base64 PNG in shop settings and printed with ESC/POS raster GS v 0 in 64-row bands (320 dots wide on 80mm, 256 on 58mm).
- State: Provider
- UI: Material Design 3, Purple #5B4DBC, White cards, Big buttons min 56px

## Folder Structure
lib/
  main.dart, firebase_config.dart
  models/ product.dart, order.dart, order_item.dart, printer_device.dart, shop_settings.dart, daily_summary.dart
  screens/ setup_screen.dart, home_screen.dart, cart_screen.dart, checkout_screen.dart, orders_screen.dart,
           daily_summary_screen.dart, manage_products_screen.dart, printer_settings_screen.dart, cafe_sharing_screen.dart
  widgets/ product_card.dart, cart_item_tile.dart, printer_status_banner.dart, print_helper.dart
  services/ data_repository.dart, database_service.dart (local), cloud_service.dart (Firebase),
            zywell_printer_service.dart - ALL Bluetooth + ESC/POS code here ONLY
  providers/ cafe_provider.dart, cart_provider.dart, product_provider.dart, printer_provider.dart,
             settings_provider.dart, order_provider.dart
  utils/ money.dart, image_tools.dart
firestore.rules, FIREBASE_SETUP.md

Rule: NEVER put Bluetooth code in screens.

## CRITICAL FIX - Overlapping Receipt ("Total : MYR1.00Total : MYR1.00")
- NEVER print the same line twice. Build receipt bytes ONCE, then send ONCE (per copy).
- NEVER use 32-char formatting on 80mm paper. 80mm = 48 chars, 58mm = 32 chars.
- Fixed column widths for 80mm: Item Name 24 left, Qty 6 center, Amount 12 right, two 3-space gaps = 48.
- "Total: MYR 14.00" must appear ONCE, right-aligned, on its own line. (Covered by test/receipt_test.dart.)
- 1 empty line between sections. No \n in the middle of a line.
- After printing: 3 empty lines, then Cut Command [0x1D, 0x56, 0x00].

## ZYWELL Printer Service - zywell_printer_service.dart
- checkBluetoothOn(): If OFF, show popup "Turn on Bluetooth to connect to ZYWELL"
- requestPermissions(): Bluetooth Scan, Bluetooth Connect, Location. Explain: "Needed to find your ZYWELL printer"
- scanDevices(): Scan 10 seconds, show list: Name + MAC. Show "Scanning for ZYWELL..."
- connect(device): Connect, save as Default Printer.
- autoReconnect(): On app start, reconnect to last saved ZYWELL.
- disconnect(): Disconnect + Forget option.
- printReceipt(order): Build ESC/POS bytes -> Send -> Success / Fail
- printTestReceipt(): "ZYWELL TEST - SUCCESS" + Date + "Paper: 80mm"
- getStatus(): Connected / Disconnected / Printing / Error / Paper Out

Error Handling - Friendly Messages, Never Crash:
- Bluetooth OFF: "Please turn on Bluetooth"
- Printer not found: "ZYWELL not found. 1. Turn ZYWELL ON, 2. Blue light blinking? 3. Move phone close, 4. Tap Scan again"
- Disconnected mid-print: "Print failed. ZYWELL disconnected. Reconnect and tap Reprint"
- Label Mode: "Your ZYWELL is in Label Mode. Hold SET button to switch to ESC / Receipt Mode"

## Receipt Format - 80mm - 48 Chars
      [SHOP NAME - Center, Bold, Double Size]
      [Phone / Address - Center]

Date: 06 Nov 2026 02:30 PM
Order: #001 Cashier: Owner

Item Qty Amount
Nasi Lemak 1 RM 8.00
Teh Tarik 2 RM 6.00

Subtotal RM 14.00
TOTAL RM 14.00
Payment: Cash
Cash Given: RM 20.00
Change: RM 6.00

    Thank you! Come again!
[CUT]

- Bold ON for Shop Name and TOTAL only.
- Center for header/footer, Left for items, totals right-aligned.
- RM or MYR from Setup. Default: RM.

## Product Management - User Controls Everything
- App starts EMPTY.
- Add Product: Name (required), Price (required, >0), Category (user creates own), Image (Gallery OR Emoji), Availability Toggle.
- Manage Products: List, Search, Edit Price anytime, Delete with confirm, Duplicate.
- Changing price later must NOT change old orders (order items store a price snapshot).

## Home / Cart / Checkout Flow
1. Home: Shop Name + Today's Sales + Printer Icon (Green = connected, Grey = not). Tap icon to connect.
2. If ZYWELL not connected, banner: "ZYWELL not connected - Tap to connect"
3. Tap Product = Add to cart. Floating bar: "X items - RM XX.XX"
4. Cart: + / -, Remove, Note per item.
5. Checkout: Save order -> Success -> [Print Receipt with ZYWELL] [Done]
6. Auto-Print ON = print automatically.
7. Orders Screen: every order has [Reprint].

## Printer Settings Screen
- Current ZYWELL: Name + Status + [Disconnect] [Forget]
- Scan: [Scan for ZYWELL]
- Paper Size: 80mm (Default) / 58mm - MUST match paper inside printer
- Auto-Print: ON / OFF
- Copies: 1 / 2
- Test Print: [Print Test Receipt]
- Mode Check: "Is your ZYWELL in Receipt Mode? If the receipt prints blank, prints strange symbols, or feeds a lot of empty paper, your ZYWELL is in Label Mode. Hold the SET button to switch to ESC / Receipt Mode, then print a test receipt again."

(The original brief was cut off at "Mode Check". The text above and the items below were filled in with sensible defaults. Change them if needed.)

## Added features (Nov 2026)
- Receipt logo: chosen in Shop settings, shared to all phones, printed instead of the shop-name text.
- Daily summary screen (date picker, total sales, orders, average, by payment, best sellers, by cashier) + Print summary.
- Shared cafe across phones (Firebase): menu, prices, photos, shop details, logo and orders. Each phone keeps its own cashier name, paper size, auto-print, copies and printer.

## Filled-in defaults
- Setup screen: Shop name (required), phone, address, cashier name, RM/MYR, paper size, footer message.
- Payment methods: Cash, DuitNow QR, Card, E-Wallet. Cash shows Cash Given + Change with quick buttons (Exact, RM 10/20/50/100).
- Order numbers: #001, #002, ... per phone; in a shared cafe #A001, #B001 (letter per phone).
- Product names print in basic English letters only; other characters print as "?".
