import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'menu_edit.dart';
import 'menu_categories_screen.dart';

class MenuItemsManagementScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const MenuItemsManagementScreen({super.key, required this.profile});

  @override
  State<MenuItemsManagementScreen> createState() => _MenuItemsManagementScreenState();
}

class _MenuItemsManagementScreenState extends State<MenuItemsManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  String? searchQuery;
  String? error;
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final categoriesResponse = await supabase
          .from('categories')
          .select('id, name')
          .eq('restaurant_id', widget.profile['restaurant_id'])
          .order('name');

      final menuItemsResponse = await supabase
          .from('menu_items')
          .select('''*, categories(name)''')
          .eq('restaurant_id', widget.profile['restaurant_id'])
          .order('name');

      setState(() {
        categories = List<Map<String, dynamic>>.from(categoriesResponse);
        menuItems = List<Map<String, dynamic>>.from(menuItemsResponse);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'خطأ في جلب البيانات: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteItem(String id, String? imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => isLoading = true);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        await _deleteImageFromStorage(imageUrl);
      }

      await supabase.from('menu_items').delete().eq('id', id);
      await _fetchData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف العنصر بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحذف: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      if (segments.length < 3) return;

      final bucket = segments[1];
      final fileName = segments.sublist(2).join('/');

      await supabase.storage.from(bucket).remove([fileName]);
    } catch (e) {
      debugPrint('خطأ في حذف الصورة: $e');
    }
  }

  void _openEditScreen(Map<String, dynamic>? item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuEditScreen(
          item: item,
          profile: widget.profile,
          categories: categories,
          onSave: _fetchData,
        ),
      ),
    ).then((_) {
      _fetchData();
    });
  }

  List<Map<String, dynamic>> get _filteredItems {
    return menuItems.where((item) {
      final matchesSearch = searchQuery == null || searchQuery!.isEmpty ||
          (item['name']?.toString() ?? '')
              .toLowerCase()
              .contains(searchQuery!.toLowerCase());

      final matchesCategory = selectedCategoryId == null ||
          item['category_id'] == selectedCategoryId;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orangeColor = Colors.orange[700];
    final blackColor = Colors.grey[900];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('إدارة القائمة',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white
            )
        ),
        centerTitle: true,
        backgroundColor: blackColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(FeatherIcons.list, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuCategoriesScreen(profile: widget.profile),
                ),
              );
            },
            tooltip: 'إدارة الأقسام',
          ),
          IconButton(
            icon: const Icon(FeatherIcons.plus, color: Colors.white),
            onPressed: () => _openEditScreen(null),
            tooltip: 'إضافة عنصر جديد',
          ),
          IconButton(
            icon: const Icon(FeatherIcons.refreshCw, color: Colors.white),
            onPressed: _fetchData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: orangeColor),
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: orangeColor,
                ),
                child: const Text('إعادة المحاولة',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          _buildFilterBar(orangeColor!, blackColor!),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 60,
                    color: orangeColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد عناصر',
                    style: TextStyle(fontSize: 18),
                  ),
                  if (searchQuery != null || selectedCategoryId != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          searchQuery = null;
                          selectedCategoryId = null;
                        });
                      },
                      child: Text('إعادة تعيين الفلاتر',
                          style: TextStyle(color: orangeColor)),
                    ),
                ],
              ),
            )
                : _buildItemsList(orangeColor, blackColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(Color orangeColor, Color blackColor) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'بحث...',
              labelStyle: TextStyle(color: Colors.black),
              prefixIcon: Icon(FeatherIcons.search, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[50],
              suffixIcon: searchQuery != null && searchQuery!.isNotEmpty
                  ? IconButton(
                icon: Icon(FeatherIcons.x, size: 18, color: blackColor),
                onPressed: () => setState(() => searchQuery = null),
              )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) => setState(() => searchQuery = value),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: selectedCategoryId,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'جميع الفئات',
                          style: TextStyle(color: blackColor),
                        ),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'] as String?,
                          child: Text(
                            category['name']?.toString() ?? 'غير معروف',
                            style: TextStyle(color: blackColor),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? value) {
                      setState(() {
                        selectedCategoryId = value;
                      });
                    },
                    isExpanded: true,
                    icon: Icon(FeatherIcons.chevronDown, size: 18, color: blackColor),
                    hint: Text('اختر الفئة', style: TextStyle(color: blackColor)),
                    dropdownColor: Colors.white,
                    underline: Container(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(Color orangeColor, Color blackColor) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filteredItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final category = item['categories'] as Map<String, dynamic>?;
        final categoryName = category?['name']?.toString() ?? 'غير مصنف';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: item['image_url']?.toString() == null ||
                  item['image_url']?.toString()?.isEmpty == true
                  ? Icon(
                Icons.fastfood,
                size: 30,
                color: blackColor,
              )
                  : ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  fit: BoxFit.cover,
                  imageUrl: item['image_url']?.toString() ?? '',
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.broken_image,
                    color: orangeColor,
                  ),
                ),
              ),
            ),
            title: Text(
              item['name']?.toString() ?? 'بدون اسم',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: blackColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['price']?.toString() ?? '0'} ر.س',
                  style: TextStyle(
                    color: orangeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الفئة: $categoryName',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    FeatherIcons.edit,
                    size: 18,
                    color: orangeColor,
                  ),
                  onPressed: () => _openEditScreen(item),
                  splashRadius: 20,
                ),
                IconButton(
                  icon: Icon(
                    FeatherIcons.trash2,
                    size: 18,
                    color: Colors.red[700],
                  ),
                  onPressed: () => _deleteItem(item['id'] as String, item['image_url']?.toString()),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}