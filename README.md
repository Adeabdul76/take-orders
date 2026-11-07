# Take Orders (ZYWELL Bluetooth printer edition)

A mobile app for taking cafe orders and printing receipts on a **ZYWELL portable
Bluetooth thermal printer** (80mm or 58mm paper, ESC/POS). Built with Flutter.
It works offline, and everything is saved on the phone.

- The app starts **empty**. You add your own products, prices, categories and pictures.
- Tap products to add them to the cart, check out, then print the receipt.
- Changing a price later does **not** change old orders. Each order keeps a copy of the price it was sold at.
- **Receipt logo:** pick it in Shop settings. It prints in black and white at the top of every receipt.
- **Daily summary:** total sales, orders, payment types, best sellers and cashiers, with a **Print summary** button.
- **Shared cafe (optional):** all phones see the same menu, prices, logo and orders through Firebase. Staff join with a cafe code and PIN. It still works offline. Setup steps are in [FIREBASE_SETUP.md](FIREBASE_SETUP.md).

## Getting the app onto a phone

You don't need to install anything on a computer. Every change to `main` is
built automatically by GitHub (`.github/workflows/build-apk.yml`), and the
newest **TakeOrders.apk** is always on the
[Releases page](https://github.com/Adeabdul76/take-orders/releases/latest).
Open that page on the Android phone, download **TakeOrders.apk** and install it.
Installing a newer version keeps your products and orders.

## How to run it on a computer (developers only)

1. Install Flutter (stable): https://docs.flutter.dev/get-started/install
2. Connect an Android phone with USB debugging on (or an iPhone with Xcode).
3. In this folder:

```bash
flutter pub get
```

```bash
flutter run
```

To make an APK you can copy to the cafe phone:

```bash
flutter build apk --release
```

The file is `build/app/outputs/flutter-apk/app-release.apk`.

## First time on the phone

1. **Setup:** type the shop name, phone, address, cashier name, RM or MYR, and the paper size (80mm or 58mm).
2. **Add products:** Menu > Manage products > Add product.
3. **Connect the ZYWELL:** tap the printer icon (top right).
   - Turn the ZYWELL on. A blinking blue light means it is **not** connected yet.
   - Tap **Scan for ZYWELL**, allow Bluetooth/Nearby devices and Location, and tap **Connect** next to your printer. It can show up as ZY306, ZYWELL, ZM01, ZM04 or Printer_xxxx.
   - If the phone asks for a PIN, try **0000** (or 1234).
   - When the blue light stays on, it is connected. Tap **Print Test Receipt**.
4. Next time you open the app, it reconnects to the same printer automatically.

## If the receipt looks wrong

| Problem | Fix |
|---|---|
| Blank paper, strange symbols, lots of empty paper | The ZYWELL is in **Label Mode**. Hold the **SET** button to switch to ESC / Receipt Mode, then test print again. |
| Text squashed into the left side, or lines cut off | The paper size in Printer settings doesn't match the roll inside. Change 80mm / 58mm. |
| Faint print, or the printer keeps disconnecting | Battery low. Charge the ZYWELL. |
| "ZYWELL not found" | Turn it on, move the phone closer, and tap Scan again. On Android you can also pair it once in phone Bluetooth settings, and it then shows as "Paired (Classic)". |

## The overlapping "Total" fix

The old receipt printed `Total : MYR1.00Total : MYR1.00` on top of itself. This app avoids that:

- The receipt is **built once**, as one block of bytes, and **sent once** (once per copy if you choose 2 copies).
- Every line ends with exactly one line feed. Styles (bold, size, alignment) are reset after each line.
- 80mm uses **48 characters** per line and 58mm uses **32**. Item columns on 80mm are Item 24 | Qty 6 | Amount 12, with 3-space gaps (48 in total).
- Font A is used. On ZYWELL 80mm paper, Font A gives exactly 48 characters (576 dots ÷ 12). Font B would give 64, which makes a 48-character layout look squashed.
- The receipt ends with 3 feed lines, then the cut command `1D 56 00`. Printers without a cutter just ignore it.

`test/receipt_test.dart` checks all of this: TOTAL appears once and is right-aligned, every line fits the paper, and the cut is at the end. Run the tests with:

```bash
flutter test
```

## Where the code is

```
lib/
  main.dart                      app start, theme (purple #5B4DBC, 56px buttons)
  firebase_config.dart           Firebase project settings (empty = sharing off)
  models/                        product, order, order_item, printer_device, shop_settings, daily_summary
  screens/                       setup, home, cart, checkout, orders, daily summary,
                                 manage products, printer settings, cafe sharing / join
  widgets/                       product card, cart item, printer banner/icon, print helper
  services/
    data_repository.dart         one interface for both storage modes
    database_service.dart        "this phone only" storage (SQLite)
    cloud_service.dart           "shared cafe" storage (Firebase Firestore) + create/join
    zywell_printer_service.dart  ALL Bluetooth + ESC/POS code (screens never touch Bluetooth)
  providers/                     cafe (which storage), cart, product, printer, settings, orders
  utils/money.dart               RM formatting (money is stored in sen, so no rounding errors)
  utils/image_tools.dart         logo -> printer dots, product photo thumbnails
firestore.rules                  security rules to paste into Firebase
```

## Packages and why

| Package | Why | Licence |
|---|---|---|
| `print_bluetooth_thermal` | Bluetooth Classic (SPP) printing to ZYWELL on Android | Apache-2.0 |
| `flutter_reactive_ble` | Finds nearby printers and prints over BLE (needed on iPhone) | BSD-3 |
| `permission_handler` | Asks for Bluetooth / Location permission | MIT |
| `sqflite`, `shared_preferences` | Saves products, orders and settings on the phone | BSD-3 |
| `provider` | App state | MIT |
| `image_picker`, `path_provider` | Product photos from the gallery | Apache-2.0 / BSD-3 |
| `intl` | Date format on receipts | BSD-3 |
| `firebase_core`, `cloud_firestore`, `firebase_auth` | Shared cafe data, offline copy, anonymous phone sign-in | BSD-3 |
| `image` | Turns the logo into printer dots; small product photos | MIT |

`flutter_blue_plus` is **not** used, even though the brief names it as the backup option. Its current licence requires a **paid commercial licence** for business use, and a cafe counts as a business. `flutter_reactive_ble` does the same job here for free.

## Known limits

- **Paper Out** cannot be read back from most portable ZYWELL models over Bluetooth, so the app can't detect it. If nothing prints, check the paper.
- **Label Mode** also can't be detected automatically. The app shows the "Hold SET" instructions in Printer settings and in this README.
- Thermal printers in ESC/POS mode only print basic English letters. Chinese or Tamil characters and emoji in product names print as `?` on the receipt, though they still show in the app.
