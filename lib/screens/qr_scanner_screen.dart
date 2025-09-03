import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:menu_peo2025/screens/home/home_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const QRScannerScreen({super.key, required this.restaurant});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  void _goToHome(String qrValue) {
    final uri = Uri.tryParse(qrValue);
    final tableId = uri?.queryParameters['id'] ?? "";
    final tableNumber = uri?.queryParameters['number'] ?? "";

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          profile: {
            "role": "customer",
            "restaurant_id": widget.restaurant['id'],
            "full_name": "زبون",
            "email": "guest@local.com",
          },
          initialTableId: tableId,
          initialTableNumber: tableNumber,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("مسح QR للطاولة")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final qrValue = barcodes.first.rawValue ?? "";
            controller.stop();
            _goToHome(qrValue);
          }
        },
      ),
    );
  }
}
