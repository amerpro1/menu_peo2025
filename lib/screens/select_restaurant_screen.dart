import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home/home_screen.dart';

class SelectRestaurantScreen extends StatefulWidget {
  const SelectRestaurantScreen({super.key});

  @override
  State<SelectRestaurantScreen> createState() => _SelectRestaurantScreenState();
}

class _SelectRestaurantScreenState extends State<SelectRestaurantScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _restaurants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    try {
      final data = await supabase.from("restaurants").select("id, name, logo_url").order("created_at");
      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("اختر مطعمك")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final r = _restaurants[index];
          return ListTile(
            leading: r["logo_url"] != null
                ? Image.network(r["logo_url"], width: 40, height: 40, fit: BoxFit.cover)
                : const Icon(Icons.store, size: 40),
            title: Text(r["name"] ?? "بدون اسم"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => HomeScreen(profile: {
                    "id": "guest",
                    "role": "customer",
                    "restaurant_id": r["id"],
                    "full_name": "زبون",
                    "email": ""
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
