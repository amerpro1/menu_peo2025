import 'package:flutter/material.dart';
import 'auth/login_screen.dart'; // تأكد أن المسار صحيح

class RestaurantSelectionScreen extends StatefulWidget {
  const RestaurantSelectionScreen({super.key});

  @override
  State<RestaurantSelectionScreen> createState() =>
      _RestaurantSelectionScreenState();
}

class _RestaurantSelectionScreenState
    extends State<RestaurantSelectionScreen> {
  List<Map<String, dynamic>> _restaurants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      // ⚠️ مؤقت: بيانات ثابتة (استبدلها بـ Supabase لاحقًا)
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _restaurants = [
          {
            "id": "09ffb5b4-b7fe-4531-855f-8a32cf7e0278",
            "name": "مطعم عامر",
            "logo_url": null
          },
          {
            "id": "914a56aa-7e84-473b-9024-be87c6b32b43",
            "name": "قصاب أوغلو",
            "logo_url": null
          },
          {
            "id": "d7283a04-8975-47c5-831c-d3b38dda666e",
            "name": "الاخوين",
            "logo_url": null
          }
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في تحميل المطاعم: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("اختر مطعمك"),
        backgroundColor: Colors.teal,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _restaurants.isEmpty
          ? const Center(child: Text("لا توجد مطاعم متاحة"))
          : ListView.builder(
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final r = _restaurants[index];
          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal,
                backgroundImage: r["logo_url"] != null
                    ? NetworkImage(r["logo_url"])
                    : null,
                child: r["logo_url"] == null
                    ? Text(
                  r["name"].toString()[0],
                  style: const TextStyle(color: Colors.white),
                )
                    : null,
              ),
              title: Text(r["name"] ?? "مطعم"),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      restaurant: r, // ✅ تمرير بيانات المطعم
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
