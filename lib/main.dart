import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_repository.dart';
import 'services/store_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FerragemStoreApp());
}

class FerragemStoreApp extends StatefulWidget {
  const FerragemStoreApp({super.key});

  @override
  State<FerragemStoreApp> createState() => _FerragemStoreAppState();
}

class _FerragemStoreAppState extends State<FerragemStoreApp> {
  late final StoreController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StoreController(repository: AppRepository())..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ferragem Store',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A00),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFFFF7A00),
          secondary: const Color(0xFF202020),
          surface: const Color(0xFFF8F8F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F3F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF202020),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE9E9E9)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8D8D8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF7A00), width: 1.4),
          ),
        ),
      ),
      home: HomeScreen(controller: _controller),
    );
  }
}

