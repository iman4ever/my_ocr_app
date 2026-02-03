import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/receipt_provider.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReceiptProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          // Define color schemes for light and dark to ensure consistent Material 3 styling
          final lightScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF00B894), // Premium Teal/Green
            secondary: const Color(0xFF0984E3),
            surface: Colors.grey[50]!,
          );

          final darkScheme = ColorScheme.fromSeed(
            seedColor: const Color(0xFF00B894),
            brightness: Brightness.dark,
            secondary: const Color(0xFF0984E3),
          );

          return MaterialApp(
            title: 'My Receipts',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: lightScheme,
              textTheme: GoogleFonts.outfitTextTheme(), // Premium Font
              appBarTheme: AppBarTheme(
                backgroundColor: lightScheme.surface,
                elevation: 0,
                iconTheme: IconThemeData(color: lightScheme.onSurface),
                titleTextStyle: TextStyle(color: lightScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: lightScheme.surface,
                elevation: 3,
                indicatorColor: lightScheme.primaryContainer,
                labelTextStyle: MaterialStateProperty.all(TextStyle(color: lightScheme.onSurface)),
              ),
              cardTheme: CardThemeData(
                color: lightScheme.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: lightScheme.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                titleTextStyle: TextStyle(color: lightScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                contentTextStyle: TextStyle(color: lightScheme.onSurface),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme: darkScheme,
              textTheme: GoogleFonts.outfitTextTheme(ThemeData(brightness: Brightness.dark).textTheme),
              appBarTheme: AppBarTheme(
                backgroundColor: darkScheme.surface,
                elevation: 0,
                iconTheme: IconThemeData(color: darkScheme.onSurface),
                titleTextStyle: TextStyle(color: darkScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: darkScheme.surface,
                elevation: 3,
                indicatorColor: darkScheme.primaryContainer,
                labelTextStyle: MaterialStateProperty.all(TextStyle(color: darkScheme.onSurface)),
              ),
              cardTheme: CardThemeData(
                color: darkScheme.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: darkScheme.surface,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                titleTextStyle: TextStyle(color: darkScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                contentTextStyle: TextStyle(color: darkScheme.onSurface),
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const ScanScreen(),
    const HistoryScreen(),
    const StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        elevation: 3,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner), // Prominent scan icon
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart), 
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
