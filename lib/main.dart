import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/folders_model.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Folders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF41342F),
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white,
          surfaceContainerLow: const Color(0xFFF5F1EE),
          primary: const Color(0xFF41342F),
          onPrimary: Colors.white,
          secondary: const Color(0xFFD4A574),
          onSecondary: Colors.white,
          outline: const Color(0xFFEDE8E2),
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFEDE8E2), width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          color: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2C221E),
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C221E),
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2C221E), size: 22),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 3,
          highlightElevation: 5,
          backgroundColor: Color(0xFF41342F),
          foregroundColor: Colors.white,
          shape: CircleBorder(),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 12,
          shadowColor: Colors.black12,
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C221E),
            letterSpacing: -0.3,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF5C4E46),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F1EE),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEDE8E2), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEDE8E2), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD4A574), width: 1.5),
          ),
          hintStyle: const TextStyle(color: Color(0xFFB0A49C), fontSize: 14),
          labelStyle: const TextStyle(color: Color(0xFF8A7A72), fontSize: 14),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8A7A72),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF41342F),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEDE8E2),
          thickness: 1,
          space: 0,
        ),
      ),
      home: ChangeNotifierProvider(
        create: (_) => FoldersModel(),
        child: const HomePage(),
      ),
    );
  }
}
