import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../domain/entities/cart_entity.dart';
import '../../domain/entities/shipping_address_entity.dart';
import '../providers/store_providers.dart';
import '../store_ui_utils.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _selectedAddressId;
  bool _placingOrder = false;

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(storeCartControllerProvider);
    final addressesAsync = ref.watch(shippingAddressesProvider);
    final defaultAddress = ref.watch(defaultShippingAddressProvider);
    final selectedAddressId = _selectedAddressId ?? defaultAddress?.id;
    final hasInvalidCartItems = ref.watch(storeHasInvalidCartItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(storeCartControllerProvider);
          ref.invalidate(shippingAddressesProvider);
          await ref.read(shippingAddressesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.screenPadding),
          children: [
            cartAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _CheckoutMessage(
                message: describeStoreError(
                  error,
                  fallbackMessage:
                      'GymUnity could not load your checkout cart right now.',
                ),
              ),
              data: (cart) {
                if (cart.isEmpty) {
                  return const _CheckoutMessage(
                    message:
                        'Your cart is empty. Add products before opening checkout.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      title: 'Shipping Address',
                      actionLabel: 'Add',
                      onAction: _placingOrder ? null : _openNewAddressSheet,
                    ),
                    const SizedBox(height: 12),
                    addressesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => _CheckoutMessage(
                        message: describeStoreError(
                          error,
                          fallbackMessage:
                              'GymUnity could not load your saved shipping addresses right now.',
                        ),
                      ),
                      data: (addresses) {
                        if (addresses.isEmpty) {
                          return _CheckoutMessage(
                            message:
                                'No shipping address is saved yet. Add an address to continue.',
                            actionLabel: 'Add Address',
                            onAction: _openNewAddressSheet,
                          );
                        }

                        return Column(
                          children: addresses
                              .map(
                                (address) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AddressCard(
                                    address: address,
                                    selected: selectedAddressId == address.id,
                                    onSelect: () {
                                      setState(
                                        () => _selectedAddressId = address.id,
                                      );
                                    },
                                    onEdit: () =>
                                        _openEditAddressSheet(address),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'Payment'),
                    const SizedBox(height: 12),
                    const _InfoCard(
                      title: 'Manual Payment Confirmation',
                      body:
                          'GymUnity does not process card payments in-app yet. Your order will be created as pending, then marked paid only after manual confirmation. No fake payment success is shown.',
                    ),
                    if (hasInvalidCartItems) ...[
                      const SizedBox(height: 16),
                      const _InfoCard(
                        title: 'Cart Needs Attention',
                        body:
                            'One or more cart items are unavailable or exceed current stock. Fix the cart before placing the order.',
                        error: true,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _SectionTitle(title: 'Order Summary'),
                    const SizedBox(height: 12),
                    _OrderSummaryCard(cart: cart),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(
        context,
        cartAsync.valueOrNull,
        selectedAddressId,
        hasInvalidCartItems,
      ),
    );
  }

  Widget? _buildBottomBar(
    BuildContext context,
    CartEntity? cart,
    String? selectedAddressId,
    bool hasInvalidCartItems,
  ) {
    if (cart == null || cart.isEmpty) {
      return null;
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        8,
        AppSizes.screenPadding,
        16,
      ),
      child: ElevatedButton(
        onPressed: _placingOrder || hasInvalidCartItems
            ? null
            : () => _placeOrder(selectedAddressId),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
        ),
        child: _placingOrder
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                selectedAddressId == null
                    ? 'Select a shipping address'
                    : 'Place Order',
              ),
      ),
    );
  }

  Future<void> _openNewAddressSheet() async {
    final saved = await showModalBottomSheet<ShippingAddressEntity>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _AddressEditorSheet(),
    );
    if (saved == null || !mounted) {
      return;
    }
    setState(() => _selectedAddressId = saved.id);
  }

  Future<void> _openEditAddressSheet(ShippingAddressEntity address) async {
    final saved = await showModalBottomSheet<ShippingAddressEntity>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddressEditorSheet(initialAddress: address),
    );
    if (saved == null || !mounted) {
      return;
    }
    setState(() => _selectedAddressId = saved.id);
  }

  Future<void> _placeOrder(String? selectedAddressId) async {
    if (selectedAddressId == null) {
      showAppFeedback(context, 'Select a shipping address before checkout.');
      return;
    }

    setState(() => _placingOrder = true);
    try {
      await ref
          .read(storeRepositoryProvider)
          .placeOrderFromCart(
            addressId: selectedAddressId,
            idempotencyKey:
                '${DateTime.now().toUtc().microsecondsSinceEpoch}-$selectedAddressId',
          );
      ref.invalidate(storeCartControllerProvider);
      ref.invalidate(myOrdersProvider);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Submitted'),
          content: const Text(
            'Your order was created successfully and is now pending manual payment confirmation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.orders,
        (route) => route.settings.name == AppRoutes.memberHome,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        describeStoreError(
          error,
          fallbackMessage: 'Unable to place your order right now.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _placingOrder = false);
      }
    }
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  final ShippingAddressEntity address;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off_outlined,
                color: selected ? AppColors.orange : AppColors.textMuted,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.recipientName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (address.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.phone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.summaryLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.cart});

  final CartEntity cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} x ${item.product.name}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${item.product.currency} ${item.lineTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: AppColors.border),
          ),
          Row(
            children: [
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                cart.subtotal.toStringAsFixed(2),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    this.error = false,
  });

  final String title;
  final String body;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final accent = error ? AppColors.error : AppColors.orange;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutMessage extends StatelessWidget {
  const _CheckoutMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AddressEditorSheet extends ConsumerStatefulWidget {
  const _AddressEditorSheet({this.initialAddress});

  final ShippingAddressEntity? initialAddress;

  @override
  ConsumerState<_AddressEditorSheet> createState() =>
      _AddressEditorSheetState();
}

class _AddressEditorSheetState extends ConsumerState<_AddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _recipientController;
  late final TextEditingController _phoneController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalController;
  late final TextEditingController _countryController;
  late final TextEditingController _notesController;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress;
    _recipientController = TextEditingController(
      text: initial?.recipientName ?? '',
    );
    _phoneController = TextEditingController(text: initial?.phone ?? '');
    _line1Controller = TextEditingController(text: initial?.line1 ?? '');
    _line2Controller = TextEditingController(text: initial?.line2 ?? '');
    _cityController = TextEditingController(text: initial?.city ?? '');
    _stateController = TextEditingController(text: initial?.stateRegion ?? '');
    _postalController = TextEditingController(text: initial?.postalCode ?? '');
    _countryController = TextEditingController(
      text: initial?.countryCode ?? 'US',
    );
    _notesController = TextEditingController(
      text: initial?.deliveryNotes ?? '',
    );
    _isDefault = initial?.isDefault ?? false;
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.screenPadding,
        right: AppSizes.screenPadding,
        top: AppSizes.screenPadding,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppSizes.screenPadding,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.initialAddress == null ? 'Add Address' : 'Edit Address',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _addressField(_recipientController, 'Recipient Name'),
            const SizedBox(height: 12),
            _addressField(
              _phoneController,
              'Phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _addressField(_line1Controller, 'Address Line 1'),
            const SizedBox(height: 12),
            _addressField(
              _line2Controller,
              'Address Line 2 (optional)',
              requiredField: false,
            ),
            const SizedBox(height: 12),
            _addressField(_cityController, 'City'),
            const SizedBox(height: 12),
            _addressField(_stateController, 'State / Region'),
            const SizedBox(height: 12),
            _addressField(_postalController, 'Postal Code'),
            const SizedBox(height: 12),
            _addressField(_countryController, 'Country Code'),
            const SizedBox(height: 12),
            _addressField(
              _notesController,
              'Delivery Notes (optional)',
              requiredField: false,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isDefault,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => _isDefault = value),
              title: const Text('Use as default address'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _save,
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
                  : const Text('Save Address'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addressField(
    TextEditingController controller,
    String label, {
    bool requiredField = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: (value) {
        if (!requiredField) {
          return null;
        }
        if ((value ?? '').trim().isEmpty) {
          return '$label is required.';
        }
        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(shippingAddressesProvider.notifier)
          .save(
            ShippingAddressEntity(
              id: widget.initialAddress?.id ?? '',
              userId: widget.initialAddress?.userId ?? '',
              recipientName: _recipientController.text,
              phone: _phoneController.text,
              line1: _line1Controller.text,
              line2: _line2Controller.text.trim().isEmpty
                  ? null
                  : _line2Controller.text,
              city: _cityController.text,
              stateRegion: _stateController.text,
              postalCode: _postalController.text,
              countryCode: _countryController.text,
              deliveryNotes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text,
              isDefault: _isDefault,
            ),
          );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppFeedback(
        context,
        describeStoreError(
          error,
          fallbackMessage: 'Unable to save the shipping address right now.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
