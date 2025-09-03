import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/restaurant_selection_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ulfasrzrtbfmtjyohzrp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVsZmFzcnpydGJmbXRqeW9oenJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1MTQyNzksImV4cCI6MjA2MzA5MDI3OX0.Et1bJV2KqGlVsuwYekUqWSOCay9Hr5DLfhVhTL4Nu1o',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,

      detectSessionInUri: true,
    ),
  );

  runApp(const MyApp());
}

SecureStorage() {
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      title: 'نظام المطعم',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Tajawal',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
     // home:  LoginScreen(),
      home: const RestaurantSelectionScreen(), // ✅ شاشة البداية
    );
  }
}

