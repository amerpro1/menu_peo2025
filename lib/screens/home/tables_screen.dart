import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/animation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../payment/payment_screen.dart';
import '../unpaid_orders_screen.dart';
import 'home_screen.dart';
import 'dart:async';

class TablesScreen extends StatefulWidget {
  /// يمرَّر معرف المطعم الحالي + البروفايل (لاستخدام الدور وغيرها)
  final String restaurantId;
  final Map<String, dynamic> profile;

  const TablesScreen({
    Key? key,
    required this.restaurantId,
    required this.profile,
  }) : super(key: key);

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _floorController = TextEditingController();
  final _qrCodeController = TextEditingController();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> tables = [];
  List<Map<String, dynamic>> filteredTables = [];
  bool isLoading = true;
  String _editingTableId = '';
  bool _isSubmitting = false;
  String _filterStatus = 'all';
  late AnimationController _animationController;
  bool _showFloorPlan = false;
  final Map<String, Timer> _tableTimers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _setupRealtimeUpdates();
  }

  Future<void> _initData() async {
    await _checkSupabaseConnection();
    await fetchTables();
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      final response = await supabase.from('tables').select('*').limit(1);
      debugPrint('Supabase connection successful: ${response.length} tables');
    } catch (e) {
      debugPrint('Supabase connection failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الاتصال بالخادم: $e')),
      );
    }
  }

  void _setupRealtimeUpdates() {
    supabase
        .channel('tables_changes')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tables',
      callback: (payload) {
        debugPrint('Realtime update: $payload');
        fetchTables();
      },
    )
        .subscribe();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _capacityController.dispose();
    _floorController.dispose();
    _qrCodeController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    _tableTimers.forEach((_, timer) => timer.cancel());
    super.dispose();
  }

  Future<void> fetchTables() async {
    try {
      setState(() => isLoading = true);

      final data = await supabase
          .from('tables')
          .select('*')
          .eq('restaurant_id', widget.restaurantId)
          .order('number', ascending: true);

      debugPrint('Fetched ${data.length} tables');
      _updateTimers(data);

      setState(() {
        tables = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Error fetching tables: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في جلب البيانات: ${e.toString()}')),
      );
    }
  }

  void _updateTimers(List<dynamic> tablesData) {
    _tableTimers.forEach((_, timer) => timer.cancel());
    _tableTimers.clear();

    for (var table in tablesData) {
      if (table['status'] == 'occupied' && table['occupied_at'] != null) {
        final tableId = table['id'].toString();
        _tableTimers[tableId] = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  String _formatDuration(DateTime? occupiedAt) {
    if (occupiedAt == null) return '';
    final duration = DateTime.now().difference(occupiedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _generateAndSaveQRCode(String tableId, String tableNumber) async {
    try {
      final qrData = _qrCodeController.text.isNotEmpty
          ? _qrCodeController.text.trim()
          : 'https://yourwebsite.com/table/$tableId';

      await supabase
          .from('tables')
          .update({
        'qr_code': qrData,
        'qr_code_updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', tableId)
          .eq('restaurant_id', widget.restaurantId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء QR Code للطاولة $tableNumber')),
      );

      await fetchTables();
    } catch (e) {
      debugPrint('Error generating QR Code: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في إنشاء QR Code: ${e.toString()}')),
      );
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(tables);

    if (_filterStatus == 'available') {
      result = result.where((table) => table['status'] == 'available').toList();
    } else if (_filterStatus == 'occupied') {
      result = result.where((table) => table['status'] == 'occupied').toList();
    }

    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      result = result.where((table) {
        return table['number'].toString().toLowerCase().contains(searchTerm) ||
            (table['upper_floor']?.toString().toLowerCase().contains(searchTerm) ?? false);
      }).toList();
    }

    setState(() {
      filteredTables = result;
    });
  }

  Future<void> _addOrUpdateTable() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final tableData = {
        'number': _numberController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 4,
        'upper_floor': _floorController.text.trim().isNotEmpty ? _floorController.text.trim() : null,
        'qr_code': _qrCodeController.text.trim().isNotEmpty ? _qrCodeController.text.trim() : null,
        'status': 'available',
        'payment_status': null,
        'restaurant_id': widget.restaurantId,
        'created_at': DateTime.now().toIso8601String(),
      };

      if (_editingTableId.isEmpty) {
        final response = await supabase.from('tables').insert(tableData).select().single();
        debugPrint('Added new table: ${response['id']}');
        if (_qrCodeController.text.isEmpty) {
          await _generateAndSaveQRCode(response['id'].toString(), _numberController.text.trim());
        }
      } else {
        await supabase
            .from('tables')
            .update(tableData)
            .eq('id', _editingTableId)
            .eq('restaurant_id', widget.restaurantId);
        debugPrint('Updated table: $_editingTableId');
      }

      _resetForm();
      await fetchTables();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingTableId.isEmpty ? 'تمت إضافة الطاولة بنجاح' : 'تم تحديث الطاولة بنجاح')),
      );
    } on PostgrestException catch (e) {
      debugPrint('Postgrest Error: ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في قاعدة البيانات: ${e.message}')),
      );
    } catch (e) {
      debugPrint('Error saving table: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ غير متوقع: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _numberController.clear();
    _capacityController.clear();
    _floorController.clear();
    _qrCodeController.clear();
    _editingTableId = '';
  }

  Future<void> _deleteTable(String tableId) async {
    try {
      await supabase
          .from('tables')
          .delete()
          .eq('id', tableId)
          .eq('restaurant_id', widget.restaurantId);
      await fetchTables();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الطاولة بنجاح')));
    } catch (e) {
      debugPrint('Error deleting table: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: ${e.toString()}')),
      );
    }
  }

  void _showTableForm({Map<String, dynamic>? table}) {
    _editingTableId = table?['id']?.toString() ?? '';
    _numberController.text = table?['number']?.toString() ?? '';
    _capacityController.text = table?['capacity']?.toString() ?? '4';
    _floorController.text = table?['upper_floor']?.toString() ?? '';
    _qrCodeController.text = table?['qr_code']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _editingTableId.isEmpty ? 'إضافة طاولة جديدة' : 'تعديل الطاولة',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _numberController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الطاولة',
                      border: OutlineInputBorder(),
                      hintText: 'أدخل رقم الطاولة',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'مطلوب';
                      if (_editingTableId.isEmpty &&
                          tables.any((t) => t['number'] == value.trim() && t['restaurant_id'] == widget.restaurantId)) {
                        return 'رقم الطاولة موجود مسبقاً';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(
                      labelText: 'السعة (عدد الأشخاص)',
                      border: OutlineInputBorder(),
                      hintText: '4',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'مطلوب';
                      if (int.tryParse(value) == null) return 'يجب أن يكون رقماً';
                      if (int.parse(value) <= 0) return 'يجب أن يكون أكبر من صفر';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _floorController,
                    decoration: const InputDecoration(
                      labelText: 'الطابق (اختياري)',
                      border: OutlineInputBorder(),
                      hintText: 'مثل: الطابق الأول',
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _qrCodeController,
                    decoration: const InputDecoration(
                      labelText: 'رابط QR Code (اختياري)',
                      border: OutlineInputBorder(),
                      hintText: 'اتركه فارغاً لإنشاء رابط تلقائي',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_editingTableId.isNotEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        await _generateAndSaveQRCode(_editingTableId, _numberController.text);
                        Navigator.pop(context);
                      },
                      child: const Text('إنشاء/تحديث QR Code'),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                        onPressed: _isSubmitting
                            ? null
                            : () {
                          Navigator.pop(context);
                          _resetForm();
                        },
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _addOrUpdateTable,
                        child: _isSubmitting
                            ? const CircularProgressIndicator()
                            : Text(_editingTableId.isEmpty ? 'حفظ' : 'تعديل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(String tableId, String tableNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الطاولة رقم $tableNumber؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTable(tableId);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showQRCode(Map<String, dynamic> table) {
    final qrData = table['qr_code'] ?? 'restaurant://table/${table['id']}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR Code - طاولة ${table['number']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
            ),
            const SizedBox(height: 10),
            Text('رقم الطاولة: ${table['number']}'),
            if (table['upper_floor'] != null) Text('الطابق: ${table['upper_floor']}'),
            if (table['qr_code_updated_at'] != null)
              Text('آخر تحديث: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(table['qr_code_updated_at']))}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _generateAndSaveQRCode(table['id'].toString(), table['number'].toString());
            },
            child: const Text('تحديث QR'),
          ),
        ],
      ),
    );
  }

  void _handleTableTap(BuildContext context, Map<String, dynamic> table) {
    final isUnpaid = table['payment_status'] == 'unpaid';
    final isPreparing = table['order_status'] == 'preparing';
    final isReady = table['order_status'] == 'ready';
    final isCompleted = table['order_status'] == 'completed';

    if (table['status'] == 'available') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            profile: widget.profile,
            initialTableId: table['id'].toString(),
            initialTableNumber: table['number'].toString(),
          ),
        ),
      );
    } else {
      String statusMessage = 'الطاولة ${table['number']} محجوزة بالفعل';
      if (isPreparing) {
        statusMessage = 'الطاولة ${table['number']} قيد التحضير';
      } else if (isReady) {
        statusMessage = 'الطاولة ${table['number']} جاهزة للاستلام';
      } else if (isCompleted) {
        statusMessage = 'الطاولة ${table['number']} تم تسليمها';
      } else if (isUnpaid) {
        statusMessage = 'الطاولة ${table['number']} غير مدفوعة';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(statusMessage)));
    }
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    final isOccupied = table['status'] == 'occupied';
    final isUnpaid = table['payment_status'] == 'unpaid';
    final isPaid = table['payment_status'] == 'paid';
    final isPreparing = table['order_status'] == 'preparing';
    final isReady = table['order_status'] == 'ready';
    final isCompleted = table['order_status'] == 'completed';

    final tableNumber = table['number']?.toString() ?? 'N/A';
    final capacity = table['capacity']?.toString() ?? '4';
    final floor = table['upper_floor']?.toString();
    final occupiedAt = table['occupied_at'] != null ? DateTime.parse(table['occupied_at']) : null;

    Color tableColor;
    IconData statusIcon;
    String statusText;

    if (isCompleted) {
      tableColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'تم التسليم غير مدفوع';
    } else if (isReady) {
      tableColor = Colors.orange;
      statusIcon = Icons.done_all;
      statusText = ' جاهز للاستلام غير مدفوع';
    } else if (isPreparing) {
      tableColor = Colors.blue;
      statusIcon = Icons.timer;
      statusText = ' قيد التحضير غير مدفوع';
    } else if (isUnpaid) {
      tableColor = Colors.red;
      statusIcon = Icons.money_off;
      statusText = 'غير مدفوع ومحجوزة';
    } else if (isPaid) {
      tableColor = Colors.purple;
      statusIcon = Icons.attach_money;
      statusText = 'مدفوع';
    } else if (isOccupied) {
      tableColor = Colors.purple;
      statusIcon = Icons.attach_money;
      statusText = 'مدفوع ومشغول';
    } else {
      tableColor = Colors.green;
      statusIcon = Icons.check;
      statusText = 'فارغة';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: tableColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleTableTap(context, table),
        onLongPress: () => _showTableOptions(table),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(statusIcon, color: Colors.white),
                  if ((widget.profile['role'] ?? '') == 'admin')
                    const Icon(Icons.more_vert, color: Colors.white, size: 18),
                ],
              ),
              Column(
                children: [
                  Text('طاولة $tableNumber', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  if (floor != null && floor.isNotEmpty)
                    Text(floor, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Text('السعة: $capacity', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
              if (occupiedAt != null)
                Text(_formatDuration(occupiedAt), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloorPlanView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: MediaQuery.of(context).size.width * 1.5,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Stack(
            children: [
              Positioned(
                top: 50,
                left: 50,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(color: Colors.brown[200], borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('المطبخ')),
                ),
              ),
              ...filteredTables.map((table) {
                final isLarge = (table['capacity'] ?? 4) > 4;
                final isOccupied = table['status'] == 'occupied';
                final color = isOccupied ? Colors.red : Colors.green;

                return Positioned(
                  top: (table['position_y'] ?? 100).toDouble(),
                  left: (table['position_x'] ?? 100).toDouble(),
                  child: GestureDetector(
                    onTap: () {
                      if (table['status'] != 'occupied') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(
                              profile: widget.profile,
                              initialTableId: table['id'].toString(),
                              initialTableNumber: table['number'].toString(),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: isLarge ? 80 : 60,
                      height: isLarge ? 80 : 60,
                      decoration: BoxDecoration(
                        color: color,
                        shape: isLarge ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: isLarge ? BorderRadius.circular(12) : null,
                      ),
                      child: Center(
                        child: Text(
                          table['number'].toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableOptions(Map<String, dynamic> table) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('تعديل'),
            onTap: () {
              Navigator.pop(context);
              _showTableForm(table: table);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('عرض QR Code'),
            onTap: () {
              Navigator.pop(context);
              _showQRCode(table);
            },
          ),
          if ((widget.profile['role'] ?? '') == 'admin')
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(table['id'].toString(), table['number'].toString());
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطاولات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.money_off),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UnpaidOrdersScreen())),
            tooltip: 'الطلبات غير المدفوعة',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchTables, tooltip: 'تحديث'),
          IconButton(
            icon: Icon(_showFloorPlan ? Icons.grid_view : Icons.map),
            onPressed: () => setState(() => _showFloorPlan = !_showFloorPlan),
            tooltip: _showFloorPlan ? 'عرض الشبكة' : 'عرض الخريطة',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'بحث',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'ابحث برقم الطاولة أو الطابق',
                    ),
                    onChanged: (value) => _applyFilters(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'available', child: Text('فارغة')),
                    DropdownMenuItem(value: 'occupied', child: Text('مشغولة')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTables.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.table_restaurant, size: 50, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text('لا توجد طاولات مسجلة'),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: fetchTables, child: const Text('إعادة تحميل')),
                ],
              ),
            )
                : _showFloorPlan
                ? _buildFloorPlanView()
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: filteredTables.length,
              itemBuilder: (context, index) => _buildTableCard(filteredTables[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: (widget.profile['role'] ?? '') == 'admin'
          ? FloatingActionButton(
        onPressed: () => _showTableForm(),
        child: const Icon(Icons.add),
        tooltip: 'إضافة طاولة',
      )
          : null,
    );
  }
}
