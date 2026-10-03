import 'package:flutter/material.dart';
import 'models/app_session.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await StorageService().getAuthSession();
  runApp(CartzLinkApp(initialSession: session));
}

class CartzLinkApp extends StatelessWidget {
  const CartzLinkApp({super.key, required this.initialSession});

  final AppSession? initialSession;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CARTZ Link',
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF93C216)),
      ),
      home: initialSession == null
          ? const LoginScreen()
          : HomeScreen(session: initialSession!),
    );
  }
}
