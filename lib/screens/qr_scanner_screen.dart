import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home/home_screen.dart'; // المسار النسبي الصحيح

class QRScannerScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const QRScannerScreen({super.key, required this.profile});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isLoading = false;
  bool _hasPermission = true; // افترض أن الصلاحية موجودة مؤقتاً

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.grey),
            onPressed: () {
              // تنفيذ تبديل الإضاءة هنا
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  _handleScannedCode(barcode.rawValue ?? '');
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black54,
            child: const Text(
              'ضع كود QR داخل الإطار للمسح',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _handleScannedCode(String scannedCode) {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // تحقق إذا كان الرابط يحتوي على معرف الطاولة
    if (scannedCode.startsWith('restaurant://table/')) {
      final tableId = scannedCode.replaceFirst('restaurant://table/', '');

      // الانتقال مباشرة إلى شاشة العناصر مع معرف الطاولة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            profile: widget.profile,
            initialTableId: tableId,
            initialTableNumber: tableId,
          ),
        ),
      );
    } else {
      // إذا كان الرابط غير صحيح
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رابط QR Code غير صحيح'),
          backgroundColor: Colors.red,
        ),
      );

      // إعادة تشغيل الماسح بعد ثانية
      Future.delayed(const Duration(seconds: 1), () {
        cameraController.start();
      });
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}