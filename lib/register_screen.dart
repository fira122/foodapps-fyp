import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart';
import '../menu_screen.dart';
import 'face_auth_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _showPasswordChecklist = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _showPasswordChecklist = _passwordCtrl.text.isNotEmpty;
        });
      }
    });
  }

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }

    final password = _passwordCtrl.text;
    final owaspRegex = RegExp(r"^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@#$!%*?&.'])[A-Za-z\d@#$!%*?&.]{8,}$");

    if (!owaspRegex.hasMatch(password)) {
      setState(() => _error =
      'Password does not meet complexity rules:\n'
          '• Must be at least 8 characters long\n'
          '• Include at least one uppercase letter (A-Z)\n'
          '• Include at least one lowercase letter (a-z)\n'
          '• Include at least one number (0-9)\n'
          '• Include at least one special character (@, #, \$, %, *, !, ., ?, \')'
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    User? createdUser;

    try {
      // 1. Initial Auth Account Instance Provisioning
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: password,
      );
      createdUser = cred.user;

      // 2. Initial Firestore Database Stub Provisioning
      await FirebaseFirestore.instance
          .collection('users')
          .doc(createdUser!.uid)
          .set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'faceEnrolled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // 3. Open Face Authenticator screen
      final enrollmentResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FaceAuthScreen(
            mode: FaceAuthMode.enroll,
            userId: createdUser!.uid,
          ),
        ),
      );

      if (!mounted) return;

      // 4. Verification Check and Rollback Safeguard Engine
      if (enrollmentResult == true) {
        // SUCCESS PATH: Clean history stack and jump straight into Menu Dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MenuScreen(uid: createdUser!.uid)),
              (route) => false,
        );
      } else {
        // FALLBACK BLOCK: Face processing failed, dropped, or was canceled
        setState(() => _error = 'Face enrollment is mandatory to create an account.');
        await _executeRollback(createdUser);
      }

    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e.code));
    } catch (e) {
      if (createdUser != null) {
        await _executeRollback(createdUser);
      }
      setState(() => _error = 'Registration Interrupted: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // Extracted Helper Method for Clean Database Rollback Operations
  Future<void> _executeRollback(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Rollback execution vector failed: $e");
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'The password provided is too weak.';
      default:
        return 'Registration failed. Try again.';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join FoodPay and start ordering',
                style: TextStyle(color: AppColors.subtext, fontSize: 14),
              ),
              const SizedBox(height: 36),

              _inputField(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _inputField(_emailCtrl, 'Email address', Icons.mail_outline_rounded),
              const SizedBox(height: 14),

              _inputField(
                _passwordCtrl,
                'Password',
                Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.subtext,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              if (_showPasswordChecklist) ...[
                const SizedBox(height: 16),
                PasswordComplexityChecklist(password: _passwordCtrl.text),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        bool obscure = false,
        Widget? suffix,
      }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtext),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: AppColors.subtext, size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PasswordComplexityChecklist extends StatelessWidget {
  final String password;
  const PasswordComplexityChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r"[@,#,$,%,*,!,.,?,&']"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _checkRow("Must be at least 8 characters long", hasLength),
        _checkRow("Include at least one uppercase letter (A-Z)", hasUpper),
        _checkRow("Include at least one lowercase letter (a-z)", hasLower),
        _checkRow("Include at least one number (0-9)", hasDigit),
        _checkRow("Include at least one special character (@, #, \$, %, *, !, ., ?, ')", hasSpecial),
      ],
    );
  }

  Widget _checkRow(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isValid ? Colors.green : AppColors.subtext,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isValid ? Colors.green : AppColors.subtext, fontSize: 12)),
        ],
      ),
    );
  }
}