import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuItemsManagementScreen extends StatefulWidget {
  const MenuItemsManagementScreen({super.key});

  @override
  State<MenuItemsManagementScreen> createState() => _MenuItemsManagementScreenState();
}

class _MenuItemsManagementScreenState extends State<MenuItemsManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  String? error;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  int? _selectedCategoryId;
  int _editingItemId = 0;
  XFile? _selectedImage;
  String? _existingImagePath;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() => isLoading = true);

      final categoriesResponse = await supabase
          .from('categories')
          .select()
          .order('name');

      final menuItemsResponse = await supabase
          .from('menu_items')
          .select()
          .order('name');

      setState(() {
        categories = List<Map<String, dynamic>>.from(categoriesResponse);
        menuItems = List<Map<String, dynamic>>.from(menuItemsResponse);
        isLoading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Error loading data: ${e.toString()}';
      });
    }
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('menu_images')
          .uploadBinary(fileName, bytes);

      return fileName;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text);
    if (price == null) {
      setState(() => error = 'Price must be a valid number');
      return;
    }

    try {
      setState(() => isLoading = true);

      String? imagePath = _existingImagePath;

      if (_selectedImage != null) {
        imagePath = await _uploadImage(_selectedImage!);
        if (imagePath == null) throw Exception('Failed to upload image');
      }

      final Map<String, dynamic> itemData = {
        'name': _nameController.text,
        'price': price,
        'category_id': _selectedCategoryId,
        'image_url': imagePath,
      };

      if (_editingItemId == 0) {
        await supabase.from('menu_items').insert(itemData);
      } else {
        await supabase.from('menu_items')
            .update(itemData)
            .eq('id', _editingItemId);
      }

      await _fetchData();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Save error: ${e.toString()}';
      });
    }
  }

  Future<void> _deleteItem(int id, String? imagePath) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('menu_items').delete().eq('id', id);

      if (imagePath != null && imagePath.isNotEmpty) {
        await supabase.storage
            .from('menu_images')
            .remove([imagePath]);
      }

      await _fetchData();
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Delete error: ${e.toString()}';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = image;
        _existingImagePath = null;
      });
    }
  }

  void _showEditDialog(Map<String, dynamic>? item) {
    _editingItemId = item?['id'] ?? 0;
    _nameController.text = item?['name'] ?? '';
    _priceController.text = item?['price']?.toString() ?? '';
    _selectedCategoryId = item?['category_id'];
    _existingImagePath = item?['image_url'];
    _selectedImage = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(_editingItemId == 0 ? 'Add New Item' : 'Edit Item'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                      ),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        items: categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['category_id'],
                            child: Text(category['name']),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCategoryId = value),
                        decoration: const InputDecoration(labelText: 'Category'),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text('Select Image'),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedImage != null)
                        FutureBuilder<Uint8List>(
                          future: _selectedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                height: 100,
                                fit: BoxFit.cover,
                              );
                            }
                            return const CircularProgressIndicator();
                          },
                        )
                      else if (_existingImagePath != null && _existingImagePath!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: supabase.storage
                              .from('menu_images')
                              .getPublicUrl(_existingImagePath!),
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saveItem,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => _resetForm());
  }

  void _resetForm() {
    _editingItemId = 0;
    _nameController.clear();
    _priceController.clear();
    _selectedCategoryId = null;
    _selectedImage = null;
    _existingImagePath = null;
    setState(() => error = null);
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final imageUrl = item['image_url'] != null && item['image_url'].isNotEmpty
        ? supabase.storage.from('menu_images').getPublicUrl(item['image_url'])
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: imageUrl != null
            ? CachedNetworkImage(
          imageUrl: imageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        )
            : const Icon(Icons.fastfood, size: 50),
        title: Text(item['name']),
        subtitle: Text('\$${item['price']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showEditDialog(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(item['id'], item['image_url']),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int id, String? imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteItem(id, imagePath);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : menuItems.isEmpty
          ? const Center(child: Text('No items found'))
          : RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView.builder(
          itemCount: menuItems.length,
          itemBuilder: (context, index) {
            return _buildMenuItemCard(menuItems[index]);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}