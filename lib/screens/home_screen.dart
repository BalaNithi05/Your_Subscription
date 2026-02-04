import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_model.dart';
import 'add_subscription_screen.dart';
import 'profile_screen.dart';
import 'analytics_screen.dart';
import 'subscription_details_screen.dart';
import '../repositories/subscription_repository.dart';
import '../services/currency_service.dart';

const Map<String, String> brandLogos = {
  'netflix': 'assets/brands/netflix.png',
  'spotify': 'assets/brands/spotify.png',
  'amazon': 'assets/brands/amazon.png',
  'prime': 'assets/brands/prime.png',
  'youtube': 'assets/brands/youtube.png',
  'disney': 'assets/brands/disney.png',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SubscriptionRepository _repository = SubscriptionRepository();
  final SupabaseClient supabase = Supabase.instance.client;

  int _currentIndex = 0;
  bool _showMonthly = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Subscription> _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeCurrency();
    _loadSubscriptions();
  }

  // =========================
  // LOAD USER CURRENCY
  // =========================
  Future<void> _initializeCurrency() async {
    await CurrencyService.loadUserCurrency();
    if (mounted) setState(() {});
  }

  // =========================
  // LOAD SUBSCRIPTIONS
  // =========================
  Future<void> _loadSubscriptions() async {
    try {
      setState(() => _loading = true);
      final data = await _repository.getAll();

      if (!mounted) return;

      setState(() {
        _subscriptions = data;
        _loading = false;

        if (_selectedCategory != 'All' &&
            !categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  ImageProvider? _getBrandImage(String name) {
    final text = name.toLowerCase();
    for (final entry in brandLogos.entries) {
      if (text.contains(entry.key)) {
        return AssetImage(entry.value);
      }
    }
    return null;
  }

  // =========================
  // TOTAL SPEND (IN INR ONLY)
  // =========================
  double get totalSpend {
    double total = 0;

    for (final sub in filteredSubscriptions) {
      if (sub.isPaused) continue;

      double amount = sub.amount;

      if (_showMonthly) {
        amount = sub.billingCycle == 'monthly' ? amount : amount / 12;
      } else {
        amount = sub.billingCycle == 'yearly' ? amount : amount * 12;
      }

      // ✅ DO NOT CONVERT HERE
      total += amount;
    }

    return total;
  }

  List<String> get categories {
    final set = <String>{};
    for (final sub in _subscriptions) {
      set.add(sub.category);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<Subscription> get filteredSubscriptions {
    return _subscriptions.where((sub) {
      final catMatch =
          _selectedCategory == 'All' || sub.category == _selectedCategory;

      final searchMatch = sub.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      return catMatch && searchMatch;
    }).toList();
  }

  Widget _dashboardTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ================= TOTAL CARD =================
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _showMonthly ? 'Total Monthly Spend' : 'Total Yearly Spend',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyService.format(totalSpend),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _cycleButton('Monthly', _showMonthly),
                  const SizedBox(width: 8),
                  _cycleButton('Yearly', !_showMonthly),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ================= CATEGORY FILTER =================
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final cat = categories[i];
              return ChoiceChip(
                label: Text(cat),
                selected: _selectedCategory == cat,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // ================= SUBSCRIPTION LIST =================
        if (filteredSubscriptions.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No subscriptions found')),
          )
        else
          ...filteredSubscriptions.map((sub) {
            final brandImage = _getBrandImage(sub.name);

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: sub.imageUrl != null
                      ? NetworkImage(sub.imageUrl!)
                      : brandImage,
                  child: sub.imageUrl == null && brandImage == null
                      ? Text(
                          sub.name.isNotEmpty ? sub.name[0].toUpperCase() : '?',
                        )
                      : null,
                ),
                title: Text(sub.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.category),
                    if (sub.isPaused)
                      const Text(
                        'Paused',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: Text(
                  CurrencyService.format(sub.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sub.isPaused ? Colors.grey : Colors.black,
                  ),
                ),
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionDetailsScreen(subscription: sub),
                    ),
                  );
                  if (updated == true) _loadSubscriptions();
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _cycleButton(String label, bool selected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showMonthly = label == 'Monthly'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.blue : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboardTab(),
      AnalyticsScreen(subscriptions: _subscriptions),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('My Subscriptions')),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final added = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddSubscriptionScreen(),
                  ),
                );
                if (added == true) _loadSubscriptions();
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
