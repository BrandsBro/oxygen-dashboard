import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://hkijrvsgkqgwujeovlju.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhraWpydnNna3Fnd3VqZW92bGp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NzU1NzcsImV4cCI6MjEwNDM1MTU3N30.6hPgUI2hl1hsTTgvZoW2D97ccpxK_viewnrnWzNTjAo',
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oxygen Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C63FF),
          surface: const Color(0xFF1A1A1A),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customer;
  final String total;
  final String currency;
  final String store;
  final bool trackingAdded;
  final DateTime time;
  final String event;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customer,
    required this.total,
    required this.currency,
    required this.store,
    required this.trackingAdded,
    required this.time,
    required this.event,
  });

  factory OrderModel.fromSupabase(Map<String, dynamic> data) {
    return OrderModel(
      id: data['id'] ?? '',
      orderNumber: data['order_number'] ?? '',
      customer: data['customer'] ?? 'Unknown',
      total: data['total'] ?? '0',
      currency: data['currency'] ?? 'USD',
      store: data['store'] ?? 'Unknown',
      trackingAdded: data['tracking_added'] ?? false,
      time: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      event: data['event'] ?? 'order_created',
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<OrderModel> _orders = [];
  int _unreadCount = 0;
  String _selectedStore = 'All';
  final List<String> _stores = ['All'];
  bool _loading = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _setupFCM();
  }

  Future<void> _loadOrders() async {
    final data = await supabase
        .from('orders')
        .select()
        .order('created_at', ascending: false);

    setState(() {
      _orders.clear();
      for (final row in data) {
        final order = OrderModel.fromSupabase(row);
        _orders.add(order);
        if (!_stores.contains(order.store)) {
          _stores.add(order.store);
        }
      }
      _loading = false;
    });
  }

  Future<void> _setupFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken(
      vapidKey: 'BIKUs4nGLswh7p88I1ganbiEbSMpJV9NpZsqenGQqdpeCSz6gxvxzVMj9nxwqrgCkJK2EyQNEVjJebzi2u4qPjE',
    );
    if (token != null) {
      print('FCM Token: $token');
      await supabase.from('fcm_tokens').upsert({
        'token': token,
        'platform': 'web',
        'updated_at': DateTime.now().toIso8601String(),
      });
      print('Token saved to Supabase!');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Reload orders from Supabase on new message
      _loadOrders();
      _unreadCount++;
    });
  }

  List<OrderModel> get _filteredOrders {
    if (_selectedStore == 'All') return _orders;
    return _orders.where((o) => o.store == _selectedStore).toList();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStoreFilter(),
            _buildStats(),
            Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _buildOrderList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${_orders.length} total orders', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ],
          ),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_outlined, color: Colors.white),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                    child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _stores.length,
        itemBuilder: (context, index) {
          final store = _stores[index];
          final isSelected = store == _selectedStore;
          return GestureDetector(
            onTap: () => setState(() => _selectedStore = store),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6C63FF) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(store, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400], fontWeight: FontWeight.w500)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final tracked = _orders.where((o) => o.trackingAdded).length;
    final untracked = _orders.where((o) => !o.trackingAdded).length;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _statCard('Total Orders', '${_orders.length}', Icons.shopping_bag_outlined, const Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          _statCard('Tracking Added', '$tracked', Icons.local_shipping_outlined, Colors.green),
          const SizedBox(width: 12),
          _statCard('No Tracking', '$untracked', Icons.warning_amber_outlined, Colors.orange),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('No orders yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Orders will appear here in real time', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) => _orderCard(_filteredOrders[index]),
      ),
    );
  }

  Widget _orderCard(OrderModel order) {
    final isTracked = order.trackingAdded;
    final isFulfilled = order.event == 'order_fulfilled';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFulfilled ? Colors.green.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#${order.orderNumber}', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(order.store, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ),
                ],
              ),
              Text(_timeAgo(order.time), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.customer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${order.currency} ${order.total}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isTracked ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTracked ? Icons.local_shipping : Icons.pending_outlined,
                      size: 14,
                      color: isTracked ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isTracked ? 'Tracked' : 'No Tracking',
                      style: TextStyle(
                        color: isTracked ? Colors.green : Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
