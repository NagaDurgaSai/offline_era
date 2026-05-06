import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final user = UserProvider();
  await user.init();
  runApp(
    ChangeNotifierProvider.value(
      value: user,
      child: const OfflineEraApp(),
    ),
  );
}

class OfflineEraApp extends StatelessWidget {
  const OfflineEraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return MaterialApp(
      title: 'Offline Era',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB8FF57),
          surface: Color(0xFF0F0F0F),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      ),
      home: user.isSetup ? const HomeScreen() : const SetupScreen(),
    );
  }
}
