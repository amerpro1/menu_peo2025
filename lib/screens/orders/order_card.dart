import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/extensions.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String, String) onStatusUpdate;
  final String userRole;

  const OrderCard({
    super.key,
    required this.order,
    required this.onStatusUpdate,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.parse(order['created_at']).toLocal();
    final formattedTime = DateFormat('hh:mm a').format(createdAt);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (محتوى بطاقة الطلب)
          ],
        ),
      ),
    );
  }
}