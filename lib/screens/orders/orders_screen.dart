import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../unpaid_orders_screen.dart';

class OrdersScreen extends StatefulWidget {
  final Function(int)? onDeleteOrder;
  final Function(int, String?)? onCompleteOrder; // أضف هذا
  final Function(int, String?, String)? onCloseOrder; // أضف هذا
  final String userRole;
  final bool showAllOrders;

  const OrdersScreen({
    super.key,
    required this.userRole,
    this.showAllOrders = false,
    this.onDeleteOrder,
    this.onCompleteOrder, // أضف هذا
    this.onCloseOrder, // أضف هذا
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _restaurantId;

  Future<String> _getRestaurantId() async {
    if (_restaurantId != null) return _restaurantId!;    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('لم يتم تسجيل الدخول');
    }
    final row = await Supabase.instance.client
        .from('profiles')
        .select('restaurant_id')
        .eq('id', uid)
        .single();
    _restaurantId = (row['restaurant_id'] as String?);
    if (_restaurantId == null) {
      throw Exception('لم يتم العثور على مطعم للمستخدم');
    }
    return _restaurantId!;
  }
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool isLoading = true;
  String selectedOrderType = 'مطعم';
  final List<String> orderTypes = ['الكل', 'توصيل', 'استلام', 'مطعم'];
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final rid = await _getRestaurantId();
      final response = await supabase
          .from('orders')
          .select('*')
          .eq('restaurant_id', rid)
          .order('created_at', ascending: false);

      setState(() {
        _allOrders = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في جلب الطلبات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_allOrders);

    if (selectedOrderType == 'توصيل') {
      result = result.where((order) => order['order_type'] == 'delivery').toList();
    } else if (selectedOrderType == 'استلام') {
      result = result.where((order) => order['order_type'] == 'takeaway').toList();
    } else if (selectedOrderType == 'مطعم') {
      result = result.where((order) => order['order_type'] == 'dine_in').toList();
    }

    if (_selectedDate != null) {
      final selectedDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      result = result.where((order) {
        final orderDate = DateTime.parse(order['created_at']).toLocal();
        final orderDateOnly = DateTime(orderDate.year, orderDate.month, orderDate.day);
        return orderDateOnly == selectedDate;
      }).toList();
    }

    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      result = result.where((order) {
        final nameMatches = order['customer_name']?.toString().toLowerCase().contains(searchTerm) ?? false;
        final phoneMatches = order['customer_phone']?.toString().contains(searchTerm) ?? false;
        final tableMatches = order['table_number']?.toString().contains(searchTerm) ?? false;
        final orderIdMatches = order['id']?.toString().contains(searchTerm) ?? false;
        return nameMatches || phoneMatches || tableMatches || orderIdMatches;
      }).toList();
    }

    if (!widget.showAllOrders) {
      if (widget.userRole == 'kitchen') {
        result = result.where((order) => ['pending', 'preparing'].contains(order['status'])).toList();
      } else {
        result = result.where((order) => ['ready', 'completed'].contains(order['status'])).toList();
      }
    }

    setState(() {
      _filteredOrders = result;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _applyFilters();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
      _applyFilters();
    });
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final order = _filteredOrders.firstWhere((o) => o['id'].toString() == orderId);

      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      if (order['order_type'] == 'dine_in' && order['table_number'] != null) {
        String tableStatus = '';

        if (newStatus == 'preparing') {
          tableStatus = 'preparing';
        } else if (newStatus == 'ready') {
          tableStatus = 'ready';
        } else if (newStatus == 'completed') {
          tableStatus = 'completed';
        }

        if (tableStatus.isNotEmpty) {
          await supabase
              .from('tables')
              .update({'order_status': tableStatus})
              .eq('number', order['table_number']);
        }
      }

      await _fetchOrders();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الطلب: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateItemQuantity(Map<String, dynamic> order, Map<String, dynamic> item, int newQuantity) async {
    try {
      if (newQuantity < 1) {
        await _deleteOrderItem(order, item);
        return;
      }

      final updatedItems = List<Map<String, dynamic>>.from(order['items']);
      final itemIndex = updatedItems.indexWhere((i) =>
      i['name'] == item['name'] && i['price'] == item['price']);

      if (itemIndex != -1) {
        double priceDifference = (item['price'] * item['quantity']) - (item['price'] * newQuantity);
        double newPayCustom = (order['pay_custom'] ?? order['total']) + priceDifference;

        updatedItems[itemIndex]['quantity'] = newQuantity;

        double newTotal = updatedItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));

        await supabase.from('orders').update({
          'items': updatedItems,
          'total': newTotal,
          'pay_custom': newPayCustom,
        }).eq('id', order['id']);

        await _fetchOrders();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الكمية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تحديث الكمية: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteOrderItem(Map<String, dynamic> order, Map<String, dynamic> item) async {
    try {
      final updatedItems = List<Map<String, dynamic>>.from(order['items'])
          .where((i) => !(i['name'] == item['name'] && i['price'] == item['price']))
          .toList();

      double itemTotal = item['price'] * item['quantity'];
      double newTotal = updatedItems.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
      double newPayCustom = (order['pay_custom'] ?? order['total']) - itemTotal;

      await supabase.from('orders').update({
        'items': updatedItems,
        'total': newTotal,
        'pay_custom': newPayCustom,
      }).eq('id', order['id']);

      await _fetchOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف ${item['name']} بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حذف العنصر: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم، الهاتف، رقم الطاولة أو الطلب...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      onChanged: (value) => _applyFilters(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: selectedOrderType,
                      items: orderTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedOrderType = value!;
                          _applyFilters();
                        });
                      },
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      underline: Container(height: 1, color: Colors.grey),
                    ),
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: _clearDateFilter,
                    ),
                ],
              ),
              if (_selectedDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'تاريخ: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchOrders,
            child: _filteredOrders.isEmpty
                ? const Center(
              child: Text(
                'لا توجد طلبات حالية',
                style: TextStyle(color: Colors.white),
              ),
            )
                : ListView.builder(
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return _buildOrderCard(order, context);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, BuildContext context) {
    final createdAt = DateTime.parse(order['created_at']).toLocal();
    final formattedTime = DateFormat('hh:mm a').format(createdAt);
    final formattedDate = DateFormat('yyyy-MM-dd').format(createdAt);

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${order['id']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  '$formattedDate - $formattedTime',
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildOrderTypeChip(order),
                const SizedBox(width: 8),
                if (order['order_type'] == 'dine_in' && order['table_number'] != null)
                  Chip(
                    label: Text(
                      'طاولة ${order['table_number']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.blueGrey[800],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'العميل: ${order['customer_name'] ?? 'غير محدد'}',
              style: TextStyle(color: Colors.grey[300]),
            ),
            if (order['customer_phone'] != null)
              Text(
                'الهاتف: ${order['customer_phone']}',
                style: TextStyle(color: Colors.grey[300]),
              ),
            const SizedBox(height: 8),
            const Text(
              'الطلبات:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ...order['items'].map<Widget>((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (widget.userRole == 'cashier' && order['status'] == 'pending')
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      color: Colors.red,
                      onPressed: () => _updateItemQuantity(
                        order,
                        item,
                        item['quantity'] - 1,
                      ),
                    ),

                  Container(
                    width: 30,
                    alignment: Alignment.center,
                    child: Text(
                      '${item['quantity']}',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ),

                  if (widget.userRole == 'cashير' && order['status'] == 'pending')
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      color: Colors.green,
                      onPressed: () => _updateItemQuantity(
                        order,
                        item,
                        item['quantity'] + 1,
                      ),
                    ),

                  Expanded(
                    child: Text(
                      ' ${item['name']}',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                  ),

                  Text(
                    '${item['price'] * item['quantity']} د.ع',
                    style: TextStyle(color: Colors.grey[300]),
                  ),

                  if (widget.userRole == 'cashier' && order['status'] == 'pending')
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                      onPressed: () => _showDeleteItemDialog(context, order, item),
                    ),
                ],
              ),
            )),
            const Divider(color: Colors.grey),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المجموع: ${order['total']} د.ع',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(order['status'])),
                  ),
                  child: Text(
                    _getStatusText(order['status']),
                    style: TextStyle(color: _getStatusColor(order['status'])),
                  ),
                ),
              ],
            ),
            // أزرار حسب نوع المستخدم
            if (widget.userRole == 'kitchen') _buildKitchenButtons(order),
            if (widget.userRole == 'cashier') _buildCashierButtons(order, context),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenButtons(Map<String, dynamic> order) {
    return Column(
      children: [
        if (order['status'] == 'pending')
          ElevatedButton(
            onPressed: () => _updateOrderStatus(order['id'].toString(), 'preparing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('بدء التحضير'),
          ),
        if (order['status'] == 'preparing')
          ElevatedButton(
            onPressed: () => _updateOrderStatus(order['id'].toString(), 'ready'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('تم الانتهاء'),
          ),
      ],
    );
  }

  Widget _buildCashierButtons(Map<String, dynamic> order, BuildContext context) {
    return Column(
      children: [
        if (order['status'] == 'ready' && widget.onCompleteOrder != null)
          ElevatedButton(
            onPressed: () => widget.onCompleteOrder!(order['id'], order['table_number']?.toString()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('استلام الزبون'),
          ),
        if (order['status'] == 'completed' && widget.onCloseOrder != null)
          ElevatedButton(
            onPressed: () => widget.onCloseOrder!(order['id'], order['table_number']?.toString(), order['payment_status']?.toString() ?? ''),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('غلق الطلب'),
          ),
        if (order['status'] == 'pending')
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _updateOrderStatus(
                    order['id'].toString(), 'preparing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('بدء التحضير'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('حذف الطلب'),
                      content: const Text('هل أنت متأكد من حذف هذا الطلب؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await widget.onDeleteOrder?.call(order['id']);
                          },
                          child: const Text('حذف',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('حذف الطلب'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOrderTypeChip(Map<String, dynamic> order) {
    IconData icon;
    Color color;
    String label;

    switch (order['order_type']) {
      case 'delivery':
        icon = Icons.delivery_dining;
        color = Colors.blue;
        label = 'توصيل';
        break;
      case 'takeaway':
        icon = Icons.takeout_dining;
        color = Colors.orange;
        label = 'استلام';
        break;
      case 'dine_in':
        icon = Icons.restaurant;
        color = Colors.green;
        label = 'مطعم';
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
        label = 'غير معروف';
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _showDeleteItemDialog(BuildContext context, Map<String, dynamic> order, Map<String, dynamic> item) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('حذف العنصر'),
          content: Text('هل أنت متأكد من حذف ${item['name']} من الطلب؟'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteOrderItem(order, item);
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'جاهز للتسليم';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }
}