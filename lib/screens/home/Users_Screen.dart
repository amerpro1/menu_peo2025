import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const UsersScreen({super.key, this.profile});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  bool _isAdmin = false;
  String? _restaurantId;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  /// التحقق من دور المستخدم وجلب restaurant_id الخاص به
  Future<void> _checkRoleAndLoad() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception("لم يتم تسجيل الدخول");

      final row = await supabase
          .from("profiles")
          .select("id, role, restaurant_id, name")
          .eq("id", uid)
          .maybeSingle();

      if (row == null) throw Exception("لا يوجد بروفايل مرتبط");

      setState(() {
        _currentUserId = row["id"];
        _currentUserName = row["name"];
        _isAdmin = row["role"] == "admin";
        _restaurantId = row["restaurant_id"];
      });

      if (_restaurantId != null) {
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e")),
        );
      }
    }
  }

  /// تحميل جميع المستخدمين لهذا المطعم
  Future<void> _loadUsers() async {
    if (_restaurantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لا يوجد مطعم مرتبط بالحساب")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from("profiles")
          .select("id, name, email, role, restaurant_id, created_at")
          .eq("restaurant_id", _restaurantId!)
          .order("created_at", ascending: false);

      debugPrint("✅ عدد الحسابات: ${rows.length}");
      setState(() {
        _users = (rows as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("❌ خطأ تحميل المستخدمين: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  /// نافذة إضافة أو تعديل مستخدم
  Future<void> _userDialog({Map<String, dynamic>? user}) async {
    final emailCtrl = TextEditingController(text: user?["email"] ?? "");
    final nameCtrl = TextEditingController(text: user?["name"] ?? "");
    final passCtrl = TextEditingController();
    String role = user?["role"] ?? "cashier";

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(user == null ? "إضافة مستخدم" : "تعديل مستخدم"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "البريد الإلكتروني"),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "الاسم"),
                ),
                if (user == null)
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: "كلمة المرور"),
                    obscureText: true,
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: "admin", child: Text("مدير")),
                    DropdownMenuItem(value: "cashier", child: Text("كاشير")),
                    DropdownMenuItem(value: "kitchen", child: Text("مطبخ")),
                  ],
                  onChanged: (v) => role = v ?? "cashier",
                  decoration: const InputDecoration(labelText: "الدور"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                try {
                  // 🟢 تأكيد الحصول على restaurant_id الصحيح
                  if (_restaurantId == null) {
                    final adminProfile = await supabase
                        .from("profiles")
                        .select("restaurant_id")
                        .eq("id", supabase.auth.currentUser!.id)
                        .maybeSingle();

                    if (adminProfile == null) {
                      throw Exception("⚠️ لا يوجد مطعم مرتبط بحساب المدير");
                    }
                    _restaurantId = adminProfile["restaurant_id"];
                  }

                  if (user == null) {
                    // إنشاء مستخدم جديد
                    final authResp = await supabase.auth.signUp(
                      email: emailCtrl.text.trim(),
                      password: passCtrl.text.trim(),
                    );
                    final newUser = authResp.user;
                    if (newUser == null) throw Exception("فشل إنشاء الحساب");

                    await supabase.from("profiles").insert({
                      "id": newUser.id,
                      "email": emailCtrl.text.trim(),
                      "name": nameCtrl.text.trim(),
                      "role": role,
                      "restaurant_id": _restaurantId,
                    });
                  } else {
                    // تعديل بيانات مستخدم
                    await supabase.from("profiles").update({
                      "email": emailCtrl.text.trim(),
                      "name": nameCtrl.text.trim(),
                      "role": role,
                    }).eq("id", user["id"]);
                  }

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(user == null ? "✅ تمت الإضافة" : "✅ تم التعديل")),
                    );
                    _loadUsers();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  /// حذف مستخدم
  Future<void> _deleteUser(String id) async {
    if (id == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لا يمكنك حذف حسابك الحالي")),
      );
      return;
    }

    try {
      await supabase.from("profiles").delete().eq("id", id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم الحذف")),
        );
        _loadUsers();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة حسابات المطعم"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () => _userDialog(),
        child: const Icon(Icons.add),
      )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_currentUserName != null)
            Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.teal, size: 40),
                title: Text(
                  _currentUserName!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("مدير المطعم الحالي"),
              ),
            ),
          const Divider(),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text("لا يوجد مستخدمين بعد"))
                : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.teal),
                    title: Text(u["name"] ?? ""),
                    subtitle: Text("${u["email"]} - الدور: ${u["role"]}"),
                    trailing: _isAdmin
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _userDialog(user: u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(u["id"]),
                        ),
                      ],
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
