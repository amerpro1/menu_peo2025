import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:menu_peo2025/screens/home/home_screen.dart';

class LoginScreen  extends StatefulWidget {
  const LoginScreen ({super.key});

  @override
  State<LoginScreen > createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<LoginScreen > {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _supabase.auth.onAuthStateChange.listen(_handleAuthChange);
    await _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      await _fetchUserProfile(currentUser);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleAuthChange(AuthState data) async {
    if (data.session?.user != null) {
      await _fetchUserProfile(data.session!.user);
    } else {
      setState(() {
        _user = null;
        _profile = null;
      });
    }
  }

  Future<void> _fetchUserProfile(User user) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      // تعيين restaurant_id في الجلسة الحالية بعد تسجيل الدخول
      if (profile['restaurant_id'] != null) {
        await _supabase.rpc('set_current_restaurant', params: {
          'restaurant_uuid': profile['restaurant_id']
        });
      }

      setState(() {
        _user = user;
        _profile = profile;
      });
    } catch (e) {
      setState(() {
        _user = user;
        _profile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) return const LoginScreen();

    if (_profile == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('بيانات المستخدم غير متوفرة'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _supabase.auth.signOut(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      );
    }

    return HomeScreen(profile: _profile!);
  }
}