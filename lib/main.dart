import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';
import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const FoodPayApp());
}

class FoodPayApp extends StatelessWidget {
  const FoodPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FoodPay',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ── Global design tokens ─────────────────────────────────────────────────────
class AppColors {
  static const Color primary    = Color(0xFFFF6B35);   // warm orange
  static const Color secondary  = Color(0xFFFFB347);   // amber
  static const Color bg         = Color(0xFFFFF8F3);   // warm cream
  static const Color card       = Colors.white;
  static const Color text       = Color(0xFF1A1A2E);
  static const Color subtext    = Color(0xFF9E9E9E);
  static const Color success    = Color(0xFF4CAF50);
  static const Color danger     = Color(0xFFE53935);
  static const Color surface    = Color(0xFFF5F0EB);
}

// ── Cart model (simple global state) ─────────────────────────────────────────
class CartItem {
  final FoodItem food;
  int qty;
  CartItem({required this.food, this.qty = 1});
}

class Cart {
  static final Cart _instance = Cart._();
  factory Cart() => _instance;
  Cart._();

  final List<CartItem> items = [];

  void add(FoodItem food) {
    final existing = items.where((e) => e.food.id == food.id);
    if (existing.isNotEmpty) {
      existing.first.qty++;
    } else {
      items.add(CartItem(food: food));
    }
  }

  void remove(String foodId) {
    items.removeWhere((e) => e.food.id == foodId);
  }

  void decrement(String foodId) {
    final existing = items.where((e) => e.food.id == foodId);
    if (existing.isNotEmpty) {
      if (existing.first.qty > 1) {
        existing.first.qty--;
      } else {
        remove(foodId);
      }
    }
  }

  void clear() => items.clear();

  double get total =>
      items.fold(0, (sum, e) => sum + e.food.price * e.qty);

  int get count => items.fold(0, (sum, e) => sum + e.qty);
}

// ── Food model ────────────────────────────────────────────────────────────────
class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String emoji;
  final String category;
  final Color color;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.emoji,
    required this.category,
    required this.color,
  });
}

// ── Menu data ─────────────────────────────────────────────────────────────────
final List<FoodItem> menuItems = [
  const FoodItem(
    id: 'b1',
    name: 'Nasi Lemak Special',
    description: 'Coconut rice, sambal, anchovies, egg & rendang',
    price: 14.90,
    emoji: '🍚',
    category: 'Mains',
    color: Color(0xFFFFE0B2),
  ),
  const FoodItem(
    id: 'b2',
    name: 'Char Kuey Teow',
    description: 'Wok-fried flat noodles with prawns & cockles',
    price: 12.90,
    emoji: '🍜',
    category: 'Mains',
    color: Color(0xFFFFF3E0),
  ),
  const FoodItem(
    id: 'b3',
    name: 'Roti Canai',
    description: 'Crispy flatbread with dhal & chicken curry',
    price: 6.50,
    emoji: '🫓',
    category: 'Mains',
    color: Color(0xFFFCE4EC),
  ),
  const FoodItem(
    id: 'b4',
    name: 'Ayam Goreng',
    description: 'Crispy fried chicken with sambal & rice',
    price: 11.90,
    emoji: '🍗',
    category: 'Mains',
    color: Color(0xFFF3E5F5),
  ),
  const FoodItem(
    id: 'd1',
    name: 'Teh Tarik',
    description: 'Pulled milk tea, the Malaysian classic',
    price: 4.00,
    emoji: '🧋',
    category: 'Drinks',
    color: Color(0xFFE3F2FD),
  ),
  const FoodItem(
    id: 'd2',
    name: 'Milo Ais',
    description: 'Iced Milo, cold and refreshing',
    price: 4.50,
    emoji: '🥤',
    category: 'Drinks',
    color: Color(0xFFE8F5E9),
  ),
  const FoodItem(
    id: 's1',
    name: 'Cendol',
    description: 'Shaved ice with coconut milk & palm sugar',
    price: 7.50,
    emoji: '🍧',
    category: 'Desserts',
    color: Color(0xFFE0F7FA),
  ),
  const FoodItem(
    id: 's2',
    name: 'Pisang Goreng',
    description: 'Deep-fried banana fritters, crispy & sweet',
    price: 5.00,
    emoji: '🍌',
    category: 'Desserts',
    color: Color(0xFFFFF9C4),
  ),
];
