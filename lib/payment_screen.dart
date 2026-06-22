import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'otp_screen.dart'; // Routes directly to our corrected standalone OTP screen
import 'success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String? uid;
  const PaymentScreen({super.key, this.uid});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedMethod;
  bool _loading = false;
  final _cart = Cart();

  String? get _activeUid {
    return widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _handleMethodSelection(String methodKey) async {
    if (methodKey == 'COUNTER') {
      setState(() => _loading = true);
      await _saveOrderToFirestore('Cash On Delivery', isCashPayment: true);
    } else {
      setState(() => _selectedMethod = methodKey);
      // Fixed: Routes cleanly to the independent OTP verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
              uid: _activeUid,
              chosenMethod: methodKey
          ),
        ),
      );
    }
  }

  Future<void> _saveOrderToFirestore(String methodLabel, {required bool isCashPayment}) async {
    try {
      final uid = _activeUid;
      await FirebaseFirestore.instance.collection('orders').add({
        'uid': uid ?? 'guest',
        'items': _cart.items.map((e) {
          return {
            'name': e.food.name,
            'emoji': e.food.emoji,
            'qty': e.qty,
            'price': e.food.price,
          };
        }).toList(),
        'subtotal': _cart.total,
        'tax': _cart.total * 0.06,
        'total': _cart.total * 1.06,
        'paymentMethod': methodLabel,
        'status': isCashPayment ? 'unpaid_cod' : 'paid',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _cart.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => SuccessScreen(
                uid: uid,
                isCash: isCashPayment,
                methodLabel: methodLabel
            )
        ),
            (route) => route.isFirst,
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Database error: $e"), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Method',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _buildSelectionLayout(),
      ),
    );
  }

  Widget _buildSelectionLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose one payment option to continue', style: TextStyle(fontSize: 14, color: AppColors.subtext)),
          const SizedBox(height: 24),
          _methodTile(
            title: 'Cash On Delivery',
            subtitle: 'Pay when you food your arrived.',
            icon: Icons.storefront_rounded,
            badge: 'RECOMMENDED',
            onTap: () => _handleMethodSelection('COUNTER'),
          ),
          const SizedBox(height: 16),
          _methodTile(
            title: 'FPX Online Banking',
            subtitle: 'Simulate direct online payment using a selected simulation bank.',
            icon: Icons.account_balance_rounded,
            onTap: () => _handleMethodSelection('FPX'),
          ),
          const SizedBox(height: 16),
          _methodTile(
            title: 'Touch \'n Go eWallet',
            subtitle: 'Simulate eWallet checkout for a faster mobile-style payment flow.',
            icon: Icons.phone_android_rounded,
            onTap: () => _handleMethodSelection('TNG'),
          ),
          if (_loading) ...[
            const SizedBox(height: 30),
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ]
        ],
      ),
    );
  }

  Widget _methodTile({
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _loading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.subtext, height: 1.3)),
                  if (badge != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(badge, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ]
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.subtext),
          ],
        ),
      ),
    );
  }
}
