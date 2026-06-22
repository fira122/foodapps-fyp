import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = Cart();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Your Cart',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  if (_cart.items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _cart.clear());
                      },
                      child: const Text('Clear all',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                ],
              ),
            ),

            // ── Cart list ──────────────────────────────────────────────────
            if (_cart.items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      const Text(
                        'Your cart is empty',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add some delicious items from the menu',
                        style: TextStyle(
                            color: AppColors.subtext, fontSize: 13.5),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Browse Menu',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  itemCount: _cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final item = _cart.items[i];
                    return _CartItemTile(
                      item: item,
                      onIncrement: () =>
                          setState(() => _cart.add(item.food)),
                      onDecrement: () =>
                          setState(() => _cart.decrement(item.food.id)),
                    );
                  },
                ),
              ),

            // ── Order summary + checkout ───────────────────────────────────
            if (_cart.items.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 20,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _summaryRow('Subtotal',
                        'RM ${_cart.total.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    _summaryRow('Service tax (6%)',
                        'RM ${(_cart.total * 0.06).toStringAsFixed(2)}'),
                    const Divider(height: 20),
                    _summaryRow(
                      'Total',
                      'RM ${(_cart.total * 1.06).toStringAsFixed(2)}',
                      bold: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentScreen(
                                uid: FirebaseAuth.instance.currentUser?.uid,
                              ),
                            ),
                          );
                        },


                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Proceed to Payment',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Insert OTP to confirm payment',
                      style:
                      TextStyle(color: AppColors.subtext, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
              color: bold ? AppColors.text : AppColors.subtext,
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              color: bold ? AppColors.primary : AppColors.text,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            )),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: item.food.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: Text(item.food.emoji,
                    style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'RM ${(item.food.price * item.qty).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _qtyBtn(Icons.remove_rounded, onDecrement),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.qty}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.text),
                ),
              ),
              _qtyBtn(Icons.add_rounded, onIncrement),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppColors.text),
      ),
    );
  }
}