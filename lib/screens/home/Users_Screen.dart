import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersScreen extends StatefulWidget {
  final Map<String, dynamic>? profile; // بروفايل المدير الحالي

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

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  /// التحقق من الدور وجلب المستخدمين
  Future<void> _checkRoleAndLoad() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        throw Exception("لم يتم تسجيل الدخول");
      }

      final rows = await supabase
          .from("profiles")
          .select("role, restaurant_id")
          .eq("id", uid)
          .limit(1); // ✅ نرجع List دائمًا

      if (rows.isEmpty) {
        throw Exception("لا يوجد بروفايل مرتبط بهذا المستخدم");
      }

      final profile = rows.first;

      setState(() {
        _isAdmin = profile["role"] == "admin";
        _restaurantId = profile["restaurant_id"];
      });

      if (_restaurantId != null) {
        _loadUsers(_restaurantId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("خطأ: $e")));
      }
    }
  }

  /// تحميل المستخدمين للمطعم الحالي
  Future<void> _loadUsers(String rid) async {
    setState(() => _loading = true);
    try {
      final rows = await supabase
          .from("profiles")
          .select("id, name, email, role, restaurant_id")
          .eq("restaurant_id", rid)
          .order("created_at", ascending: false);

      setState(() {
        _users = (rows as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint("خطأ تحميل المستخدمين: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  /// إضافة أو تعديل مستخدم
  Future<void> _userDialog({Map<String, dynamic>? user}) async {
    final emailCtrl = TextEditingController(text: user?["email"] ?? "");
    final nameCtrl = TextEditingController(text: user?["name"] ?? "");
    final passCtrl = TextEditingController();
    String role = user?["role"] ?? "cashier";

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(user == null ? "إضافة مستخدم جديد" : "تعديل مستخدم"),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (_restaurantId == null) throw Exception("لا يوجد مطعم مرتبط");

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
                      SnackBar(
                        content: Text(user == null
                            ? "تمت إضافة المستخدم"
                            : "تم تعديل المستخدم"),
                      ),
                    );
                  }
                  if (_restaurantId != null) {
                    _loadUsers(_restaurantId!);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ: $e")),
                  );
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  /// تأكيد الحذف
  Future<void> _confirmDeleteUser(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: Text("هل أنت متأكد من حذف الحساب ($name) ؟"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("حذف"),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteUser(id);
    }
  }

  /// حذف مستخدم
  Future<void> _deleteUser(String id) async {
    try {
      await supabase.from("profiles").delete().eq("id", id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حذف الحساب")),
        );
      }
      if (_restaurantId != null) {
        _loadUsers(_restaurantId!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("فشل الحذف: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.profile?['name'] ?? "مدير";

    return Scaffold(
      appBar: AppBar(title: const Text("إدارة حسابات المطعم")),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
        onPressed: () => _userDialog(),
        child: const Icon(Icons.add),
      )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // بطاقة المدير الحالي
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.verified_user,
                  size: 40, color: Colors.teal),
              title: Text(
                userName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text("مدير المطعم الحالي"),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.teal),
                    title: Text(u["name"] ?? ""),
                    subtitle:
                    Text("${u["email"]} - الدور: ${u["role"]}"),
                    trailing: _isAdmin
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue),
                          onPressed: () => _userDialog(user: u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () =>
                              _confirmDeleteUser(u["id"], u["name"]),
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
