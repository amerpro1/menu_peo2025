import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

class MenuEditScreen extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic> profile;
  final VoidCallback onSave;

  const MenuEditScreen({
    super.key,
    this.item,
    required this.categories,
    required this.onSave,
    required this.profile,
  });

  @override
  State<MenuEditScreen> createState() => _MenuEditScreenState();
}

class _MenuEditScreenState extends State<MenuEditScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryId;
  XFile? _selectedImage;
  String? _existingImagePath;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name']?.toString() ?? '';
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _descriptionController.text = widget.item!['descrip_item']?.toString() ?? '';
      _selectedCategoryId = widget.item!['category_id'] as String?;
      _existingImagePath = widget.item!['image_url']?.toString();
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 70,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _existingImagePath = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'خطأ في اختيار الصورة: ${e.toString()}');
      }
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = path.extension(imageFile.name).replaceFirst('.', '');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('menu_images')
          .uploadBinary(fileName, bytes);

      return supabase.storage
          .from('menu_images')
          .getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'خطأ في رفع الصورة: ${e.toString()}');
      }
      return null;
    }
  }

  Future<void> _deleteOldImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      if (segments.length < 3) return;

      final bucket = segments[1];
      final fileName = segments.sublist(2).join('/');

      await supabase.storage.from(bucket).remove([fileName]);
    } catch (e) {
      debugPrint('خطأ في حذف الصورة القديمة: $e');
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text);
    if (price == null) {
      setState(() => _error = 'يجب أن يكون السعر رقمًا صحيحًا');
      return;
    }

    if (_selectedCategoryId == null) {
      setState(() => _error = 'يجب اختيار فئة');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      String? imageUrl = _existingImagePath;

      // إذا تم اختيار صورة جديدة
      if (_selectedImage != null) {
        // حذف الصورة القديمة إذا كانت موجودة
        if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
          await _deleteOldImage(_existingImagePath!);
        }
        // رفع الصورة الجديدة
        imageUrl = await _uploadImage(_selectedImage!);
        if (imageUrl == null) throw Exception('فشل رفع الصورة');
      }

      final Map<String, dynamic> itemData = {
        'name': _nameController.text,
        'price': price,
        'descrip_item': _descriptionController.text,
        'category_id': _selectedCategoryId,
        'updated_at': DateTime.now().toIso8601String(),
        'restaurant_id': widget.profile['restaurant_id'],
      };

      if (imageUrl != null) {
        itemData['image_url'] = imageUrl;
      }

      if (widget.item == null) {
        // إضافة عنصر جديد
        await supabase.from('menu_items').insert(itemData);
      } else {
        // تحديث العنصر الموجود
        await supabase
            .from('menu_items')
            .update(itemData)
            .eq('id', widget.item!['id']);
      }

      if (mounted) {
        widget.onSave();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'خطأ في الحفظ: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'إضافة عنصر جديد' : 'تعديل العنصر'),
        actions: [
          if (widget.item != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: const Text('هل أنت متأكد من حذف هذا العنصر؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('حذف', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  Navigator.pop(context, true);
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // صورة العنصر
              _buildImageSection(),
              const SizedBox(height: 20),

              // حقل اسم العنصر
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم العنصر',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fastfood),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // حقل السعر
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // حقل الوصف
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // اختيار الفئة
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('اختر الفئة'),
                  ),
                  ...widget.categories.map((category) {
                    final categoryId = category['id'] as String?;
                    return DropdownMenuItem<String>(
                      value: categoryId,
                      child: Text(category['name']?.toString() ?? 'غير معروف'),
                    );
                  }).toList(),
                ],
                onChanged: (value) => setState(() => _selectedCategoryId = value),
                decoration: const InputDecoration(
                  labelText: 'الفئة',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                validator: (value) => value == null ? 'مطلوب' : null,
              ),
              const SizedBox(height: 16),

              // رسالة الخطأ
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 24),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ', style: TextStyle(fontSize: 18)),
                  onPressed: _saveItem,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        // عرض الصورة الحالية أو المختارة
        if (_selectedImage != null)
          FutureBuilder<Uint8List>(
            future: _selectedImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    snapshot.data!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          )
        else if (_existingImagePath != null && _existingImagePath!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: _existingImagePath!,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                height: 150,
                width: double.infinity,
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                height: 150,
                width: double.infinity,
                child: const Icon(Icons.broken_image, size: 50),
              ),
            ),
          )
        else
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.image, size: 50, color: Colors.grey),
          ),

        const SizedBox(height: 10),

        // زر اختيار الصورة
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('اختر صورة'),
            onPressed: _pickImage,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}