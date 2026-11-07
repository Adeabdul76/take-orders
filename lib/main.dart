import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/cafe_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/cloud_service.dart';
import 'services/database_service.dart';
import 'services/zywell_printer_service.dart';

const brandPurple = Color(0xFF5B4DBC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsProvider();
  final products = ProductProvider();
  final orders = OrderProvider();
  final cart = CartProvider();
  final cafe = CafeProvider(CloudService.instance, LocalRepository.instance);
  await settings.load();
  await cafe.init();

  // Point everything at the right data: this phone, or the shared cafe.
  void attachAll() {
    settings.attach(cafe.repo);
    products.attach(cafe.repo);
    orders.attach(cafe.repo);
    cart.attach(cafe.repo);
  }

  attachAll();
  cafe.addListener(attachAll);

  final printer = PrinterProvider(ZywellPrinterService.instance);
  // Try to reconnect to the last ZYWELL in the background.
  printer.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: cafe),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: products),
        ChangeNotifierProvider.value(value: orders),
        ChangeNotifierProvider.value(value: printer),
        ChangeNotifierProvider.value(value: cart),
      ],
      child: const TakeOrdersApp(),
    ),
  );
}

class TakeOrdersApp extends StatelessWidget {
  const TakeOrdersApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      primary: brandPurple,
      surface: Colors.white,
    );
    const bigButton = Size(64, 56);
    final setupDone = context.select<SettingsProvider, bool>(
      (s) => s.setupDone,
    );

    return MaterialApp(
      title: 'Take Orders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F4FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandPurple,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(color: Colors.white, elevation: 1),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: bigButton,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: bigButton,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(minimumSize: bigButton),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: setupDone ? const HomeScreen() : const SetupScreen(),
    );
  }
}
