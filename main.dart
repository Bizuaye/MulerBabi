import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database/db_helper.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.instance.database;
  runApp(const VetWholesaleApp());
}

class VetWholesaleApp extends StatelessWidget {
  const VetWholesaleApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vet Wholesale',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
