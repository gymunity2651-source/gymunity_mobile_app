import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../store/domain/entities/product_entity.dart';
import '../../../store/presentation/providers/store_providers.dart';
import '../../../store/presentation/widgets/store_product_image.dart';
import '../providers/seller_providers.dart';

class SellerProductEditorScreen extends ConsumerStatefulWidget {
  const SellerProductEditorScreen({super.key, this.product});

  final ProductEntity? product;

  @override
  ConsumerState<SellerProductEditorScreen> createState() =>
      _SellerProductEditorScreenState();
}

class _SellerProductEditorScreenState
    extends ConsumerState<SellerProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockController;
  bool _isActive = true;
  bool _saving = false;
  final List<XFile> _pendingImages = <XFile>[];

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _titleController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _categoryController = TextEditingController(text: product?.category ?? '');
    _priceController = TextEditingController(
      text: product != null ? product.price.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(
      text: product?.stockQty.toString() ?? '0',
    );
    _lowStockController = TextEditingController(
      text: product?.lowStockThreshold.toString() ?? '5',
    );
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEditing ? 'Edit Product' : 'Add Product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Text(
                'Images',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if ((widget.product?.imageUrls ?? const <String>[]).isNotEmpty)
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) => StoreProductImage(
                      product: ProductEntity(
                        id: widget.product!.id,
                        sellerId: widget.product!.sellerId,
                        name: widget.product!.name,
                        description: widget.product!.description,
                        category: widget.product!.category,
                        price: widget.product!.price,
                        currency: widget.product!.currency,
                        stockQty: widget.product!.stockQty,
                        imagePaths: widget.product!.imagePaths,
                        imageUrls: <String>[widget.product!.imageUrls[index]],
                        lowStockThreshold: widget.product!.lowStockThreshold,
                        isActive: widget.product!.isActive,
                        deletedAt: widget.product!.deletedAt,
                      ),
                      width: 88,
                      height: 88,
                    ),
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemCount: widget.product!.imageUrls.length,
                  ),
                ),
              if (_pendingImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pendingImages
                      .map(
                        (file) => Chip(
                          label: Text(file.name),
                          onDeleted: () {
                            setState(() => _pendingImages.remove(file));
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add Images'),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _titleController,
                label: 'Title',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 4,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Description is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _categoryController,
                label: 'Category',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Category is required.'
                    : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _priceController,
                label: 'Price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid price.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Stock Qty',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Invalid stock.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lowStockController,
                      label: 'Low Stock',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'Invalid threshold.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isActive,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _isActive = value);
                      },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Visible in store catalog',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Create Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) {
        return;
      }
      setState(() => _pendingImages.addAll(files));
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        'Unable to access your image library right now.',
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(sellerRepositoryProvider);
      final existingPaths = List<String>.from(
        widget.product?.imagePaths ?? const [],
      );
      var product = await repo.saveProduct(
        productId: widget.product?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        price: double.parse(_priceController.text.trim()),
        stockQty: int.parse(_stockController.text.trim()),
        lowStockThreshold: int.parse(_lowStockController.text.trim()),
        imagePaths: existingPaths,
        isActive: _isActive,
      );

      if (_pendingImages.isNotEmpty) {
        final uploadedPaths = List<String>.from(existingPaths);
        for (final file in _pendingImages) {
          final bytes = await file.readAsBytes();
          final extension = file.name.contains('.')
              ? file.name.split('.').last
              : 'jpg';
          final path = await repo.uploadProductImage(
            productId: product.id,
            bytes: bytes,
            extension: extension,
          );
          uploadedPaths.add(path);
        }

        product = await repo.saveProduct(
          productId: product.id,
          title: _titleController.text,
          description: _descriptionController.text,
          category: _categoryController.text,
          price: double.parse(_priceController.text.trim()),
          stockQty: int.parse(_stockController.text.trim()),
          lowStockThreshold: int.parse(_lowStockController.text.trim()),
          imagePaths: uploadedPaths,
          isActive: _isActive,
        );
      }

      ref.invalidate(sellerProductsProvider);
      ref.invalidate(storeProductsProvider);
      ref.invalidate(sellerDashboardSummaryProvider);

      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        '${product.name} was ${widget.product == null ? 'created' : 'updated'}.',
      );
      Navigator.pop(context, product);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppFeedback(context, 'Unable to save the product right now.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
