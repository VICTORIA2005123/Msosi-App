import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/menu_item.dart';
import '../../providers/chat_provider.dart';
import '../../services/firestore_service.dart';

class MenuItemFormScreen extends ConsumerStatefulWidget {
  const MenuItemFormScreen({super.key, required this.restaurantId, this.existingItem});

  final String restaurantId;
  final MenuItem? existingItem;

  bool get isEditing => existingItem != null;

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _prepTimeController;
  late bool _available;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingItem?.itemName ?? '');
    _priceController = TextEditingController(
      text: widget.existingItem?.price.toStringAsFixed(2) ?? '',
    );
    _prepTimeController = TextEditingController(
      text: widget.existingItem?.prepTime.toString() ?? '15',
    );
    _available = widget.existingItem?.available ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(firestoreServiceProvider);
      final price = double.parse(_priceController.text.trim());
      final prepTime = int.parse(_prepTimeController.text.trim());

      if (widget.isEditing) {
        await service.updateMenuItem(widget.restaurantId, widget.existingItem!.id, {
          'item_name': _nameController.text.trim(),
          'price': price,
          'prep_time': prepTime,
          'available': _available,
        });
      } else {
        final item = MenuItem(
          id: '',
          restaurantId: widget.restaurantId,
          itemName: _nameController.text.trim(),
          price: price,
          prepTime: prepTime,
          available: _available,
        );
        await service.addMenuItem(widget.restaurantId, item);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Menu Item' : 'Add Menu Item'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Price is required';
                      final price = double.tryParse(v.trim());
                      if (price == null || price <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep Time (minutes)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                      helperText: 'How long does it take to prepare this item?',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Prep time is required';
                      final time = int.tryParse(v.trim());
                      if (time == null || time <= 0) return 'Enter a valid time in minutes';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Available'),
                    subtitle: Text(_available ? 'Item is shown to students' : 'Item is hidden'),
                    value: _available,
                    onChanged: (v) => setState(() => _available = v),
                    secondary: Icon(
                      _available ? Icons.visibility : Icons.visibility_off,
                      color: _available ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(widget.isEditing ? Icons.save : Icons.add),
                          label: Text(widget.isEditing ? 'Save Changes' : 'Add Item'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
