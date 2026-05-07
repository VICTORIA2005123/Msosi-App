import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'router/app_router.dart';
import 'widgets/realtime_connection.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'utils/seed_data.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Seed database in the background without blocking the UI
  seedDatabase().catchError((e) {
    debugPrint('Seeding failed: $e');
  });

  runApp(
    const ProviderScope(
      child: RealtimeConnection(
        child: CampusFoodApp(),
      ),
    ),
  );
}

class CampusFoodApp extends ConsumerWidget {
  const CampusFoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Msosi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722), // Vibrant Deep Orange
          primary: const Color(0xFFFF5722),
          secondary: const Color(0xFF212121), // Charcoal
          surface: const Color(0xFFFDFBF7), // Warm Cream
          onSurface: const Color(0xFF1A1A1A),
        ),
        textTheme: GoogleFonts.outfitTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.black.withOpacity(0.05)),
          ),
          color: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          brightness: Brightness.dark,
          surface: const Color(0xFF050505), // OLED Black
          onSurface: const Color(0xFFF5F5F5),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          color: const Color(0xFF121212),
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
