import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'menu_screen.dart';

class SuccessScreen extends StatefulWidget {
  final String? uid;
  final bool isCash;
  final String? methodLabel;

  const SuccessScreen({
    super.key,
    this.uid,
    this.isCash = false,
    this.methodLabel,
  });

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> with TickerProviderStateMixin {
  late AnimationController _checkCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _checkScale;
  late Animation<double> _checkFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;

  String get _activeUid {
    return widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));
    _checkFade = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeIn);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeIn);

    _checkCtrl.forward().then((_) => _contentCtrl.forward());
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String finalMethodText = widget.isCash ? '💵 Cash on Delivery' : (widget.methodLabel == 'TNG' ? '📱 Touch n Go (OTP Verified)' :'FPX'? '🏦 FPX Bank (OTP Verified)');
    String finalStatusText = widget.isCash ? '⏳ Processing' : '✅ Paid';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _checkFade,
                child: ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.success.withOpacity(.3), blurRadius: 30, offset: const Offset(0, 12))]),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    children: [
                      const Text('Order Confirmed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
                      const SizedBox(height: 10),
                      Text(widget.isCash ? 'Your COD request has been recorded.\nPlease prepare exact change!' : 'Your order has been placed.\nWe\'ll prepare it right away!', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtext, fontSize: 15, height: 1.6)),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 20, offset: const Offset(0, 8))]),
                        child: Column(
                          children: [
                            _detailRow('Payment Method', finalMethodText),
                            const Divider(height: 20),
                            _detailRow('Status', finalStatusText),
                            const Divider(height: 20),
                            _detailRow('Provider', widget.isCash ? 'Local Logistics' : 'Fiuu Gateway (Demo)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MenuScreen(uid: _activeUid)), (_) => false);
                          },
                          child: const Text('Back to Menu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => MenuScreen(uid: _activeUid)), (_) => false);
                        },
                        child: const Text('View Order History', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.subtext, fontSize: 13.5)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 13.5)),
      ],
    );
  }
}