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

  Future<void> _initializeCurrency() async {
    await CurrencyService.loadUserCurrency();
    if (mounted) setState(() {});
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final accent = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    return Container(
      color: bgColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ================= SEARCH =================
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              style: TextStyle(color: textColor),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search subscriptions...",
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                prefixIcon: Icon(
                  Icons.search,
                  color: textColor.withOpacity(0.5),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ================= TOTAL CARD =================
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.15), blurRadius: 30),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _showMonthly ? 'Total Monthly Spend' : 'Total Yearly Spend',
                  style: TextStyle(color: textColor.withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyService.format(totalSpend),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _cycleButton('Monthly', _showMonthly, accent),
                    const SizedBox(width: 12),
                    _cycleButton('Yearly', !_showMonthly, accent),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ================= CATEGORY =================
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final selected = _selectedCategory == cat;

                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  selectedColor: accent,
                  backgroundColor: cardColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : textColor.withOpacity(0.7),
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ================= SUBS =================
          if (filteredSubscriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  'No subscriptions found',
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                ),
              ),
            )
          else
            ...filteredSubscriptions.map((sub) {
              final brandImage = _getBrandImage(sub.name);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    backgroundImage: sub.imageUrl != null
                        ? NetworkImage(sub.imageUrl!)
                        : brandImage,
                    child: sub.imageUrl == null && brandImage == null
                        ? Text(
                            sub.name.isNotEmpty
                                ? sub.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: textColor),
                          )
                        : null,
                  ),
                  title: Text(
                    sub.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    sub.category,
                    style: TextStyle(color: textColor.withOpacity(0.5)),
                  ),
                  trailing: Text(
                    CurrencyService.format(sub.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sub.isPaused ? Colors.grey : accent,
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
      ),
    );
  }

  Widget _cycleButton(String label, bool selected, Color accent) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showMonthly = label == 'Monthly'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : accent,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(elevation: 0, title: const Text('My Subscriptions')),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: navColor,
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
      ),
    );
  }
}
