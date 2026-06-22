import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // 👈 Required for core framework tasks

import '../main.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'face_auth_screen.dart';

class MenuScreen extends StatefulWidget {
  final String? uid;

  const MenuScreen({
    super.key,
    this.uid,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _selectedCategory = 'All';
  final _cart = Cart();

  String _username = 'there';
  String _email = '';
  bool _faceEnrolled = false;

  final _categories = ['All', 'Mains', 'Drinks', 'Desserts'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String? get _activeUid {
    return widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _loadUserData() async {
    final uid = _activeUid;

    if (uid == null) {
      debugPrint('UID is null');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted) return;

    final data = doc.data();

    setState(() {
      final name = data?['name'] ?? '';
      _username = name.toString().isNotEmpty
          ? name.toString().split(' ').first
          : 'there';

      _email = data?['email'] ??
          FirebaseAuth.instance.currentUser?.email ??
          '';

      _faceEnrolled = data?['faceEnrolled'] ?? false;
    });
  }

  // ── 🔒 SECURE RE-AUTHENTICATION CHANGE PASSWORD DIALOG ──────────────────────
  void _showChangePasswordDialog(BuildContext context) {
    final _oldPasswordCtrl = TextEditingController();
    final _newPasswordCtrl = TextEditingController();
    final _confirmPasswordCtrl = TextEditingController();

    bool _isUpdating = false;
    String? _dialogError;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing during network transaction
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            Future<void> _executeUpdate() async {
              final oldPassword = _oldPasswordCtrl.text.trim();
              final newPassword = _newPasswordCtrl.text.trim();
              final confirmPassword = _confirmPasswordCtrl.text.trim();

              // 1. Core Empty Field Check
              if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                setDialogState(() => _dialogError = 'All fields are required.');
                return;
              }

              // 2. OWASP Strict Complexity Policy Enforcement Engine
              final owaspRegex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@#$!%*?&.])[A-Za-z\d@#$!%*?&.]{8,}$');

              if (!owaspRegex.hasMatch(newPassword)) {
                setDialogState(() => _dialogError =
                'Password does not meet complexity rules:\n'
                    '• Must be at least 8 characters long\n'
                    '• Include at least one uppercase letter (A-Z)\n'
                    '• Include at least one lowercase letter (a-z)\n'
                    '• Include at least one number (0-9)\n'
                    '• Include at least one special character (@, #, \$, %, *, !, ., ?)'
                );
                return;
              }

              // 3. Confirm Match Check
              if (newPassword != confirmPassword) {
                setDialogState(() => _dialogError = 'New passwords do not match.');
                return;
              }

              setDialogState(() {
                _isUpdating = true;
                _dialogError = null;
              });

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) throw Exception('No authenticated user found.');

                AuthCredential credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: oldPassword,
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);

                if (!context.mounted) return;
                Navigator.pop(context); // Clear dialog safely

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password changed successfully! 🎉'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                setDialogState(() {
                  if (e.code == 'wrong-password') {
                    _dialogError = 'The current password you entered is incorrect.';
                  } else {
                    _dialogError = e.message ?? 'Failed to update password.';
                  }
                });
              } catch (e) {
                setDialogState(() => _dialogError = 'An unexpected error occurred.');
              } finally {
                setDialogState(() => _isUpdating = false);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.text),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'For security, you must enter your current password to authorize this modification.',
                      style: TextStyle(color: AppColors.subtext, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _oldPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.gpp_good_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _dialogError!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isUpdating ? null : _executeUpdate,
                  child: _isUpdating
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<FoodItem> get _filtered {
    if (_selectedCategory == 'All') return menuItems;

    return menuItems
        .where((f) => f.category == _selectedCategory)
        .toList();
  }

  void _addToCart(FoodItem item) {
    setState(() => _cart.add(item));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.emoji} ${item.name} added to cart'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: AppColors.text,
      ),
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _username.isNotEmpty
                        ? _username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Hi, $_username!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),

              Text(
                _email,
                style: const TextStyle(
                  color: AppColors.subtext,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _faceEnrolled
                        ? AppColors.success.withOpacity(.12)
                        : AppColors.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _faceEnrolled
                        ? Icons.face_retouching_natural_rounded
                        : Icons.face_outlined,
                    color: _faceEnrolled
                        ? AppColors.success
                        : AppColors.primary,
                    size: 24,
                  ),
                ),
                title: Text(
                  _faceEnrolled
                      ? 'Face Login Enabled'
                      : 'Set Up Face Login',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                subtitle: Text(
                  _faceEnrolled
                      ? 'Tap to re-enroll your face'
                      : 'Enable face recognition for faster login',
                  style: const TextStyle(
                    color: AppColors.subtext,
                    fontSize: 12.5,
                  ),
                ),
                trailing: _faceEnrolled
                    ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                )
                    : const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.subtext,
                ),
                onTap: () async {
                  Navigator.pop(ctx);

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FaceAuthScreen(
                        mode: FaceAuthMode.authenticate,
                        // FIX: Force cast the nullable String? to a non-nullable String using !
                        userId: widget.uid!,
                      ),
                    ),
                  );

                  if (result == true && mounted) {
                    await _loadUserData();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('😊 Face login enabled!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),

              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),

              // ── 🔓 NEW: SECURE PASSWORD ROTATION MANAGEMENT MODULE ──────────────────
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                subtitle: const Text(
                  'Securely rotate your account password',
                  style: TextStyle(
                    color: AppColors.subtext,
                    fontSize: 12.5,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.subtext,
                ),
                onTap: () {
                  Navigator.pop(ctx); // Dismiss profile menu sheet clean
                  _showChangePasswordDialog(context); // Pop password adjustment layer
                },
              ),

              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);

                  await FirebaseAuth.instance.signOut();

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginScreen(),
                    ),
                        (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hey, $_username 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const Text(
                          'What are you craving?',
                          style: TextStyle(
                            color: AppColors.subtext,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );

                      setState(() {});
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (_cart.count > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_cart.count}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  GestureDetector(
                    onTap: _showProfile,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.subtext,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!_faceEnrolled)
              GestureDetector(
                onTap: _showProfile,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9).withOpacity(.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4A90D9).withOpacity(.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        '😊',
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Set up Face Login for faster sign-in next time',
                          style: TextStyle(
                            color: Color(0xFF357ABD),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Color(0xFF357ABD),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final active = cat == _selectedCategory;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: active
                            ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                            : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : AppColors.subtext,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => _FoodCard(
                  item: _filtered[i],
                  onAdd: () => _addToCart(_filtered[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onAdd;

  const _FoodCard({
    required this.item,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
              child: Center(
                child: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 52),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.text,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtext,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Text(
                      'RM ${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}