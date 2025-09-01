import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class UnpaidOrdersScreen extends StatefulWidget {
  final String? initialTableNumber;
  final String? initialOrderId;

  const UnpaidOrdersScreen({super.key, this.initialTableNumber, this.initialOrderId});

  @override
  State<UnpaidOrdersScreen> createState() => _UnpaidOrdersScreenState();
}

class _UnpaidOrdersScreenState extends State<UnpaidOrdersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  String? _restaurantId;

  Future<String> _getRestaurantId() async {
    if (_restaurantId != null) return _restaurantId!;
    final uid = Supabase.instance.client.auth.currentUser?.id;
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
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  String _selectedPaymentFilter = 'غير مدفوع';
  String _selectedOrderTypeFilter = 'الكل';
  String _selectedSearchOrderType = 'الكل';
  final TextEditingController _paymentAmountController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  // الألوان المخصصة
  final Color primaryColor = const Color(0xFF120E0E);
  final Color secondaryColor = Colors.deepOrange;
  final Color backgroundColor = Colors.grey[100]!;
  final Color cardColor = Colors.white;
  final Color textColor = Colors.black87;
  final Color tableChipColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    if (widget.initialTableNumber != null) {
      _searchController.text = widget.initialTableNumber!;
    }
    // دعم فتح طلب معين حسب ID إذا تم تمريره
    if (widget.initialOrderId != null) {
      _searchController.text = widget.initialOrderId!;
    }
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      setState(() => isLoading = true);
      final rid = await _getRestaurantId();
      var query = supabase.from('orders').select('*').eq('restaurant_id', rid);

      if (_selectedPaymentFilter != 'الكل') {
        query = query.eq('payment_status', _selectedPaymentFilter);
      }

      if (_selectedOrderTypeFilter != 'الكل') {
        query = query.eq('order_type', _getOrderTypeKey(_selectedOrderTypeFilter));
      }

      if (_fromDate != null) {
        query = query.gte('created_at', _fromDate!.toIso8601String());
      }

      if (_toDate != null) {
        query = query.lte('created_at',
            DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)
                .toIso8601String());
      }

      if (_searchController.text.isNotEmpty) {
        final orderId = int.tryParse(_searchController.text);
        if (orderId != null) {
          query = query.eq('id', orderId);
        } else {
          query = query.ilike('table_number', '%${_searchController.text}%');
        }
      }

      if (_selectedSearchOrderType != 'الكل') {
        query = query.eq('order_type', _getOrderTypeKey(_selectedSearchOrderType));
      }

      final data = await query.order('created_at', ascending: false);
      setState(() {
        orders = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في جلب الطلبات: ${e.toString()}'),
          backgroundColor: primaryColor,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? _fromDate ?? (_toDate ?? DateTime.now())
          : _toDate ?? (_fromDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate != null && _fromDate!.isAfter(_toDate!)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
          if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
            _fromDate = _toDate;
          }
        }
      });
      _fetchOrders();
    }
  }

  Future<void> _payOrder(String orderId, double paidAmount, double remainingAmount) async {
    try {
      // التحقق من المبلغ المدخل
      if (paidAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء إدخال مبلغ صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // إذا كان المبلغ المدفوع لا يساوي المبلغ المتبقي
      if (paidAmount != remainingAmount) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تنبيه'),
            content: Text(
              'المبلغ المدفوع (${paidAmount.toStringAsFixed(2)}) لا يساوي المبلغ المطلوب (${remainingAmount.toStringAsFixed(2)})\n'
                  'الرجاء إدخال المبلغ بالضبط: ${remainingAmount.toStringAsFixed(2)} ر.س',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
        return;
      }

      // إذا كان المبلغ مساوياً للمبلغ المتبقي
      await _completePayment(orderId, paidAmount);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التسديد: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completePayment(String orderId, double paidAmount) async {
    try {
      final response = await supabase
          .from('orders')
          .select('*')
          .eq('id', orderId)
          .single();

      final order = response as Map<String, dynamic>;

      await supabase.from('orders').update({
        'payment_status': 'مدفوع',
        'pay_custom': paidAmount,
        'total_pay': 0.0,
      }).eq('id', orderId);

      if (order['order_type'] == 'dine_in' && order['table_number'] != null) {
        await supabase
            .from('tables')
            .update({
          'status': 'available',
          'payment_status': null,
          'order_status': null,
          'occupied_at': null,
        })
            .eq('number', order['table_number']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسديد المبلغ بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // بعد الدفع، نعود إلى شاشة الكاشير
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التسديد: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getOrderTypeKey(String displayName) {
    switch (displayName) {
      case 'توصيل':
        return 'delivery';
      case 'استلام':
        return 'takeaway';
      case 'تناول بالمطعم':
        return 'dine_in';
      default:
        return '';
    }
  }

  String _getOrderTypeDisplayName(String type) {
    switch (type) {
      case 'delivery':
        return 'توصيل';
      case 'takeaway':
        return 'استلام';
      case 'dine_in':
        return 'تناول بالمطعم';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('الطلبات غير المسددة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: secondaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // قسم البحث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'ابحث برقم الطلب أو رقم الطاولة',
                    labelStyle: TextStyle(color: textColor),
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: primaryColor),
                      onPressed: () {
                        _searchController.clear();
                        _fetchOrders();
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                  onChanged: (value) => _fetchOrders(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedSearchOrderType,
                  items: const [
                    DropdownMenuItem(
                        value: 'الكل', child: Text('كل أنواع الطلبات')),
                    DropdownMenuItem(
                        value: 'توصيل', child: Text('طلبات التوصيل فقط')),
                    DropdownMenuItem(
                        value: 'استلام', child: Text('طلبات الاستلام فقط')),
                    DropdownMenuItem(value: 'تناول بالمطعم',
                        child: Text('طلبات المطعم فقط')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedSearchOrderType = value!);
                    _fetchOrders();
                  },
                  decoration: InputDecoration(
                    labelText: 'بحث حسب نوع الطلب',
                    labelStyle: TextStyle(color: textColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),

          // فلتر التاريخ
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                        Icons.calendar_today, size: 16, color: primaryColor),
                    label: Text(
                      _fromDate == null ? 'من تاريخ' : DateFormat('yyyy/MM/dd')
                          .format(_fromDate!),
                      style: TextStyle(color: textColor),
                    ),
                    onPressed: () => _selectDate(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    icon: Icon(
                        Icons.calendar_today, size: 16, color: primaryColor),
                    label: Text(
                      _toDate == null ? 'إلى تاريخ' : DateFormat('yyyy/MM/dd')
                          .format(_toDate!),
                      style: TextStyle(color: textColor),
                    ),
                    onPressed: () => _selectDate(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: primaryColor),
                      ),
                    ),
                  ),
                ),
                if (_fromDate != null || _toDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: primaryColor),
                    onPressed: () {
                      setState(() {
                        _fromDate = null;
                        _toDate = null;
                      });
                      _fetchOrders();
                    },
                  ),
              ],
            ),
          ),

          // فلاتر حالة السداد ونوع الطلب
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentFilter,
                    items: const [
                      DropdownMenuItem(
                          value: 'غير مدفوع', child: Text('غير مسدد')),
                      DropdownMenuItem(value: 'مدفوع', child: Text('مسدد')),
                      DropdownMenuItem(value: 'الكل', child: Text('جميع الحالات')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedPaymentFilter = value!);
                      _fetchOrders();
                    },
                    decoration: InputDecoration(
                      labelText: 'حالة السداد',
                      labelStyle: TextStyle(color: textColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedOrderTypeFilter,
                    items: const [
                      DropdownMenuItem(value: 'الكل', child: Text('الكل')),
                      DropdownMenuItem(value: 'توصيل', child: Text('توصيل')),
                      DropdownMenuItem(value: 'استلام', child: Text('استلام')),
                      DropdownMenuItem(
                          value: 'تناول بالمطعم', child: Text('تناول بالمطعم')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedOrderTypeFilter = value!);
                      _fetchOrders();
                    },
                    decoration: InputDecoration(
                      labelText: 'نوع الطلب',
                      labelStyle: TextStyle(color: textColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor),
                  ),
                ),
              ],
            ),
          ),

          // قائمة الطلبات
          Expanded(
            child: isLoading
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
                : orders.isEmpty
                ? Center(
              child: Text(
                'لا توجد طلبات',
                style: TextStyle(color: textColor, fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final total = order['total']?.toDouble() ?? 0.0;
                final remainingAmount = total - (order['pay_custom']?.toDouble() ?? 0.0);

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${order['id']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('yyyy/MM/dd - HH:mm')
                                  .format(DateTime.parse(
                                  order['created_at'])
                                  .toLocal()),
                              style: TextStyle(color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (order['order_type'] == 'dine_in' &&
                                order['table_number'] != null)
                              Chip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getOrderTypeDisplayName(
                                          order['order_type']),
                                      style: TextStyle(
                                          color: Colors.white),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.table_restaurant,
                                        size: 16,
                                        color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${order['table_number']}',
                                      style: TextStyle(
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                                backgroundColor: tableChipColor,
                              )
                            else
                              Chip(
                                label: Text(
                                  _getOrderTypeDisplayName(
                                      order['order_type'] ?? ''),
                                  style: TextStyle(
                                      color: Colors.white),
                                ),
                                backgroundColor: primaryColor,
                              ),
                            const Spacer(),
                            Text(
                              '${total.toStringAsFixed(2)} د.ع',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: secondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (order['payment_status'] != 'مدفوع') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _paymentAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'المبلغ المدفوع',
                              labelStyle:
                              TextStyle(color: textColor),
                              hintText:
                              '${remainingAmount.toStringAsFixed(2)} د.ع مطلوبة',
                              hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.6)),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(8),
                                borderSide:
                                BorderSide(color: primaryColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: primaryColor, width: 2),
                              ),
                            ),
                            style: TextStyle(color: textColor),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                final amount = double.tryParse(
                                    _paymentAmountController.text) ??
                                    0;
                                if (amount > 0) {
                                  _payOrder(
                                    order['id'].toString(),
                                    amount,
                                    remainingAmount,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'الرجاء إدخال مبلغ صحيح'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                              ),
                              child: const Text(
                                'تسديد',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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