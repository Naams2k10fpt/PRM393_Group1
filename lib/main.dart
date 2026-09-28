import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/kahoot_entry_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuizManagementApp());
}

class QuizManagementApp extends StatelessWidget {
  const QuizManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz Management Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: KahootColors.background,
          primary: KahootColors.background,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const KahootEntryScreen(),
    );
  }
}
