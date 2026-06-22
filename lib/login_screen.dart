import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../menu_screen.dart';
import 'register_screen.dart';
import 'face_auth_screen.dart';
import 'dart:async'; // Required for tracking the lockout timer thread

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // ── Lockout State Controls ────────────────────────────────────────────────
  int _failedAttempts = 0;              // Tracks wrong password interactions
  bool _isLockedOut = false;            // Security gate state flag
  int _secondsRemaining = 60;           // Duration of the lockout penalty
  Timer? _lockoutTimer;                 // Holds the active stream handle

  // ── Standard Fallback: Password Login ─────────────────────────────────────
  Future<void> _login() async {
    // Gatekeeper: Instantly block login processing if penalty is currently active
    if (_isLockedOut) {
      setState(() {
        _error = 'Too many attempts. Locked out for security. Try again in $_secondsRemaining seconds.';
      });
      return;
    }

    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      // Reset defensive failure counter tracking variables upon valid login
      _failedAttempts = 0;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MenuScreen(uid: cred.user!.uid),
        ),
      );
    } on FirebaseAuthException catch (e) {
      // Catch specific wrong credential exceptions to check brute-force counters
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() {
          _failedAttempts++;
        });

        if (_failedAttempts >= 3) {
          _startLockoutCountdown();
        } else {
          int remaining = 3 - _failedAttempts;
          setState(() {
            _error = 'Incorrect credentials. You have $remaining attempts left.';
          });
        }
      } else if (e.code == 'too-many-requests') {
        // Fallback catch if default Firebase backend triggers first
        setState(() => _error = 'Too many attempts. Backend security lockdown active.');
      } else {
        setState(() => _error = _friendlyError(e.code));
      }
    } catch (e) {
      setState(() => _error = 'Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ── Custom Lockout Engine ─────────────────────────────────────────────────
  void _startLockoutCountdown() {
    setState(() {
      _isLockedOut = true;
      _secondsRemaining = 60;
      _error = 'Security Lockout: Too many incorrect entries. Locked for 1 minute.';
    });

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
          _error = 'Too many attempts. Locked out for security. Try again in $_secondsRemaining seconds.';
        });
      } else {
        // Penalty expired, clean up states
        _lockoutTimer?.cancel();
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
          _error = null;
          _emailCtrl.clear();
          _passwordCtrl.clear();
        });
      }
    });
  }

  // ── Biometric Authentication Loop ──────────────────────────────────────────
  Future<void> _startFaceLogin() async {
    if (_isLockedOut) {
      setState(() {
        _error = 'System locked out. Password fallback required after expiration.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // FIX 1: Expect a dynamic or Object result since FaceAuthScreen returns a String ID upon success
      final Object? result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const FaceAuthScreen(
            mode: FaceAuthMode.login, // Triggers global database scan loop match
            userId: '',               // Empty string safely bypassed by design
          ),
        ),
      );

      if (!mounted) return;

      // FIX 2: Check if the returned object is the matched User ID String
      if (result != null && result is String && result.isNotEmpty) {
        final String matchedUid = result;

        // NOTE: If you are managing user states directly via their Firestore UID
        // without an active Firebase Auth password session, pass the matchedUid directly to the Menu:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MenuScreen(uid: matchedUid),
          ),
        );
      } else {
        setState(() {
          _error = 'Biometric verification canceled or denied.';
        });
      }

    } catch (e) {
      setState(() {
        _error = 'Face login error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'too-many-requests':
        return 'Too many attempts. Locked out for security.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel(); // Safe memory cleaning optimization to prevent leaks
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🍽️', style: TextStyle(fontSize: 30)),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Sign in to continue ordering',
                style: TextStyle(
                  color: AppColors.subtext,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 36),

              _FaceLoginButton(
                onTap: (_loading || _isLockedOut) ? () {} : _startFaceLogin,
              ),

              const SizedBox(height: 20),

              _divider('or sign in with password'),

              const SizedBox(height: 20),

              _inputField(
                controller: _emailCtrl,
                hint: 'Email address',
                icon: Icons.mail_outline_rounded,
                enabled: !_isLockedOut, // Gray out text field if locked out
              ),

              const SizedBox(height: 14),

              _inputField(
                controller: _passwordCtrl,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                enabled: !_isLockedOut, // Gray out text field if locked out
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.subtext,
                    size: 20,
                  ),
                  onPressed: _isLockedOut ? null : () {
                    setState(() => _obscure = !_obscure);
                  },
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLockedOut ? Colors.grey : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: (_loading || _isLockedOut) ? null : _login,
                  child: _loading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    _isLockedOut ? 'Locked Out' : 'Log In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: AppColors.subtext),
                      children: [
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.subtext,
              fontSize: 12.5,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.subtext),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade200,
        prefixIcon: Icon(
          icon,
          color: AppColors.subtext,
          size: 20,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FaceLoginButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FaceLoginButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4A90D9),
              Color(0xFF357ABD),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90D9).withOpacity(.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '😊',
              style: TextStyle(fontSize: 22),
            ),
            SizedBox(width: 10),
            Text(
              'Log in with Face',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}