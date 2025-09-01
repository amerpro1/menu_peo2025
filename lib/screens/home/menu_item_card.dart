import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onAdd;
  final Color primaryColor;
  final Color secondaryColor;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onAdd,
    this.primaryColor = const Color(0xFFFF6B00),
    this.secondaryColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // صورة العنصر
              Hero(
                tag: 'item-image-${item['id']}',
                child: SizedBox(
                  height: 150,
                  child: CachedNetworkImage(
                    imageUrl: item['image_url'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            secondaryColor.withOpacity(0.1),
                            primaryColor.withOpacity(0.2)
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.fastfood,
                            size: 50,
                            color: primaryColor.withOpacity(0.5)),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.broken_image,
                            size: 50,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

              // معلومات العنصر
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 50), // مساحة أقل للزر
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // صف يحتوي على الاسم والسعر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // اسم العنصر
                        Expanded(
                          child: Text(
                            item['name'] ?? 'بدون اسم',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: secondaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // سعر العنصر
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${item['price']?.toString() ?? '0'} د.ع',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // زر الإضافة (مصغر)
          Positioned(
            bottom: 12, // تم تقليل المسافة من الأسفل
            right: 16,
            left: 16,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40), // ارتفاع أقل (40 بدلاً من 48)
                padding: const EdgeInsets.symmetric(horizontal: 12), // حشو أقل
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2, // ظل أقل
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart, size: 18), // أيقونة أصغر
                  SizedBox(width: 6), // مسافة أقل بين الأيقونة والنص
                  Text(
                    'أضف إلى السلة',
                    style: TextStyle(fontSize: 14), // حجم خط أصغر
                  ),
                ],
              ),
            ),
          ),

          // شريط التصنيف
          if (item['category'] != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item['category'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}