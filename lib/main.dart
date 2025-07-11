// lib/main.dart (診断機能付き・完全版)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ===== モデルクラス =====
class MenuItem {
  final String id;
  final String name;
  final int price;
  final String imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? '',
      price: data['price'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }
}

class Shop {
  final String id;
  final String name;
  final String description;
  final String imageUrl;

  const Shop({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
  });

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Shop(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

// ===== 状態管理クラス =====
class CartModel extends ChangeNotifier {
  final List<MenuItem> _items = [];
  String _shopId = '';
  String _shopName = '';

  List<MenuItem> get items => _items;
  String get shopId => _shopId;
  String get shopName => _shopName;

  void add(MenuItem item, String currentShopId, String currentShopName) {
    if (_shopId.isNotEmpty && _shopId != currentShopId) {
      clear();
    }
    _shopId = currentShopId;
    _shopName = currentShopName;
    _items.add(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _shopId = '';
    _shopName = '';
    notifyListeners();
  }

  int get totalPrice {
    return _items.fold(0, (total, current) => total + current.price);
  }
}

// ===== アプリの開始点 =====
Future<void> main() async {
  // ★1: Flutterエンジンとウィジェットツリーの結合を保証
  WidgetsFlutterBinding.ensureInitialized();
  print("--- OK: Flutter WidgetsFlutterBinding.ensureInitialized() ---");

  // ★2: Firebaseサービスの初期化が完了するのを「待つ」
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("--- OK: Firebase.initializeApp() ---");
  } catch (e) {
    print("！！！！！！！！！！！！！！！！！！！！！！！！");
    print("！！！ Firebaseの初期化に失敗しました ！！！");
    print("エラー: $e");
    print("！！！！！！！！！！！！！！！！！！！！！！！！");
  }
  
  // ★3: すべての初期化が終わってからアプリ本体を起動
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartModel(),
      child: const MyApp(),
    ),
  );
  print("--- OK: runApp() ---");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'モバイルオーダー',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

// ===== 再利用可能なAppBar部品 =====
class MyAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const MyAppbar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// ===== カート画面 =====
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  Future<void> _placeOrder(CartModel cart) async {
    print('--- 注文処理を開始します ---');
    if (cart.items.isEmpty) {
      print('エラー: カートが空です。');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('カートが空です')),
      );
      return;
    }
    setState(() { _isLoading = true; });
    try {
      final orderData = {
        'shopId': cart.shopId,
        'shopName': cart.shopName,
        'items': cart.items.map((item) => item.toMap()).toList(),
        'totalPrice': cart.totalPrice,
        'orderStatus': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      };
      print('Firestoreに書き込むデータ: $orderData');
      print('Firestoreへの書き込み処理を実行します...');
      await FirebaseFirestore.instance.collection('orders').add(orderData);
      print('Firestoreへの書き込みに成功しました！');
      cart.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注文が確定しました！')),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      print('！！！！！！！！！！！！！！！！！！！！！！！！');
      print('エラー発生: 注文処理に失敗しました。');
      print('エラータイプ: ${error.runtimeType}');
      print('エラー詳細: $error');
      print('！！！！！！！！！！！！！！！！！！！！！！！！');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注文に失敗しました。詳細はコンソールを確認してください。')),
      );
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
      print('--- 注文処理を終了します ---');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartModel>(context);
    return Scaffold(
      appBar: const MyAppbar(title: 'カート'),
      body: cart.items.isEmpty
          ? const Center(child: Text('カートは空です', style: TextStyle(fontSize: 18)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        leading: const Icon(Icons.check),
                        title: Text(item.name),
                        trailing: Text('¥${item.price}'),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('合計金額', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('¥${cart.totalPrice}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _placeOrder(cart),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('注文を確定する', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== ホーム画面（お店一覧） =====
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MyAppbar(title: 'お店を探す'),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('shops').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('利用できるお店がありません。'));
          }
          final shops = snapshot.data!.docs.map((doc) => Shop.fromFirestore(doc)).toList();
          return ListView.builder(
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ShopDetailScreen(shop: shop),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ShopCard(shop: shop),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ===== お店カード =====
class ShopCard extends StatelessWidget {
  final Shop shop;
  const ShopCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        children: [
          FadeInImage.assetNetwork(
            placeholder: 'assets/images/loading.gif',
            image: shop.imageUrl,
            fit: BoxFit.cover,
            height: 200,
            width: double.infinity,
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(shop.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ===== お店詳細画面（メニュー一覧） =====
class ShopDetailScreen extends StatelessWidget {
  final Shop shop;

  const ShopDetailScreen({
    super.key,
    required this.shop,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: shop.name),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('shops')
            .doc(shop.id)
            .collection('menu_items')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('メニューの読み込みに失敗しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('このお店にはメニューがありません。'));
          }
          final menuDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: menuDocs.length,
            itemBuilder: (context, index) {
              final menuItem = MenuItem.fromFirestore(menuDocs[index]);
              return ListTile(
                leading: menuItem.imageUrl.isNotEmpty
                    ? SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: FadeInImage.assetNetwork(
                            placeholder: 'assets/images/loading.gif',
                            image: menuItem.imageUrl,
                            fit: BoxFit.cover,
                            imageErrorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.fastfood, size: 40);
                            },
                          ),
                        ),
                      )
                    : const SizedBox(
                        width: 80,
                        height: 80,
                        child: Icon(Icons.fastfood, size: 40),
                      ),
                title: Text(menuItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('¥${menuItem.price}'),
                trailing: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('追加'),
                  onPressed: () {
                    Provider.of<CartModel>(context, listen: false).add(menuItem, shop.id, shop.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${menuItem.name}をカートに追加しました'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}