import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/folders_model.dart';
import 'models/favorites_model.dart';
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
          seedColor: const Color.fromARGB(255, 20, 13, 26),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 3,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FoldersModel()),
          ChangeNotifierProvider(create: (_) => FavoritesModel()),
        ],
        child: const HomePage(),
      ),
    );
  }
}
