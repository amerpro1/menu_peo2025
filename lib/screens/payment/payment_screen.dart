import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final double total;
  final String customerName;
  final String customerPhone;
  final String notes;
  final List<Map<String, dynamic>> cartItems;
  final Function(Map<String, dynamic>) onSubmit;
  final String orderType;
  final String? tableNumber;
  final String? tableId; // أضف هذا

  const PaymentScreen({
    super.key,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.notes,
    required this.cartItems,
    required this.onSubmit,
    required this.orderType,
    this.tableNumber,
    this.tableId, // أضف هذا
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {

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
  String _paymentMethod = 'نقدي';
  String _paymentStatus = 'مدفوع';
  bool _isLoading = false;
  final TextEditingController _paidAmountController = TextEditingController();
  double _remainingAmount = 0.0;
  double _finalTotal = 0.0;

  final List<String> _paymentMethods = ['نقدي', 'بطاقة ائتمان', 'محفظة إلكترونية'];
  final List<String> _paymentStatuses = ['مدفوع', 'غير مدفوع'];

  @override
  void initState() {
    super.initState();
    _finalTotal = widget.total;
    _remainingAmount = 0.0;
    _paidAmountController.text = _finalTotal.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  void _handlePaymentStatusChange(String? value) {
    setState(() {
      _paymentStatus = value!;
      if (_paymentStatus == 'مدفوع') {
        _paidAmountController.text = _finalTotal.toStringAsFixed(2);
        _remainingAmount = 0.0;
      } else {
        _paidAmountController.text = '0';
        _remainingAmount = _finalTotal;
      }
    });
  }

  Future<void> _updateTableStatus() async {
    try {
      if (widget.tableId != null && widget.orderType == 'dine_in') {
        final paymentStatus = _paymentStatus == 'مدفوع' ? 'paid' : 'unpaid';

        await Supabase.instance.client
            .from('tables')
            .update({
          'status': 'occupied',
          'payment_status': paymentStatus,
          'order_status': 'pending',
          'occupied_at': DateTime.now().toIso8601String(),
        })
            .eq('id', widget.tableId!);
      }
    } catch (e) {
      debugPrint('Error updating table status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الدفع'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطلب الأساسية
            ListTile(
              leading: Icon(
                widget.orderType == 'delivery'
                    ? Icons.delivery_dining
                    : widget.orderType == 'takeaway'
                    ? Icons.takeout_dining
                    : Icons.restaurant,
                color: Colors.teal,
              ),
              title: Text(
                widget.orderType == 'delivery'
                    ? 'توصيل'
                    : widget.orderType == 'takeaway'
                    ? 'استلام من المطعم'
                    : widget.tableNumber != null
                    ? 'طاولة ${widget.tableNumber}'
                    : 'تناول في المطعم',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const Divider(height: 20),

            // ملخص الطلب
            const Text(
              'ملخص الطلب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),

            ...widget.cartItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${item['quantity']} × ${item['name']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '${(item['price'] * item['quantity']).toStringAsFixed(2)} د.ع',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )),

            const Divider(height: 20),

            // تفاصيل المبلغ
            Row(
              children: [
                const Text(
                  'المجموع:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${widget.total.toStringAsFixed(2)} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'الإجمالي النهائي:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_finalTotal.toStringAsFixed(2)} د.ع',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'معلومات الدفع',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),

            // طريقة الدفع
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: _paymentMethods
                  .map((method) => DropdownMenuItem(
                value: method,
                child: Text(method),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
              decoration: InputDecoration(
                labelText: 'طريقة الدفع',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.payment),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),

            const SizedBox(height: 16),

            // حالة الدفع
            DropdownButtonFormField<String>(
              value: _paymentStatus,
              items: _paymentStatuses
                  .map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              ))
                  .toList(),
              onChanged: _handlePaymentStatusChange,
              decoration: InputDecoration(
                labelText: 'حالة الدفع',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),

            // المبلغ المدفوع والمتبقي (يظهر فقط عند حالة "مدفوع")
            if (_paymentStatus == 'مدفوع') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _paidAmountController,
                keyboardType: TextInputType.number,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع',
                  border: const OutlineInputBorder(),
                  suffixText: 'د.ع',
                  prefixIcon: const Icon(Icons.money),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'المبلغ المتبقي:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '0.00 د.ع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading
                    ? null
                    : () async {
                  setState(() => _isLoading = true);

                  // تحديث حالة الطاولة أولاً
                  await _updateTableStatus();

                  final paymentData = {
                    'paymentMethod': _paymentMethod,
                    'paymentStatus': _paymentStatus,
                    'pay_custom': double.tryParse(_paidAmountController.text) ?? 0.0,
                    'total_pay': _remainingAmount,
                    'order_type': widget.orderType,
                    'table_number': widget.tableNumber,
                    'table_id': widget.tableId, // أضف هذا
                    'final_total': _finalTotal,
                  };

                  await widget.onSubmit(paymentData);
                  setState(() => _isLoading = false);
                },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'تأكيد الدفع والطلب',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}