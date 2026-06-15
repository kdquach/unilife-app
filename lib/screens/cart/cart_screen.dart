import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart.dart';
import '../../states/cart_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../cart/checkout_data_note_screen.dart';

class CartScreen extends ConsumerWidget {
  static const String routeName = '/cart';

  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      appBar: showBackButton ? AppBar(title: const Text('My Cart')) : null,
      body: SafeArea(
        child: cartAsync.when(
          data: (cart) {
            if (cart == null || cart.items.isEmpty) return _EmptyCart(showBackButton: showBackButton);
            
            final validItems = cart.validItems;
            final invalidItems = cart.invalidItems;
            
            final total = cart.totalPrice;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!showBackButton) const Text('My Cart', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                if (!showBackButton) const SizedBox(height: 4),
                const Text('Review your selected items', style: TextStyle(color: AppColors.subText)),
                const SizedBox(height: 20),
                
                if (validItems.isNotEmpty) ...[
                  ...validItems.map((item) => Padding(key: ValueKey(item.cartItemId), padding: const EdgeInsets.only(bottom: 14), child: _CartItemRow(item: item))),
                  const SizedBox(height: 10),
                ],

                if (invalidItems.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Unavailable Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ),
                  ...invalidItems.map((item) => Padding(key: ValueKey(item.cartItemId), padding: const EdgeInsets.only(bottom: 14), child: _CartItemRow(item: item, isInvalid: true))),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Order summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 18),
                      _SummaryRow('Total Items', cart.totalItems),
                      const Divider(height: 28),
                      _SummaryRow('Total', total, large: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Checkout', 
                  onPressed: validItems.isNotEmpty ? () => Navigator.pushNamed(context, CheckoutDataNoteScreen.routeName) : null,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load cart', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subText)),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Retry',
                    onPressed: () => ref.read(cartProvider.notifier).refreshCart(),
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

class _CartItemRow extends ConsumerStatefulWidget {
  final CartItemDto item;
  final bool isInvalid;

  const _CartItemRow({required this.item, this.isInvalid = false});

  @override
  ConsumerState<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends ConsumerState<_CartItemRow> {
  bool _isLoading = false;
  Timer? _debounceTimer;
  late int _localQuantity;

  @override
  void initState() {
    super.initState();
    _localQuantity = widget.item.quantity;
  }

  @override
  void didUpdateWidget(_CartItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _localQuantity = widget.item.quantity;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateQuantity(int newQuantity) async {
    if (newQuantity < 0) return;
    if (_isLoading) return; // Prevent updates while an API call is in-flight

    // Check stock limits before anything else
    final int? stock = widget.item.remainingCount ?? 
                       (widget.item.food?.isMenuFood == true 
                           ? widget.item.food?.remainingServings 
                           : widget.item.food?.stockQuantity);
                           
    if (stock != null && newQuantity > stock) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Quantity exceeds stock (max $stock)'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (widget.item.maxServing != null && newQuantity > widget.item.maxServing!) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('You can only buy up to ${widget.item.maxServing} portions'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (newQuantity == 0) {
      _debounceTimer?.cancel();
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Item'),
          content: const Text('Are you sure you want to remove this item from your cart?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldDelete != true) {
        if (_localQuantity != widget.item.quantity) {
          _updateQuantity(_localQuantity);
        }
        return;
      }
      
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(cartProvider.notifier).removeItem(widget.item.cartItemId);
      } catch (e) {
        if (mounted) {
          setState(() {
            _localQuantity = widget.item.quantity;
          });
        }
        final errorMessage = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
        messenger.showSnackBar(SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() {
      _localQuantity = newQuantity;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await ref.read(cartProvider.notifier).updateItemQuantity(widget.item.cartItemId, _localQuantity);
      } catch (e) {
        if (mounted) {
          // Revert optimistic update on failure
          setState(() {
            _localQuantity = widget.item.quantity;
          });
          final errorMessage = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _showQuantityDialog() async {
    final controller = TextEditingController(text: _localQuantity.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              labelText: 'Quantity',
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel', style: TextStyle(color: AppColors.subText))
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                final val = int.tryParse(text);
                if (val == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter a valid number'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                Navigator.pop(context, val);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      }
    );
    if (result != null) {
      _updateQuantity(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isInvalid = widget.isInvalid;
    final food = item.food;
    final String title = food?.name ?? 'Unknown Item';
    final String type = (food?.isMenuFood ?? false) ? 'Menu Food' : 'Always Available';
    
    return Dismissible(
      key: ValueKey('dismiss_${item.cartItemId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8), // Assuming AppCard has some margin implicitly, wait, AppCard itself doesn't have margin in cart_screen, the list view provides spacing via separatorBuilder. We just need matching border radius.
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Item', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to remove this item from your cart?'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No', style: TextStyle(color: AppColors.subText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        final messenger = ScaffoldMessenger.of(context);
        ref.read(cartProvider.notifier).removeItem(item.cartItemId).catchError((e) {
          final errorMessage = e is ApiException ? e.message : e.toString().replaceAll('Exception: ', '');
          messenger.showSnackBar(SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ));
        });
      },
      child: AppCard(
      onTap: food != null ? () => Navigator.pushNamed(context, '/food-detail', arguments: food) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (food?.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                food!.imageUrl!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fastfood, color: Colors.grey)),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isInvalid ? Colors.grey : AppColors.text, decoration: isInvalid ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 4),
                if (isInvalid && item.reason != null)
                  Text(item.reason!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500))
                else
                  Text(type, style: const TextStyle(color: AppColors.subText, fontSize: 13)),
                  
                const SizedBox(height: 12),
                
                if (!isInvalid) Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        CurrencyFormatter.vnd(item.subtotal), 
                        style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => _updateQuantity(_localQuantity - 1),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.remove, size: 18, color: AppColors.subText)),
                          ),
                          InkWell(
                            onTap: _showQuantityDialog,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 30),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: _isLoading 
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text('$_localQuantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          InkWell(
                            onTap: () => _updateQuantity(_localQuantity + 1),
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(Icons.add, size: 18, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ) else Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(CurrencyFormatter.vnd(item.subtotal), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, decoration: TextDecoration.lineThrough)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
                      onPressed: () => _updateQuantity(0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool large;

  const _SummaryRow(this.label, this.amount, {this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: large ? 17 : 14, fontWeight: large ? FontWeight.w900 : FontWeight.w400, color: large ? AppColors.text : AppColors.subText))),
          Text(large ? CurrencyFormatter.vnd(amount) : amount.toString(), style: TextStyle(fontSize: large ? 18 : 14, fontWeight: FontWeight.w900, color: large ? AppColors.primary : AppColors.text)),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final bool showBackButton;
  const _EmptyCart({required this.showBackButton});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 88, color: AppColors.primary),
            const SizedBox(height: 18),
            const Text('Your cart is empty', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Browse today menu and add your favorite meals.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.subText)),
            const SizedBox(height: 24),
            AppButton(
              label: 'Browse Menu', 
              onPressed: () {
                if (showBackButton) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/main', 
                    (route) => false,
                    arguments: {'tabIndex': 1},
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
