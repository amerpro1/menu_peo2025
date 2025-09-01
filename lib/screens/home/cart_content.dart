import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class CartContent extends StatelessWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(int, String) onRemove;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController notesController;
  final VoidCallback onProceedToPayment;
  final BuildContext parentContext;

  const CartContent({
    super.key,
    required this.cartItems,
    required this.onRemove,
    required this.nameController,
    required this.phoneController,
    required this.notesController,
    required this.onProceedToPayment,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFFF6B00);
    final secondaryColor = Colors.black;
    final total = cartItems.fold(
      0.0,
          (sum, item) => sum + (item['price'] * item['quantity']),
    );
    final isDineIn =
        ModalRoute.of(context)?.settings.arguments as bool? ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9F9F9), Color(0xFFEEEEEE)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'سلة المشتريات',
            style: GoogleFonts.tajawal(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: secondaryColor),
            onPressed: () => Navigator.pop(parentContext),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              if (cartItems.isEmpty)
                _buildEmptyCart(context, primaryColor, secondaryColor)
              else
                Column(
                  children: [
                    _buildCartItems(primaryColor, secondaryColor),
                    const SizedBox(height: 20),
                    if (!isDineIn)
                      _buildCustomerInfo(primaryColor, secondaryColor),
                    const SizedBox(height: 20),
                    _buildOrderSummary(
                      primaryColor,
                      secondaryColor,
                      total,
                    ),
                    const SizedBox(height: 30),
                    _buildActionButton(context, primaryColor, isDineIn),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItems(Color primaryColor, Color secondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shopping_bag, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'العناصر المختارة',
                  style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder:
                (context, index) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final item = cartItems[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(
                            item['image_url'] ?? '',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'بدون اسم',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: secondaryColor,
                            ),
                          ),
                          Text(
                            '${item['price']} د.ع',
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: 18),
                            onPressed: () => onRemove(index, 'decrease'),
                            color: primaryColor,
                          ),
                          Text(
                            '${item['quantity']}',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add, size: 18),
                            onPressed: () => onRemove(index, 'increase'),
                            color: primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(
      BuildContext context,
      Color primaryColor,
      Color secondaryColor,
      ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/empty_cart.png', width: 200, height: 200),
          const SizedBox(height: 20),
          Text(
            'سلة التسوق فارغة',
            style: GoogleFonts.tajawal(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'قم بإضافة بعض المنتجات لتظهر هنا',
            style: GoogleFonts.tajawal(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'تصفح القائمة',
              style: GoogleFonts.tajawal(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo(Color primaryColor, Color secondaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلومات العميل',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: nameController,
            label: 'الاسم بالكامل',
            icon: Icons.person_outline,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: phoneController,
            label: 'رقم الهاتف',
            icon: Icons.phone_android_outlined,
            primaryColor: primaryColor,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: notesController,
            label: 'ملاحظات (اختياري)',
            icon: Icons.note_outlined,
            primaryColor: primaryColor,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.tajawal(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.tajawal(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: primaryColor.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildOrderSummary(
      Color primaryColor,
      Color secondaryColor,
      double total,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'ملخص الطلب',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'المجموع',
            '${total.toStringAsFixed(2)} د.ع',
            secondaryColor,
          ),
          const Divider(height: 24, thickness: 1, color: Colors.grey),
          _buildSummaryRow(
            'الإجمالي',
            '${total.toStringAsFixed(2)} د.ع',
            primaryColor,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String title,
      String value,
      Color color, {
        bool isTotal = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      Color primaryColor,
      bool isDineIn,
      ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: primaryColor.withOpacity(0.5),
        ),
        onPressed:
        isDineIn
            ? () => Navigator.pop(
          parentContext,
          'confirm',
        ) // استخدم parentContext هنا
            : onProceedToPayment,
        child: Text(
          isDineIn ? 'تأكيد الطلب' : 'التوجه للدفع',
          style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}