import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:menu_peo2025/screens/menu_edit.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ulfasrzrtbfmtjyohzrp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVsZmFzcnpydGJmbXRqeW9oenJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1MTQyNzksImV4cCI6MjA2MzA5MDI3OX0.Et1bJV2KqGlVsuwYekUqWSOCay9Hr5DLfhVhTL4Nu1o',
  );
  await _initStorage(); // تهيئة التخزين
  runApp(const MyApp());
}
Future<void> _initStorage() async {
  final supabase = Supabase.instance.client;
  try {
    // إنشاء bucket إذا لم يكن موجوداً
    final response = await supabase.storage.listBuckets();
    if (!response.contains('menu_images')) {
      await supabase.storage.createBucket('menu_images');
    }
  } catch (e) {
    debugPrint('Storage init error: $e');
  }
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
      home: const AuthWrapper(),
    );
  }
}

// ========== غلاف المصادقة ==========
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseClient supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _getAuthState();
  }

  Future<void> _getAuthState() async {
    supabase.auth.onAuthStateChange.listen((event) async {
      if (event.session?.user != null) {
        final user = event.session!.user;
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single()
            .catchError((_) => null);

        setState(() {
          _user = user;
          _profile = profile;
        });
      } else {
        setState(() {
          _user = null;
          _profile = null;
        });
      }
    });

    // تحقق من حالة المصادقة الحالية
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null) {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', currentUser.id)
          .single()
          .catchError((_) => null);

      setState(() {
        _user = currentUser;
        _profile = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _user == null
        ? const LoginScreen()
        : HomeScreen(user: _user!, profile: _profile!);
  }
}

// ========== شاشة تسجيل الدخول ==========
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user == null) {
        setState(() => _error = 'فشل تسجيل الدخول');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'حدث خطأ غير متوقع');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                obscureText: true,
                validator: (value) =>
                value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== الشاشة الرئيسية مع التحكم في الصلاحيات ==========
class HomeScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;

  const HomeScreen({

    super.key,
    required this.user,
    required this.profile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> cartItems = [];
  int? selectedCategoryId;
  bool isLoading = true;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final categoriesData = await supabase.from('categories').select().order('name');
      final menuItemsData = await supabase.from('menu_items').select().order('name');

      setState(() {
        categories = List<Map<String, dynamic>>.from(categoriesData);
        menuItems = List<Map<String, dynamic>>.from(menuItemsData);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب البيانات: ${e.toString()}')),
      );
    }
  }

  void addToCart(Map<String, dynamic> item, {int quantity = 1}) {
    setState(() {
      final index = cartItems.indexWhere((cartItem) => cartItem['id'] == item['id']);
      if (index != -1) {
        cartItems[index]['quantity'] += quantity;
      } else {
        cartItems.add({...item, 'quantity': quantity});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إضافة ${item['name']} إلى السلة')),
    );
  }

  void removeFromCart(int index) {
    setState(() {
      if (cartItems[index]['quantity'] > 1) {
        cartItems[index]['quantity']--;
      } else {
        cartItems.removeAt(index);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الكمية')),
    );
  }

  void _navigateToOrders(String userRole) {
    if (widget.profile['role'] != 'admin' && widget.profile['role'] != userRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية الوصول')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => OrdersScreen(userRole: userRole),
    ));
  }

  void _navigateToReports() {
    if (widget.profile['role'] != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الوصول مقصور على المسؤولين فقط')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ReportsScreen(),
    ));
  }

  void _openPaymentScreen() {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم ورقم الهاتف')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => PaymentScreen(
        total: cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity'])),
        customerName: nameController.text,
        customerPhone: phoneController.text,
        notes: notesController.text,
        cartItems: cartItems,
        onSubmit: submitOrder,
      ),
    ));
  }

  Future<void> submitOrder(Map<String, dynamic> paymentData) async {
    try {
      await supabase.from('orders').insert([{
        'total': cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity'])),
        'items': cartItems,
        'customer_name': nameController.text,
        'customer_phone': phoneController.text,
        'notes': notesController.text,
        'status': 'pending',
        'payment_method': paymentData['paymentMethod'],
        'payment_status': paymentData['paymentStatus'],
        'created_at': DateTime.now().toIso8601String(),
        'user_id': widget.user.id,
      }]);

      setState(() {
        cartItems.clear();
        nameController.clear();
        phoneController.clear();
        notesController.clear();
      });
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تقديم الطلب بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تقديم الطلب: ${e.toString()}')),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تسجيل الخروج: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.profile['role'] == 'admin';
    final isCashier = widget.profile['role'] == 'cashier' || isAdmin;
    final isKitchen = widget.profile['role'] == 'kitchen' || isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة الطعام'),
        actions: [
          if (isKitchen)
            IconButton(
              icon: const Icon(Icons.restaurant),
              onPressed: () => _navigateToOrders('kitchen'),
              tooltip: 'طلبات المطبخ',
            ),
          // أيقونة طلبات الكاشير (موجودة أصلاً)
          if (isCashier)
            IconButton(
              icon: const Icon(Icons.point_of_sale),
              onPressed: () => _navigateToOrders('cashier'),
              tooltip: 'طلبات الكاشير',
            ),
          // أيقونة التقارير (موجودة أصلاً)
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _navigateToReports,
              tooltip: 'التقارير والإيرادات',
            ),

          // الزر الجديد لإدارة المواد - أضف هذا الكود
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.restaurant_menu),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MenuItemsManagementScreen()),
              ),
              tooltip: 'إدارة المواد',
            ),
          //أيقونة السلة
          IconButton(
            icon: Badge(
              label: Text(cartItems.isEmpty ? '0' : '${cartItems.length}'),
              child: const Icon(Icons.shopping_cart),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => CartContent(
                  cartItems: cartItems,
                  onRemove: removeFromCart,
                  nameController: nameController,
                  phoneController: phoneController,
                  notesController: notesController,
                  onProceedToPayment: _openPaymentScreen,
                ),
              );
            },
          ),
          // أيقونة تسجيل الخروج (موجودة أصلاً)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFA404), Color(0xFFFFA200), Color(0xFFFFA404)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FilterChip(
                        label: Text(category['name']),
                        selected: selectedCategoryId == category['category_id'],
                        onSelected: (selected) => setState(() {
                          selectedCategoryId = selected ? category['category_id'] : null;
                        }),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                itemCount: menuItems.where((item) =>
                selectedCategoryId == null || item['category_id'] == selectedCategoryId).length,
                itemBuilder: (context, index) {
                  final filteredItems = menuItems.where((item) =>
                  selectedCategoryId == null || item['category_id'] == selectedCategoryId).toList();
                  final item = filteredItems[index];
                  return MenuItemCard(
                    item: item,
                    onAdd: () => addToCart(item),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== شاشة الدفع ==========
class PaymentScreen extends StatefulWidget {
  final double total;
  final String customerName;
  final String customerPhone;
  final String notes;
  final List<Map<String, dynamic>> cartItems;
  final Function(Map<String, dynamic>) onSubmit;

  const PaymentScreen({
    super.key,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.notes,
    required this.cartItems,
    required this.onSubmit,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'نقدي';
  String _paymentStatus = 'مدفوع';
  bool _isLoading = false;

  final List<String> _paymentMethods = ['نقدي', 'بطاقة ائتمان', 'محفظة إلكترونية'];
  final List<String> _paymentStatuses = ['مدفوع', 'جزئي', 'غير مدفوع'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الدفع')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('ملخص الطلب', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...widget.cartItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('${item['quantity']} × ${item['name']}'),
                  const Spacer(),
                  Text('${item['price'] * item['quantity']} ر.س'),
                ],
              ),
            )),
            const Divider(),
            Row(
              children: [
                const Text('المجموع:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${widget.total.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('معلومات الدفع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: _paymentMethods.map((method) => DropdownMenuItem(
                value: method,
                child: Text(method),
              )).toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              items: _paymentStatuses.map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              )).toList(),
              onChanged: (value) => setState(() => _paymentStatus = value!),
              decoration: const InputDecoration(
                labelText: 'حالة الدفع',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  await widget.onSubmit({
                    'paymentMethod': _paymentMethod,
                    'paymentStatus': _paymentStatus,
                  });
                  setState(() => _isLoading = false);
                },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد الدفع والطلب'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== شاشة التقارير ==========
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  DateTime? fromDate;
  DateTime? toDate;
  double totalRevenue = 0;
  double completedOrdersRevenue = 0;
  int totalOrders = 0;
  int completedOrdersCount = 0;
  double averageOrderValue = 0;
  final Map<String, double> revenueByPaymentMethod = {};
  final Map<String, double> revenueByOrderStatus = {};
  final Map<String, int> countByOrderStatus = {};

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      setState(() => isLoading = true);

      var query = supabase.from('orders').select('*');

      if (fromDate != null && toDate != null) {
        query = query
            .gte('created_at', fromDate!.toIso8601String())
            .lte('created_at', toDate!.add(const Duration(days: 1)).toIso8601String());
      }

      final data = await query.order('created_at', ascending: false);

      setState(() {
        orders = List<Map<String, dynamic>>.from(data);
        _calculateStatistics();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب التقارير: ${e.toString()}')),
      );
    }
  }

  void _calculateStatistics() {
    totalRevenue = 0;
    completedOrdersRevenue = 0;
    totalOrders = orders.length;
    completedOrdersCount = 0;
    revenueByPaymentMethod.clear();
    revenueByOrderStatus.clear();
    countByOrderStatus.clear();

    for (var order in orders) {
      final orderTotal = (order['total'] as num).toDouble();
      final orderStatus = order['status'] ?? 'غير محدد';
      final paymentMethod = order['payment_method'] ?? 'غير محدد';

      totalRevenue += orderTotal;

      if (orderStatus == 'completed') {
        completedOrdersRevenue += orderTotal;
        completedOrdersCount++;
      }

      revenueByPaymentMethod.update(
        paymentMethod,
            (value) => value + orderTotal,
        ifAbsent: () => orderTotal,
      );

      revenueByOrderStatus.update(
        orderStatus,
            (value) => value + orderTotal,
        ifAbsent: () => orderTotal,
      );

      countByOrderStatus.update(
        orderStatus,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? fromDate ?? DateTime.now() : toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
      _fetchReports();
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'preparing': return 'قيد التحضير';
      case 'ready': return 'جاهز للتسليم';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.green;
      case 'completed': return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإيرادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'من تاريخ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        fromDate != null
                            ? DateFormat('yyyy-MM-dd').format(fromDate!)
                            : 'اختر التاريخ',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'إلى تاريخ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        toDate != null
                            ? DateFormat('yyyy-MM-dd').format(toDate!)
                            : 'اختر التاريخ',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'ملخص الإيرادات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildSummaryRow('إجمالي الطلبات', '$totalOrders'),
                    _buildSummaryRow('الطلبات المكتملة', '$completedOrdersCount'),
                    _buildSummaryRow('إجمالي الإيرادات', '${totalRevenue.toStringAsFixed(2)} ر.س'),
                    _buildSummaryRow(
                      'إيرادات المكتملة',
                      '${completedOrdersRevenue.toStringAsFixed(2)} ر.س',
                      isHighlighted: true,
                    ),
                    _buildSummaryRow('متوسط الطلب', '${averageOrderValue.toStringAsFixed(2)} ر.س'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildStatisticsCard(
              title: 'الإيرادات حسب حالة الطلب',
              data: revenueByOrderStatus,
              isStatus: true,
            ),
            const SizedBox(height: 20),
            _buildStatisticsCard(
              title: 'الإيرادات حسب طريقة الدفع',
              data: revenueByPaymentMethod,
              isStatus: false,
            ),
            const SizedBox(height: 20),
            const Text(
              'تفاصيل الطلبات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 10),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? const Center(child: Text('لا توجد طلبات في الفترة المحددة'))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final createdAt = DateTime.parse(order['created_at']).toLocal();
                return _buildOrderItem(order, createdAt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> order, DateTime createdAt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      child: ListTile(
        title: Text('#${order['id']} - ${order['customer_name']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(DateFormat('yyyy-MM-dd HH:mm').format(createdAt)),
            Text('${order['total']} ر.س - ${order['payment_method']}'),
            const SizedBox(height: 5),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(order['status']).withValues(),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor(order['status'])),
          ),
          child: Text(
            _getStatusText(order['status']),
            style: TextStyle(
              color: _getStatusColor(order['status']),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? Colors.green : Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard({
    required String title,
    required Map<String, double> data,
    required bool isStatus,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 10),
            ...data.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(
                    isStatus ? _getStatusText(entry.key) : entry.key,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const Spacer(),
                  if (isStatus)
                    Text(
                      '${countByOrderStatus[entry.key] ?? 0} طلب',
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(width: 15),
                  Text(
                    '${entry.value.toStringAsFixed(2)} ر.س',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ========== شاشة عرض محتوى السلة ==========
class CartContent extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(int) onRemove;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final VoidCallback onProceedToPayment;

  const CartContent({
    super.key,
    required this.cartItems,
    required this.onRemove,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.onProceedToPayment,
  });

  @override
  Widget build(BuildContext context) {
    final total = cartItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (cartItems.isEmpty)
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('السلة فارغة'),
                  ],
                ),
              )
            else
              Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: item['image_url'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.blue,
                                child: const Icon(Icons.fastfood, size: 30, color: Colors.grey),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                              ),
                            ),
                          ),
                          title: Text(item['name']),
                          subtitle: Text('${item['price']} ر.س × ${item['quantity']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => onRemove(index),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالكامل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المجموع:', style: TextStyle(fontSize: 18)),
                      Text(
                        '${total.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: onProceedToPayment,
                      child: const Text('التوجه للدفع'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ========== بطاقة عنصر القائمة ==========
class MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAdd;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: item['image_url'],
              height: 120,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                height: 120,
                child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                height: 120,
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['price']} ر.س',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('أضف إلى السلة'),
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ========== شاشة عرض الطلبات للمطبخ والكاشير ==========
class OrdersScreen extends StatefulWidget {
  final String userRole;

  const OrdersScreen({super.key, required this.userRole});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final query = supabase.from('orders').select('*');

      if (widget.userRole == 'kitchen') {
        query.in_('status', ['pending', 'preparing']);
      } else {
        query.in_('status', ['ready', 'completed']);
      }

      query.order('created_at', ascending: false);

      final data = await query;

      setState(() {
        orders = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب الطلبات: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      await _fetchOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث الطلب: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == 'kitchen' ? 'طلبات المطبخ' : 'طلبات الكاشير'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchOrders,
        child: orders.isEmpty
            ? const Center(child: Text('لا توجد طلبات حالية'))
            : ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order, context);
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, BuildContext context) {
    final createdAt = DateTime.parse(order['created_at']).toLocal();
    final formattedTime = DateFormat('hh:mm a').format(createdAt);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${order['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(formattedTime),
              ],
            ),
            const SizedBox(height: 8),
            Text('العميل: ${order['customer_name']}'),
            Text('الهاتف: ${order['customer_phone']}'),
            const SizedBox(height: 8),
            const Text('الطلبات:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...order['items'].map<Widget>((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('${item['quantity']} × ${item['name']}'),
                  const Spacer(),
                  Text('${item['price'] * item['quantity']} ر.س'),
                ],
              ),
            )),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('المجموع: ${order['total']} ر.س',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withValues(),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order['status'])),
                  ),
                  child: Text(_getStatusText(order['status'])),
                ),
              ],
            ),
            if (widget.userRole == 'kitchen' && order['status'] == 'pending')
              ElevatedButton(
                onPressed: () => _updateOrderStatus(order['id'].toString(), 'preparing'),
                child: const Text('بدء التحضير'),
              ),
            if (widget.userRole == 'kitchen' && order['status'] == 'preparing')
              ElevatedButton(
                onPressed: () => _updateOrderStatus(order['id'].toString(), 'ready'),
                child: const Text('تم الانتهاء'),
              ),
            if (widget.userRole == 'cashier' && order['status'] == 'ready')
              ElevatedButton(
                onPressed: () => _updateOrderStatus(order['id'].toString(), 'completed'),
                child: const Text('تم التسليم'),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.green;
      case 'completed': return Colors.grey;
      default: return Colors.black;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'preparing': return 'قيد التحضير';
      case 'ready': return 'جاهز للتسليم';
      case 'completed': return 'مكتمل';
      default: return status;
    }
  }
}

extension on PostgrestFilterBuilder<PostgrestList> {
  void in_(String s, List<String> list) {}
}