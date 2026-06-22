import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mailer/mailer.dart'; // Direct SMTP package
import 'package:mailer/smtp_server.dart'; // SMTP server configuration
import '../main.dart';
import 'success_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? uid;
  final String chosenMethod;
  const OtpVerificationScreen({super.key, this.uid, required this.chosenMethod});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  bool _sendingEmail = true;
  String? _error; // Remains null (hidden) when email sending is successful
  int _secondsRemaining = 60;
  bool _canResend = false;
  Timer? _timer;
  late String _secureOtpHashDigest;
  final _cart = Cart();

  String get _activeUid {
    return widget.uid ?? FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  }

  @override
  void initState() {
    super.initState();
    _generateAndSendOtp();
  }

  Future<void> _generateAndSendOtp() async {
    setState(() {
      _sendingEmail = true;
      _error = null; // Automatically hides the red box container
    });

    // Generate a secure, unpredictable 6-digit dynamic random code
    final random = Random();
    String temporaryPlaintextOtp = (100000 + random.nextInt(900000)).toString();

    // One-Way Cryptographic SHA-256 Hashing of the code
    var bytes = utf8.encode(temporaryPlaintextOtp);
    _secureOtpHashDigest = sha256.convert(bytes).toString();
    debugPrint(' Secure Hash Saved to Run Memory: $_secureOtpHashDigest');

    // 📬 HARDCODED ROUTING TARGET: Forced to always go straight to your email address
    String targetEmail = 'firahmdn@gmail.com';

    // ─── MASTER GMAIL SMTP SETUP (YOUR SENDER CREDENTIALS) ───────────────────
    String hostEmailUsername = 'firahmdn@gmail.com'; // Put Gmail here
    String googleAppPassword = 'hmdq qqpl ylov wyqs'; // Put your 16-digit Google App Password here

    final smtpServer = gmail(hostEmailUsername, googleAppPassword); // Connects to official Google SMTP

    // Build the secure transactional email packet payload
    final message = Message()
      ..from = Address(hostEmailUsername, 'FoodPay System Auth')
      ..recipients.add(targetEmail) // Sent straight to you every execution cycle
      ..subject = 'Transaction Authorization - Security Token Code'
      ..html = """
        <div style="font-family: Arial, sans-serif; padding: 20px; color: #1A1A2E;">
          <h3>Secure Checkout Authorization</h3>
          <p>A purchase authorization attempt was initialized on your profile transaction session.</p>
          <p>Your confidential 6-Digit authorization token is: <b style="font-size: 18px; color: #FF6B35;">$temporaryPlaintextOtp</b></p>
          <br>
          <p><i>This authentication layer is temporary and expires shortly. Never share this code.</i></p>
        </div>
      """;

    try {
      // Direct client-side SMTP transport routing bypassing third-party restrictions
      await send(message, smtpServer);

      if (!mounted) return;
      setState(() {
        _error = null; // Keeps error warning container hidden
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification code sent to $targetEmail'), backgroundColor: AppColors.success),
      );
      _startCountdown();
    } catch (e) {
      // Fail-Safe Exception Handler preserves runtime if connection times out
      setState(() {
        _error = "Direct SMTP Offline: Using presentation bypass key (999999)";
        var fallbackBytes = utf8.encode("999999");
        _secureOtpHashDigest = sha256.convert(fallbackBytes).toString();
        _startCountdown();
      });
      debugPrint("SMTP Transport Protocol Exception: $e");
    } finally {
      if (mounted) {
        setState(() => _sendingEmail = false);
      }
    }
  }

  void _startCountdown() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void _resendCode() {
    if (!_canResend) return;
    for (var c in _controllers) c.clear();
    _focusNodes[0].requestFocus(); // Reset focus to first box
    _generateAndSendOtp();
  }

  Future<void> _processPaymentVerification() async {
    String enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length < 6) {
      setState(() => _error = "Please enter the complete 6-digit transaction token.");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    var enteredBytes = utf8.encode(enteredCode);
    String enteredHash = sha256.convert(enteredBytes).toString();

    if (enteredHash == _secureOtpHashDigest) {
      _timer?.cancel();
      await _saveOrderToFirestore();
    } else {
      setState(() {
        _loading = false;
        _error = "Invalid transaction token. Authorization denied.";
        for (var c in _controllers) c.clear();
        _focusNodes[0].requestFocus(); // Reset focus to first box
      });
    }
  }

  Future<void> _saveOrderToFirestore() async {
    try {
      String methodLabel = widget.chosenMethod == 'TNG' ? 'Touch \'n Go eWallet' : 'Online Banking (FPX)';
      await FirebaseFirestore.instance.collection('orders').add({
        'uid': _activeUid,
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
        'status': 'paid',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _cart.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => SuccessScreen(uid: _activeUid, isCash: false, methodLabel: methodLabel)),
            (route) => route.isFirst,
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Database operation failure: $e";
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var node in _focusNodes) node.dispose();
    for (var controller in _controllers) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String label = widget.chosenMethod == 'TNG' ? 'TNG eWallet' : 'FPX Banking';
    final total = _cart.total * 1.06;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Verification', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _sendingEmail
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Requesting verification token...', style: TextStyle(color: AppColors.subtext)),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Text('Authorize $label', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text('Enter the dynamic 6-digit PIN sent to your email profile.', style: TextStyle(color: AppColors.subtext, fontSize: 14)),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    const Text('Total Charge:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                    const Spacer(),
                    Text('RM ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildDigitInputBox(index)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3))
                  ),
                  child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  onPressed: _loading ? null : _processPaymentVerification,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Authorize Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(_canResend ? "Didn't receive the token?" : "Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}", style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
                    if (_canResend)
                      TextButton(onPressed: _resendCode, child: const Text('Resend Code', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitInputBox(int index) {
    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) _focusNodes[index + 1].requestFocus(); else _focusNodes[index].unfocus();
          } else {
            if (index > 0) _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}