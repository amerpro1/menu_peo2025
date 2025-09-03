import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'menu_item_card.dart';
import 'cart_content.dart';
import '../orders/orders_screen.dart';
import '../reports/reports_screen.dart';
import '../menu_management/menu_items_screen.dart';
import '../payment/payment_screen.dart';
import 'tables_screen.dart';
import '../unpaid_orders_screen.dart';
import 'Users_Screen.dart';
import 'kitchen_screen.dart';
import 'cashier_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  final String? initialTableId;
  final String? initialTableNumber;

  const HomeScreen({
    super.key,
    required this.profile,
    this.initialTableId,
    this.initialTableNumber,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cartItems = [];
  int? _selectedCategoryId;
  bool _isLoading = true;
  String? _orderType;
  String? _selectedTableId;
  String? _selectedTableNumber;

  final Color primaryColor = const Color(0xFFFF6B00);
  final Color secondaryColor = Colors.black;
  final Color backgroundColor = Colors.white;
  final Color textColor = Colors.black;
  final Color lightTextColor = Colors.white;

  @override
  @override
  void initState() {
    super.initState();
    // ✅ لو دخل كزبون (customer) أو عن طريق QR
    if (widget.initialTableId != null) {
      _selectedTableId = widget.initialTableId;
      _selectedTableNumber = widget.initialTableNumber;
      _orderType = 'dine_in';
    }

    if (widget.profile['restaurant_id'] == null) {
      // في حال ماكو مطعم محدد
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ لم يتم تحديد مطعم")),
      );
    } else {
      _fetchData();
    }
  }



  Future<void> switchRestaurant(String newRestaurantId) async {
    final supabase = Supabase.instance.client;

    // حدّث بروفايل المستخدم ليطابق المطعم الجديد
    await supabase
        .from('profiles')
        .update({'restaurant_id': newRestaurantId})
        .eq('id', widget.profile['id']);

    // اجلب البروفايل المحدّث
    final updated = await supabase
        .from('profiles')
        .select()
        .eq('id', widget.profile['id'])
        .single();

    setState(() {
      widget.profile['restaurant_id'] = updated['restaurant_id'];
      widget.profile['role']         = updated['role']; // عند الحاجة
    });

    // افتح شاشة الطاولات للمطعم الجديد
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TablesScreen(
          restaurantId: widget.profile['restaurant_id'],
          profile: widget.profile,
        ),
      ),
    );
  }


  Future<void> _fetchData() async {
    if (widget.profile['restaurant_id'] == null) return;

    try {
      final categories = await supabase
          .from('categories')
          .select()
          .eq('restaurant_id', widget.profile['restaurant_id'])
          .order('name');

      final menuItems = await supabase
          .from('menu_items')
          .select()
          .eq('restaurant_id', widget.profile['restaurant_id'])
          .order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(categories);
        _menuItems = List<Map<String, dynamic>>.from(menuItems);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب البيانات: ${e.toString()}')),
      );
    }
  }


  Widget _buildDrawer(bool isAdmin, bool isCashier) {
    return Drawer(
      child: Container(
        color: secondaryColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.profile['full_name'] ?? 'مستخدم',
                    style: TextStyle(
                      color: lightTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.profile['email'] ?? '',
                    style: TextStyle(
                      color: lightTextColor.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'مطعم: ${widget.profile['restaurant_id'] != null ? 'مفعل' : 'غير محدد'}',
                    style: TextStyle(
                      color: lightTextColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin)
              _buildDrawerItem(
                icon: Icons.people,
                title: 'المستخدمين',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UsersScreen(profile: widget.profile),
                    ),
                  );
                },
              ),
            if (isAdmin)
              _buildDrawerItem(
                icon: Icons.analytics,
                title: 'التقارير',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportsScreen()),
                  );
                },
              ),
            if (isAdmin)
              _buildDrawerItem(
                icon: Icons.restaurant_menu,
                title: 'إدارة القائمة',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MenuItemsManagementScreen(profile: widget.profile),
                    ),
                  );
                },
              ),
            if (isCashier)
              _buildDrawerItem(
                icon: Icons.money_off,
                title: 'الطلبات غير المدفوعة',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UnpaidOrdersScreen()),
                  );
                },
              ),
            const Divider(color: Colors.grey),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }

  ListTile _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: lightTextColor),
      title: Text(
        title,
        style: TextStyle(color: lightTextColor),
      ),
      onTap: onTap,
    );
  }

  Future<void> _selectOrderType() async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryColor,
        title: Text('اختر نوع الطلب', style: TextStyle(color: primaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOrderTypeOption(
              context,
              icon: Icons.delivery_dining,
              title: 'توصيل',
              value: 'delivery',
              textColor: lightTextColor,
            ),
            _buildOrderTypeOption(
              context,
              icon: Icons.takeout_dining,
              title: 'استلام من المطعم',
              value: 'takeaway',
              textColor: lightTextColor,
            ),
            _buildOrderTypeOption(
              context,
              icon: Icons.restaurant,
              title: 'تناول في المطعم',
              value: 'dine_in',
              textColor: lightTextColor,
            ),
          ],
        ),
      ),
    );

    if (type == null) return;

    if (type == 'dine_in') {
      // ✅ نفتح شاشة الطاولات مع تمرير restaurantId و profile فقط
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TablesScreen(
            restaurantId: widget.profile['restaurant_id'],
            profile: widget.profile,
          ),
        ),
      );
    } else {
      setState(() {
        _orderType = type;
        _selectedTableId = null;
        _selectedTableNumber = null;
      });
    }
  }

  ListTile _buildOrderTypeOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required Color textColor,
      }) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: () => Navigator.pop(context, value),
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    if (_orderType == null || (_orderType == 'dine_in' && _selectedTableId == null)) {
      _selectOrderType().then((_) {
        if (_orderType != null && (_orderType != 'dine_in' || _selectedTableId != null)) {
          _addItemToCart(item);
        }
      });
    } else {
      _addItemToCart(item);
    }
  }

  void _addItemToCart(Map<String, dynamic> item) {
    setState(() {
      final index = _cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1) {
        _cartItems[index]['quantity'] += 1;
      } else {
        _cartItems.add({...item, 'quantity': 1});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إضافة ${item['name']} إلى السلة'),
        backgroundColor: primaryColor,
      ),
    );
  }

  void _removeFromCart(int index, String action) {
    setState(() {
      final item = _cartItems[index];
      if (action == 'increase') {
        item['quantity']++;
      } else if (action == 'decrease') {
        if (item['quantity'] > 1) {
          item['quantity']--;
        } else {
          _cartItems.removeAt(index);
        }
      }
    });
  }

  void _navigateToTablesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TablesScreen(
          restaurantId: widget.profile['restaurant_id'],
          profile: widget.profile,
        ),
      ),
    );
  }

  double _calculateTotal() {
    double subtotal = _cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
    return _orderType == 'delivery' ? subtotal + 5.0 : subtotal;
  }

  Future<void> _submitOrder(Map<String, dynamic> paymentData) async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .insert({
        'total': _calculateTotal(),
        'items': _cartItems,
        'customer_name': _nameController.text,
        'customer_phone': _phoneController.text,
        'notes': _notesController.text,
        'payment_method': paymentData['paymentMethod'],
        'payment_status': paymentData['paymentStatus'],
        'pay_custom': paymentData['pay_custom'],
        'total_pay': paymentData['total_pay'],
        'order_type': paymentData['order_type'],
        'table_number': paymentData['table_number'],
        'restaurant_id': widget.profile['restaurant_id'],
        'user_id': widget.profile['id'] == 'guest' ? null : widget.profile['id'],
        'status': 'pending',
      })
          .select()
          .single();

      if (_orderType == 'dine_in' && _selectedTableId != null) {
        final paymentStatus = paymentData['paymentStatus'] == 'مدفوع' ? 'paid' : 'unpaid';

        await supabase
            .from('tables')
            .update({
          'status': 'occupied',
          'payment_status': paymentStatus,
          'order_status': 'pending',
          'occupied_at': DateTime.now().toIso8601String(),
        })
            .eq('id', _selectedTableId!)
            .eq('restaurant_id', widget.profile['restaurant_id']);
      }

      setState(() {
        _cartItems.clear();
        _nameController.clear();
        _phoneController.clear();
        _notesController.clear();
        _orderType = null;
        _selectedTableId = null;
        _selectedTableNumber = null;
      });

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تقديم الطلب بنجاح'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تقديم الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPaymentScreen() {
    if (_orderType == null) {
      _selectOrderType();
      return;
    }

    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('الرجاء إدخال الاسم ورقم الهاتف'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          total: _calculateTotal(),
          customerName: _nameController.text,
          customerPhone: _phoneController.text,
          notes: _notesController.text,
          cartItems: _cartItems,
          onSubmit: _submitOrder,
          orderType: _orderType!,
          tableNumber: _selectedTableNumber,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            restaurant: widget.profile['restaurant'], // أو المتغير اللي عندك يحمل بيانات المطعم
          ),
        ),      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تسجيل الخروج: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.profile['role'] == 'admin';
    final isCashier = widget.profile['role'] == 'cashier' || isAdmin;
    final isKitchen = widget.profile['role'] == 'kitchen' || isAdmin;

    return Scaffold(
      drawer: _buildDrawer(isAdmin, isCashier),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Row(
          children: [
            Text('قائمة الطعام', style: TextStyle(color: lightTextColor)),
            const Spacer(),
            TextButton.icon(
              icon: Icon(Icons.edit, size: 20, color: lightTextColor),
              label: Text(
                _orderType == 'delivery'
                    ? 'توصيل'
                    : _orderType == 'takeaway'
                    ? 'استلام'
                    : _selectedTableNumber != null
                    ? 'طاولة $_selectedTableNumber'
                    : 'اختر نوع الطلب',
                style: TextStyle(fontSize: 16, color: lightTextColor),
              ),
              onPressed: _selectOrderType,
            ),
          ],
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: lightTextColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.table_restaurant, color: lightTextColor),
            onPressed: _navigateToTablesScreen,
            tooltip: 'عرض الطاولات',
          ),
          if (isKitchen)
            IconButton(
              icon: Icon(Icons.restaurant, color: lightTextColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => KitchenScreen(profile: widget.profile),
                ),
              ),
              tooltip: 'طلبات المطبخ',
            ),
          if (isCashier)
            IconButton(
              icon: Icon(Icons.point_of_sale, color: lightTextColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CashierScreen(profile: widget.profile),
                ),
              ),
              tooltip: 'طلبات الكاشير',
            ),
          IconButton(
            icon: Badge(
              backgroundColor: secondaryColor,
              label: Text(
                '${_cartItems.length}',
                style: TextStyle(color: lightTextColor),
              ),
              isLabelVisible: _cartItems.isNotEmpty,
              child: Icon(Icons.shopping_cart, color: lightTextColor),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (BuildContext context, StateSetter setModalState) {
                    return CartContent(
                      parentContext: context,
                      cartItems: _cartItems,
                      onRemove: (index, action) {
                        setState(() {
                          _removeFromCart(index, action);
                        });
                        setModalState(() {});
                      },
                      nameController: _nameController,
                      phoneController: _phoneController,
                      notesController: _notesController,
                      onProceedToPayment: _openPaymentScreen,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
        children: [
          Container(
            height: 70,
            color: secondaryColor,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ChoiceChip(
                    label: Text(
                      category['name'],
                      style: TextStyle(
                        color: _selectedCategoryId == category['id']
                            ? lightTextColor
                            : textColor,
                      ),
                    ),
                    selected: _selectedCategoryId == category['id'],
                    selectedColor: primaryColor,
                    backgroundColor: backgroundColor,
                    onSelected: (selected) => setState(() {
                      _selectedCategoryId = selected ? category['id'] : null;
                    }),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 2, color: Colors.grey),
          Expanded(
            child: MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              padding: const EdgeInsets.all(8),
              itemCount: _menuItems
                  .where((item) => _selectedCategoryId == null ||
                  item['category_id'] == _selectedCategoryId)
                  .length,
              itemBuilder: (context, index) {
                final filteredItems = _menuItems
                    .where((item) => _selectedCategoryId == null ||
                    item['category_id'] == _selectedCategoryId)
                    .toList();
                final item = filteredItems[index];
                return MenuItemCard(
                  item: item,
                  onAdd: () => _addToCart(item),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.profile['role'] == 'cashier' || widget.profile['role'] == 'admin')
          ? FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          setState(() {
            _cartItems.clear();
            _orderType = null;
            _selectedTableId = null;
            _selectedTableNumber = null;
          });
          _selectOrderType();
        },
        child: Icon(Icons.refresh, color: lightTextColor),
        tooltip: 'طلب جديد',
      )
          : null,
    );
  }
}
