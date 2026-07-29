import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart.dart';
import '../../states/cart_provider.dart';
import '../../widgets/app_card.dart';
import '../cart/checkout_screen.dart';

// ---------------------------------------------------------------------------
// Local palette for this screen — blue (primary actions / info), green
// (money / success), orange (quantity stepper / accents). Kept local so we
// don't need to touch app_colors.dart or any other screen.
// ---------------------------------------------------------------------------
const Color _kBlue = Color(0xFF2563EB);
const Color _kBlueSoft = Color(0xFFEFF4FF);
const Color _kGreen = Color(0xFF16A34A);
const Color _kOrange = Color(0xFFF97316);
const Color _kOrangeSoft = Color(0xFFFFF1E6);

const LinearGradient _kCtaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_kOrange, _kOrange],
);

class CartScreen extends ConsumerWidget {
  static const String routeName = '/cart';

  final bool showBackButton;

  const CartScreen({super.key, this.showBackButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: showBackButton
          ? AppBar(
              title: const Text(
                'My Cart',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: _kBlue),
            )
          : null,
      body: SafeArea(
        child: cartAsync.when(
          data: (cart) {
            if (cart == null || cart.items.isEmpty) {
              return _EmptyCart(showBackButton: showBackButton);
            }

            final validItems = cart.validItems;
            final invalidItems = cart.invalidItems;

            final total = cart.totalPrice;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                if (!showBackButton) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 26,
                        decoration: BoxDecoration(
                          gradient: _kCtaGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'My Cart',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (validItems.isNotEmpty) ...[
                  ...validItems.map((item) => Padding(
                        key: ValueKey(item.cartItemId),
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CartItemRow(item: item),
                      )),
                  const SizedBox(height: 6),
                ],
                if (invalidItems.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Unavailable Items',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                  ...invalidItems.map((item) => Padding(
                        key: ValueKey(item.cartItemId),
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CartItemRow(item: item, isInvalid: true),
                      )),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 2),
                _SummaryCard(totalItems: cart.totalItems, total: total),
                const SizedBox(height: 20),
                _GradientButton(
                  label: 'Checkout',
                  gradient: _kCtaGradient,
                  onPressed: validItems.isNotEmpty
                      ? () =>
                          Navigator.pushNamed(context, CheckoutScreen.routeName)
                      : null,
                ),
              ],
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kBlue)),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text('Failed to load cart',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(err.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.subText)),
                  const SizedBox(height: 24),
                  _GradientButton(
                    label: 'Retry',
                    gradient: _kCtaGradient,
                    onPressed: () =>
                        ref.read(cartProvider.notifier).refreshCart(),
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

// ---------------------------------------------------------------------------
// Reusable gradient CTA button (replaces AppButton for this screen so we can
// control the blue → green gradient directly).
// ---------------------------------------------------------------------------
class _GradientButton extends StatelessWidget {
  final String label;
  final Gradient gradient;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: disabled ? null : gradient,
            color: disabled ? const Color(0xFFE0E0E0) : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: disabled ? const Color(0xFF9E9E9E) : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order summary card
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final int totalItems;
  final int total;

  const _SummaryCard({required this.totalItems, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Order Summary',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Items',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.subText),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kBlueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  totalItems.toString(),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: _kBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF171717),
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.vnd(total),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _kOrange,
                ),
              ),
            ],
          ),
        ],
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

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    final apiRoot = Uri.parse(ApiClient.baseUrl);
    final origin = '${apiRoot.scheme}://${apiRoot.authority}';
    final normalizedPath = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
    return '$origin$normalizedPath';
  }

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
        backgroundColor: _kOrange,
      ));
      return;
    }

    if (widget.item.maxServing != null &&
        widget.item.maxServing! > 0 &&
        newQuantity > widget.item.maxServing!) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('You can only buy up to ${widget.item.maxServing} portions'),
        backgroundColor: _kOrange,
      ));
      return;
    }

    if (newQuantity == 0) {
      _debounceTimer?.cancel();
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmDialog(
          title: 'Remove Item',
          message: 'Are you sure you want to remove this item from your cart?',
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
        await ref
            .read(cartProvider.notifier)
            .removeItem(widget.item.cartItemId);
      } catch (e) {
        if (mounted) {
          setState(() {
            _localQuantity = widget.item.quantity;
          });
        }
        final errorMessage = e is ApiException
            ? e.message
            : e.toString().replaceAll('Exception: ', '');
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
        await ref
            .read(cartProvider.notifier)
            .updateItemQuantity(widget.item.cartItemId, _localQuantity);
      } catch (e) {
        if (mounted) {
          // Revert optimistic update on failure
          setState(() {
            _localQuantity = widget.item.quantity;
          });
          final errorMessage = e is ApiException
              ? e.message
              : e.toString().replaceAll('Exception: ', '');
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
          title: const Text('Enter Quantity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            cursorColor: _kBlue,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                borderSide: const BorderSide(color: _kBlue, width: 1.5),
              ),
              labelText: 'Quantity',
              labelStyle: const TextStyle(color: _kBlue),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.subText)),
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
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
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
    final imageUrl = food?.imageUrl;

    return Dismissible(
      key: ValueKey('dismiss_${item.cartItemId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
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
          builder: (context) => _ConfirmDialog(
            title: 'Remove Item',
            message:
                'Are you sure you want to remove this item from your cart?',
          ),
        );
      },
      onDismissed: (direction) {
        final messenger = ScaffoldMessenger.of(context);
        ref
            .read(cartProvider.notifier)
            .removeItem(item.cartItemId)
            .catchError((e) {
          final errorMessage = e is ApiException
              ? e.message
              : e.toString().replaceAll('Exception: ', '');
          messenger.showSnackBar(SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ));
        });
      },
      child: AppCard(
        onTap: food != null
            ? () =>
                Navigator.pushNamed(context, '/food-detail', arguments: food)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _resolveImageUrl(imageUrl) ?? imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.fastfood, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isInvalid ? Colors.grey : const Color(0xFF1A1A1A),
                      decoration: isInvalid ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isInvalid && item.reason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.reason!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (!isInvalid)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            CurrencyFormatter.vnd(item.subtotal),
                            style: const TextStyle(
                                color: _kOrange,
                                fontSize: 16,
                                fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: _kOrangeSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () =>
                                    _updateQuantity(_localQuantity - 1),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(12)),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  child: Icon(Icons.remove,
                                      size: 18, color: _kOrange),
                                ),
                              ),
                              InkWell(
                                onTap: _showQuantityDialog,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 30),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 7),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: _kOrange),
                                        )
                                      : Text(
                                          '$_localQuantity',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Color(0xFF7C2D12)),
                                        ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    _updateQuantity(_localQuantity + 1),
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(12)),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  child: Icon(Icons.add,
                                      size: 18, color: _kOrange),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.vnd(item.subtotal),
                          style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.lineThrough),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 24),
                          onPressed: () => _updateQuantity(0),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared confirm dialog used for both the quantity-to-zero and swipe-to-
// delete flows, styled with the blue accent.
// ---------------------------------------------------------------------------
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const _ConfirmDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No',
              style: TextStyle(
                  color: AppColors.subText, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
        ),
      ],
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
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: _kCtaGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kBlue.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 60, color: Colors.white),
            ),
            const SizedBox(height: 22),
            const Text('Your cart is empty',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              'Browse today menu and add your favorite meals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subText),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: _GradientButton(
                label: 'Browse Menu',
                gradient: _kCtaGradient,
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
            ),
          ],
        ),
      ),
    );
  }
}
