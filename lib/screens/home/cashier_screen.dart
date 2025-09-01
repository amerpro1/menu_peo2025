import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../orders/orders_screen.dart';
import '../unpaid_orders_screen.dart';
import 'users_screen.dart';

class CashierScreen extends StatelessWidget {


  Future<String> _getRestaurantId() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('لم يتم تسجيل الدخول');
    }
    final row = await Supabase.instance.client
        .from('profiles')
        .select('restaurant_id')
        .eq('id', uid)
        .single();
    final rid = row['restaurant_id'] as String?;
    if (rid == null) {
      throw Exception('لم يتم العثور على مطعم للمستخدم');
    }
    return rid;
  }

  final Map<String, dynamic> profile;
  SupabaseClient get supabase => Supabase.instance.client;

  const CashierScreen({super.key, required this.profile});

  Future<void> _deleteOrder(BuildContext context, int orderId) async {
    try {
      await supabase.from('orders').delete().eq('id', orderId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الطلب بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CashierScreen(profile: profile),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حذف الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeOrder(BuildContext context, int orderId, String? tableNumber) async {
    try {
      // تحديث حالة الطلب إلى مكتمل
      await supabase.from('orders').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String()
      }).eq('id', orderId);

      // إذا كان الطلب مرتبطاً بطاولة، قم بتحديث حالة الطاولة أيضاً
      if (tableNumber != null) {
        await supabase.from('tables').update({
          'order_status': 'completed'
        }).eq('number', tableNumber).eq('restaurant_id', await _getRestaurantId());
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسليم الطلب للزبون بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CashierScreen(profile: profile),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسليم الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeOrder(BuildContext context, int orderId, String? tableNumber, String paymentStatus) async {
    try {
      if (paymentStatus == 'unpaid' || paymentStatus == 'غير مدفوع') {
        // إذا كان غير مدفوع، انتقل إلى شاشة الطلبات غير المدفوعة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnpaidOrdersScreen(
              initialOrderId: orderId.toString(),
            ),
          ),
        );
      } else {
        // إذا كان مدفوعاً، أغلق الطلب وحرر الطاولة
        await supabase.from('orders').update({
          'status': 'closed',
          'closed_at': DateTime.now().toIso8601String()
        }).eq('id', orderId);

        // إذا كان الطلب مرتبطاً بطاولة، قم بتحريرها
        if (tableNumber != null) {
          await supabase.from('tables').update({
            'status': 'available',
            'payment_status': null,
            'order_status': null,
            'occupied_at': null
          }).eq('number', tableNumber).eq('restaurant_id', await _getRestaurantId());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إغلاق الطلب وتحرير الطاولة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CashierScreen(profile: profile),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إغلاق الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات الكاشير'),
        backgroundColor: const Color(0xFFFF6B00),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => CashierScreen(profile: profile),
                ),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: OrdersScreen(
        userRole: 'cashier',
        onDeleteOrder: (orderId) => _deleteOrder(context, orderId),
        onCompleteOrder: (orderId, tableNumber) => _completeOrder(context, orderId, tableNumber),
        onCloseOrder: (orderId, tableNumber, paymentStatus) => _closeOrder(context, orderId, tableNumber, paymentStatus),
        showAllOrders: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B00),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UnpaidOrdersScreen()),
          );
        },
        child: const Icon(Icons.money_off),
        tooltip: 'الطلبات غير المدفوعة',
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B00),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    profile['name'] ?? 'مستخدم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    profile['email'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.money_off, color: Colors.white),
              title: const Text('الطلبات غير المدفوعة', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UnpaidOrdersScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.white),
              title: const Text('إدارة المستخدمين', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UsersScreen(profile: profile),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
              onTap: () async {
                try {
                  await supabase.auth.signOut();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في تسجيل الخروج: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}