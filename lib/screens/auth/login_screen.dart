import 'package:flutter/material.dart';
import 'package:menu_peo2025/screens/home/home_screen.dart';
import 'package:menu_peo2025/screens/qr_scanner_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant; // ✅ بيانات المطعم المختار

  const LoginScreen({super.key, required this.restaurant});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// تسجيل دخول موظف (أدمن/كاشير/مطبخ)
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final AuthResponse response =
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = response.user;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(profile: profile),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = "خطأ: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ نافذة خيارات دخول الزبون
  void _showCustomerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.fastfood, color: Colors.teal),
            title: const Text("الدخول مباشرة"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => HomeScreen(
                    profile: {
                      "role": "customer",
                      "restaurant_id": widget.restaurant['id'],
                      "full_name": "زبون",
                      "email": "guest@local.com",
                    },
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.orange),
            title: const Text("الدخول عبر QR"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QRScannerScreen(
                    restaurant: widget.restaurant,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/screenFood.jpeg', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset("assets/amer.jpg",
                        width: 100, height: 100),
                  ),
                  const SizedBox(height: 20),

                  // كرت تسجيل دخول الموظف
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text("تسجيل الدخول",
                              style: TextStyle(
                                  color: Colors.white, fontSize: 20)),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "البريد الإلكتروني",
                              labelStyle: TextStyle(color: Colors.white),
                              prefixIcon:
                              Icon(Icons.email, color: Colors.white),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: "كلمة المرور",
                              labelStyle:
                              const TextStyle(color: Colors.white),
                              prefixIcon:
                              const Icon(Icons.lock, color: Colors.white),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.white)
                                : const Text("تسجيل الدخول"),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // زر دخول كزبون
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => _showCustomerOptions(context),
                    label: const Text("دخول كزبون"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
