
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ReportsScreen extends StatefulWidget {
  final String? restaurantId;
  const ReportsScreen({super.key, this.restaurantId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // Time range
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  // UI State
  bool _loading = false;
  String? _error;
  late final TabController _tab;

  // Filter: order type
  // 'all' | 'delivery' | 'takeaway' | 'dine_in'
  String _selectedType = 'all';

  // Metric mode: show "value" or "count"
  String _metricMode = 'value';

  // Raw cache
  List<Map<String, dynamic>> _ordersCache = [];

  // Aggregates (based on current filter)
  double _total = 0.0;
  int _count = 0;
  double _avg = 0.0;

  // Paid/unpaid values
  double _paidAll = 0.0, _unpaidAll = 0.0;
  double _paidDelivery = 0.0, _unpaidDelivery = 0.0;
  double _paidTakeaway = 0.0, _unpaidTakeaway = 0.0;
  double _paidDineIn = 0.0, _unpaidDineIn = 0.0;

  // Paid/unpaid counts
  int _paidCountAll = 0, _unpaidCountAll = 0;
  int _paidCountDelivery = 0, _unpaidCountDelivery = 0;
  int _paidCountTakeaway = 0, _unpaidCountTakeaway = 0;
  int _paidCountDineIn = 0, _unpaidCountDineIn = 0;

  // By day
  List<Map<String, dynamic>> _byDay = [];
  Map<String, dynamic>? _bestDay;

  // Top items
  List<Map<String, dynamic>> _topItems = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<String> _getRestaurantId() async {
    if (widget.restaurantId != null) return widget.restaurantId!;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('لم يتم تسجيل الدخول');
    }
    final row = await supabase
        .from('profiles')
        .select('restaurant_id')
        .eq('id', uid)
        .single();
    final rid = row['restaurant_id'] as String?;
    if (rid == null) {
      throw Exception('لا يوجد مطعم مرتبط بالمستخدم');
    }
    return rid;
  }

  bool _isPaid(dynamic status) {
    final s = (status ?? '').toString().toLowerCase();
    return s == 'paid' || s == 'مدفوع';
  }

  bool _isUnpaid(dynamic status) {
    final s = (status ?? '').toString().toLowerCase();
    return s == 'unpaid' || s == 'غير مدفوع' || s == 'غيرمدفوع';
  }

  String _normalizeType(dynamic orderType) {
    final t = (orderType ?? '').toString().toLowerCase();
    if (t.contains('delivery') || t.contains('توصيل')) return 'delivery';
    if (t.contains('takeaway') || t.contains('استلام')) return 'takeaway';
    if (t.contains('dine') || t.contains('مطعم') || t.contains('داخل')) return 'dine_in';
    return t.isEmpty ? 'unknown' : t;
  }

  List<Map<String, dynamic>> _applyTypeFilter(List<Map<String, dynamic>> src) {
    if (_selectedType == 'all') return src;
    return src.where((r) => _normalizeType(r['order_type']) == _selectedType).toList();
  }

  void _recalcFromCache() {
    final orders = _applyTypeFilter(_ordersCache);

    // Totals
    double total = 0;
    int count = orders.length;

    // Paid/unpaid totals & counts (by type)
    double paidAll = 0, unpaidAll = 0;
    double paidDel = 0, unpaidDel = 0;
    double paidTak = 0, unpaidTak = 0;
    double paidDin = 0, unpaidDin = 0;

    int paidCountAll = 0, unpaidCountAll = 0;
    int paidCountDel = 0, unpaidCountDel = 0;
    int paidCountTak = 0, unpaidCountTak = 0;
    int paidCountDin = 0, unpaidCountDin = 0;

    // By day (filtered)
    final Map<DateTime, double> bucket = {};

    // Top items agg
    final Map<String, Map<String, num>> itemAgg = {};

    for (final r in orders) {
      final amount = (r['total'] as num?)?.toDouble() ?? 0.0;
      total += amount;

      final t = _normalizeType(r['order_type']);
      final paid = _isPaid(r['payment_status']);
      final unpaid = _isUnpaid(r['payment_status']);

      if (paid) {
        paidAll += amount;
        paidCountAll += 1;
        if (t == 'delivery') { paidDel += amount; paidCountDel++; }
        else if (t == 'takeaway') { paidTak += amount; paidCountTak++; }
        else if (t == 'dine_in') { paidDin += amount; paidCountDin++; }
      } else if (unpaid) {
        unpaidAll += amount;
        unpaidCountAll += 1;
        if (t == 'delivery') { unpaidDel += amount; unpaidCountDel++; }
        else if (t == 'takeaway') { unpaidTak += amount; unpaidCountTak++; }
        else if (t == 'dine_in') { unpaidDin += amount; unpaidCountDin++; }
      }

      // by day
      final ts = DateTime.parse(r['created_at'] as String).toLocal();
      final day = DateTime(ts.year, ts.month, ts.day);
      bucket.update(day, (x) => x + amount, ifAbsent: () => amount);

      // items
      final items = r['items'];
      if (items is List) {
        for (final it in items) {
          try {
            final name = (it['name'] ?? '') as String;
            if (name.isEmpty) continue;
            final price = (it['price'] as num?) ?? 0;
            final qty = (it['quantity'] as num?) ?? 0;
            final totalLine = price * qty;
            final m = itemAgg.putIfAbsent(name, () => {'qty': 0, 'total': 0});
            m['qty'] = (m['qty'] ?? 0) + qty;
            m['total'] = (m['total'] ?? 0) + totalLine;
          } catch (_) {}
        }
      }
    }

    final avg = count == 0 ? 0.0 : total / count;

    final byDay = bucket.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final byDayOut = byDay.map((e) => {'day': e.key, 'total': e.value}).toList();

    MapEntry<DateTime, double>? best;
    for (final e in byDay) {
      if (best == null || e.value > best!.value) best = e;
    }
    final bestDay = best == null ? null : {'day': best!.key, 'total': best!.value};

    final topItems = itemAgg.entries
        .map((e) => {
      'name': e.key,
      'qty': (e.value['qty'] ?? 0).toInt(),
      'total': (e.value['total'] ?? 0).toDouble(),
    })
        .toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    setState(() {
      _total = total;
      _count = count;
      _avg = avg;

      _byDay = byDayOut;
      _bestDay = bestDay;
      _topItems = topItems.take(20).toList();

      _paidAll = paidAll; _unpaidAll = unpaidAll;
      _paidDelivery = paidDel; _unpaidDelivery = unpaidDel;
      _paidTakeaway = paidTak; _unpaidTakeaway = unpaidTak;
      _paidDineIn = paidDin; _unpaidDineIn = unpaidDin;

      _paidCountAll = paidCountAll; _unpaidCountAll = unpaidCountAll;
      _paidCountDelivery = paidCountDel; _unpaidCountDelivery = unpaidCountDel;
      _paidCountTakeaway = paidCountTak; _unpaidCountTakeaway = unpaidCountTak;
      _paidCountDineIn = paidCountDin; _unpaidCountDineIn = unpaidCountDin;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rid = await _getRestaurantId();
      final rows = await supabase
          .from('orders')
          .select('id,total,created_at,items,order_type,payment_status')
          .eq('restaurant_id', rid)
          .gte('created_at', _from.toIso8601String())
          .lte('created_at', _to.toIso8601String())
          .order('created_at', ascending: true);

      _ordersCache = (rows as List).cast<Map<String, dynamic>>();
      _recalcFromCache();
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التقارير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Quick ranges
  void _quickRange(String kind) {
    final now = DateTime.now();
    setState(() {
      if (kind == 'today') {
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (kind == '7d') {
        _from = now.subtract(const Duration(days: 7));
        _to = now;
      } else if (kind == '30d') {
        _from = now.subtract(const Duration(days: 30));
        _to = now;
      } else if (kind == 'month') {
        _from = DateTime(now.year, now.month, 1);
        _to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      }
    });
    _load();
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _from = DateTime(picked.year, picked.month, picked.day);
        } else {
          _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _load();
    }
  }



  String _fmtVal(num v) => NumberFormat('#,##0.00').format(v);

  Future<pw.Font> _loadArabicFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      try {
        final data = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
        return pw.Font.ttf(data);
      } catch (_) {
        // Fallback: default font (قد لا يدعم العربية بشكل كامل)
        return pw.Font.helvetica();
      }
    }
  }

  Future<void> _printReport() async {
    try {
      final arabicFont = await _loadArabicFont();
      final theme = pw.ThemeData.withFont(base: arabicFont);

      final doc = pw.Document();
      final df = DateFormat('yyyy-MM-dd');

      // Build tables data
      final byDayRows = _byDay.map((e) => [
        df.format(e['day'] as DateTime),
        _fmtVal((e['total'] as num).toDouble()),
      ]).toList();

      // Paid/Unpaid grids
      final paidGrid = [
        ['الكل', _fmtVal(_paidAll), _paidCountAll.toString()],
        ['التوصيل', _fmtVal(_paidDelivery), _paidCountDelivery.toString()],
        ['استلام من مطعم', _fmtVal(_paidTakeaway), _paidCountTakeaway.toString()],
        ['تناول في المطعم', _fmtVal(_paidDineIn), _paidCountDineIn.toString()],
      ];

      final unpaidGrid = [
        ['الكل', _fmtVal(_unpaidAll), _unpaidCountAll.toString()],
        ['التوصيل', _fmtVal(_unpaidDelivery), _unpaidCountDelivery.toString()],
        ['استلام من مطعم', _fmtVal(_unpaidTakeaway), _unpaidCountTakeaway.toString()],
        ['تناول في المطعم', _fmtVal(_unpaidDineIn), _unpaidCountDineIn.toString()],
      ];

      // Conversion
      final totalOrders = _paidCountAll + _unpaidCountAll;
      final conv = totalOrders == 0 ? 0.0 : (_paidCountAll / totalOrders) * 100.0;

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            theme: theme,
          ),
          build: (ctx) => [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('تقرير المبيعات', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('الفترة: ${df.format(_from)} — ${df.format(_to)}'),
                  pw.SizedBox(height: 12),
                  // KPIs row
                  pw.Row(
                    children: [
                      _kpiBox('إجمالي المبيعات', _fmtVal(_total)),
                      pw.SizedBox(width: 8),
                      _kpiBox('عدد الطلبات', '$_count'),
                      pw.SizedBox(width: 8),
                      _kpiBox('متوسط الطلب', _fmtVal(_avg)),
                      pw.SizedBox(width: 8),
                      _kpiBox('معدل التحويل', '${conv.toStringAsFixed(1)}%'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('المدفوعة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  _gridTable(['الفئة', 'القيمة', 'العدد'], paidGrid),
                  pw.SizedBox(height: 12),
                  pw.Text('غير المدفوعة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  _gridTable(['الفئة', 'القيمة', 'العدد'], unpaidGrid),
                  pw.SizedBox(height: 12),
                  pw.Text('حسب اليوم', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  _gridTable(['اليوم', 'الإجمالي'], byDayRows),
                ],
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => await doc.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر إنشاء ملف الطباعة: $e')),
      );
    }
  }

  // Helpers for pdf layout
  pw.Widget _kpiBox(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _gridTable(List<String> header, List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8F5E9)),
          children: header.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          )).toList(),
        ),
        ...rows.map((r) => pw.TableRow(
          children: r.map((c) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(c),
          )).toList(),
        )),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final currency = NumberFormat('#,##0.00');

    // Conversion rate
    final totalOrders = _paidCountAll + _unpaidCountAll;
    final conv = totalOrders == 0 ? 0.0 : (_paidCountAll / totalOrders) * 100.0;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          actions: [IconButton(icon: Icon(Icons.print), onPressed: _printReport)],
          title: const Text('التقارير'),
          backgroundColor: Colors.teal,
          bottom: TabBar(
            controller: _tab,
            tabs: const [
              Tab(text: 'ملخص'),
              Tab(text: 'حسب اليوم'),
              Tab(text: 'الأصناف'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Time range bar + filters
            Container(
              color: Colors.teal.withOpacity(0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(from: true),
                          child: Text('من: ${df.format(_from)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(from: false),
                          child: Text('إلى: ${df.format(_to)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _load,
                        child: _loading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('تحديث'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QuickChip(label: 'اليوم', onTap: () => _quickRange('today')),
                      _QuickChip(label: '7 أيام', onTap: () => _quickRange('7d')),
                      _QuickChip(label: '30 يومًا', onTap: () => _quickRange('30d')),
                      _QuickChip(label: 'هذا الشهر', onTap: () => _quickRange('month')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Type filter
                  Row(
                    children: [
                      _TypeChip(
                        label: 'الكل',
                        active: _selectedType == 'all',
                        onTap: () {
                          setState(() => _selectedType = 'all');
                          _recalcFromCache();
                        },
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'التوصيل',
                        active: _selectedType == 'delivery',
                        onTap: () {
                          setState(() => _selectedType = 'delivery');
                          _recalcFromCache();
                        },
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'استلام',
                        active: _selectedType == 'takeaway',
                        onTap: () {
                          setState(() => _selectedType = 'takeaway');
                          _recalcFromCache();
                        },
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(
                        label: 'داخل المطعم',
                        active: _selectedType == 'dine_in',
                        onTap: () {
                          setState(() => _selectedType = 'dine_in');
                          _recalcFromCache();
                        },
                      ),
                      const Spacer(),
                      // Metric mode toggle
                      ToggleButtons(
                        isSelected: [_metricMode == 'value', _metricMode == 'count'],
                        onPressed: (i) {
                          setState(() => _metricMode = (i == 0) ? 'value' : 'count');
                        },
                        borderRadius: BorderRadius.circular(12),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('القيمة'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('العدد'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                color: Colors.red.withOpacity(.08),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  // Summary tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MetricCard(
                              title: 'إجمالي المبيعات',
                              value: NumberFormat('#,##0.00').format(_total),
                              icon: Icons.attach_money,
                            ),
                            const SizedBox(width: 8),
                            _MetricCard(
                              title: 'عدد الطلبات',
                              value: '$_count',
                              icon: Icons.receipt_long,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _MetricCard(
                              title: 'متوسط قيمة الطلب',
                              value: NumberFormat('#,##0.00').format(_avg),
                              icon: Icons.calculate_rounded,
                            ),
                            const SizedBox(width: 8),
                            _MetricCard(
                              title: 'معدل التحويل (مدفوعة/الكل)',
                              value: '${conv.toStringAsFixed(1)}%',
                              icon: Icons.percent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('المدفوعة', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _metricMode == 'value' ? [
                            _MetricTile(title: 'الكل', value: NumberFormat('#,##0.00').format(_paidAll)),
                            _MetricTile(title: 'استلام من مطعم', value: NumberFormat('#,##0.00').format(_paidTakeaway)),
                            _MetricTile(title: 'التوصيل', value: NumberFormat('#,##0.00').format(_paidDelivery)),
                            _MetricTile(title: 'تناول في المطعم', value: NumberFormat('#,##0.00').format(_paidDineIn)),
                          ] : [
                            _MetricTile(title: 'الكل', value: '$_paidCountAll'),
                            _MetricTile(title: 'استلام من مطعم', value: '$_paidCountTakeaway'),
                            _MetricTile(title: 'التوصيل', value: '$_paidCountDelivery'),
                            _MetricTile(title: 'تناول في المطعم', value: '$_paidCountDineIn'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('غير المدفوعة', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _metricMode == 'value' ? [
                            _MetricTile(title: 'الكل', value: NumberFormat('#,##0.00').format(_unpaidAll)),
                            _MetricTile(title: 'استلام من مطعم', value: NumberFormat('#,##0.00').format(_unpaidTakeaway)),
                            _MetricTile(title: 'التوصيل', value: NumberFormat('#,##0.00').format(_unpaidDelivery)),
                            _MetricTile(title: 'تناول في المطعم', value: NumberFormat('#,##0.00').format(_unpaidDineIn)),
                          ] : [
                            _MetricTile(title: 'الكل', value: '$_unpaidCountAll'),
                            _MetricTile(title: 'استلام من مطعم', value: '$_unpaidCountTakeaway'),
                            _MetricTile(title: 'التوصيل', value: '$_unpaidCountDelivery'),
                            _MetricTile(title: 'تناول في المطعم', value: '$_unpaidCountDineIn'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Mini two-bars (paid vs unpaid)
                        const Text('المدفوعة مقابل غير المدفوعة (حسب التصفية الحالية)'),
                        const SizedBox(height: 8),
                        _TwoBars(
                          paid: _metricMode == 'value' ? _paidAll : _paidCountAll.toDouble(),
                          unpaid: _metricMode == 'value' ? _unpaidAll : _unpaidCountAll.toDouble(),
                          isCount: _metricMode == 'count',
                        ),
                        const SizedBox(height: 12),
                        const Text('نظرة سريعة (الرسم)'),
                        const SizedBox(height: 8),
                        _Sparkline(byDay: _byDay),
                      ],
                    ),
                  ),
                  // By day tab
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Card(
                      elevation: 2,
                      child: ListView.separated(
                        itemCount: _byDay.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = _byDay[index];
                          final day = row['day'] as DateTime;
                          final total = (row['total'] as num).toDouble();
                          return ListTile(
                            dense: true,
                            title: Text(DateFormat('yyyy-MM-dd').format(day)),
                            trailing: Text(NumberFormat('#,##0.00').format(total)),
                          );
                        },
                      ),
                    ),
                  ),
                  // Top items tab
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Card(
                      elevation: 2,
                      child: ListView.separated(
                        itemCount: _topItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = _topItems[index];
                          return ListTile(
                            title: Text(row['name'] as String),
                            subtitle: Text('الكمية: ${row['qty']}'),
                            trailing: Text(NumberFormat('#,##0.00').format(row['total'] as double)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Styled components

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.teal : Colors.white,
          border: Border.all(color: Colors.teal.withOpacity(.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.teal.withOpacity(.25)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Sparkline
class _Sparkline extends StatelessWidget {
  final List<Map<String, dynamic>> byDay;
  const _Sparkline({required this.byDay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CustomPaint(
            painter: _SparklinePainter(byDay.map<double>((e) => (e['total'] as num).toDouble()).toList()),
            child: Container(),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  _SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.teal;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = (maxVal - minVal).abs() < 1e-6 ? 1.0 : (maxVal - minVal);

    final dx = size.width / (data.length - 1).clamp(1, 1000000);
    final path = Path();

    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Two bars chart (paid vs unpaid)
class _TwoBars extends StatelessWidget {
  final double paid;
  final double unpaid;
  final bool isCount;
  const _TwoBars({required this.paid, required this.unpaid, required this.isCount});

  @override
  Widget build(BuildContext context) {
    final maxv = (paid > unpaid ? paid : unpaid);
    final p = maxv <= 0 ? 0.0 : (paid / maxv);
    final u = maxv <= 0 ? 0.0 : (unpaid / maxv);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Bar(label: 'مدفوعة', fraction: p, value: isCount ? paid.toStringAsFixed(0) : NumberFormat('#,##0.00').format(paid)),
            const SizedBox(width: 12),
            _Bar(label: 'غير مدفوعة', fraction: u, value: isCount ? unpaid.toStringAsFixed(0) : NumberFormat('#,##0.00').format(unpaid)),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double fraction; // 0..1
  final String value;
  const _Bar({required this.label, required this.fraction, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, cs) {
              final w = cs.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 16,
                    width: w,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 16,
                    width: w * fraction,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.teal.withOpacity(.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label),
      ),
    );
  }
}
