import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription_model.dart';
import '../services/supabase_service.dart';
import '../repositories/subscription_repository.dart';
import '../usecases/reminder_usecase.dart';
import '../services/notification_service.dart';
import '../utils/notification_id_helper.dart';

/// 🔵 BRAND LOGO DATABASE (AUTO DETECTION)
const Map<String, String> brandLogos = {
  'netflix': 'assets/brands/netflix.png',
  'spotify': 'assets/brands/spotify.png',
  'amazon': 'assets/brands/amazon.png',
  'prime': 'assets/brands/prime.png',
  'youtube': 'assets/brands/youtube.png',
  'disney': 'assets/brands/disney.png',
};

class AddSubscriptionScreen extends StatefulWidget {
  final Subscription? subscription;
  const AddSubscriptionScreen({super.key, this.subscription});

  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  final SubscriptionRepository _repository = SubscriptionRepository();
  final SupabaseService _categoryService = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _client = Supabase.instance.client;

  File? _logoImage;
  ImageProvider? _brandImage;

  String _billingCycle = 'monthly';
  String _category = 'Entertainment';
  DateTime? _startDate;

  bool _pushReminder = true;
  int _reminderDays = 0;

  bool _saving = false;

  final List<String> _categories = [
    'Entertainment',
    'Utilities',
    'Health',
    'Software',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.subscription != null) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toString();
      _billingCycle = sub.billingCycle;
      _category = sub.category;
      _startDate = sub.startDate;
      _notesController.text = sub.notes ?? '';

      _pushReminder = sub.pushReminder;
      _reminderDays = sub.reminderDays ?? 0;

      _detectBrand(sub.name);
    }
  }

  // ================= IMAGE UPLOAD =================
  Future<String?> _uploadImage(String subscriptionId) async {
    if (_logoImage == null) return null;

    final user = _client.auth.currentUser;
    if (user == null) return null;

    final fileExt = _logoImage!.path.split('.').last;
    final filePath = '${user.id}/$subscriptionId.$fileExt';

    await _client.storage
        .from('subscription-logos')
        .upload(
          filePath,
          _logoImage!,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('subscription-logos').getPublicUrl(filePath);
  }

  // ================= LOAD CATEGORIES =================
  Future<void> _loadCategories() async {
    final dbCategories = await _categoryService.fetchCategories();
    if (!mounted) return;

    setState(() {
      for (final c in dbCategories) {
        if (!_categories.contains(c)) {
          _categories.add(c);
        }
      }
      if (!_categories.contains(_category)) {
        _categories.add(_category);
      }
    });
  }

  // ================= BRAND AUTO DETECT =================
  void _detectBrand(String value) {
    final text = value.toLowerCase();
    for (final entry in brandLogos.entries) {
      if (text.contains(entry.key)) {
        setState(() => _brandImage = AssetImage(entry.value));
        return;
      }
    }
    setState(() => _brandImage = null);
  }

  // ================= PICK IMAGE =================
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _logoImage = File(picked.path);
        _brandImage = null;
      });
    }
  }

  // ================= ADD CATEGORY =================
  Future<void> _addCategoryDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && !_categories.contains(result)) {
      await _categoryService.addCategory(result);
      setState(() {
        _categories.add(result);
        _category = result;
      });
    }
  }

  // ================= PICK DATE =================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  // ================= SAVE =================
  Future<void> _saveSubscription() async {
    if (_saving) return;

    if (_nameController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty ||
        _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _saving = true);

    final isEditing = widget.subscription != null;

    final safeId = isEditing
        ? widget.subscription!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final imageUrl = await _uploadImage(safeId);

    final sub = Subscription(
      id: safeId,
      name: _nameController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      billingCycle: _billingCycle,
      category: _category,
      startDate: _startDate!,
      pushReminder: _pushReminder,
      reminderDays: _pushReminder ? _reminderDays : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isPaused: widget.subscription?.isPaused ?? false,
      createdAt: widget.subscription?.createdAt ?? DateTime.now(),
      imageUrl: imageUrl,
    );

    isEditing ? await _repository.update(sub) : await _repository.add(sub);

    final notificationId = NotificationIdHelper.fromSubscription(sub);

    await NotificationService.cancel(notificationId);

    final reminderDate = ReminderUsecase.getReminderDate(sub);

    if (reminderDate != null) {
      await NotificationService.schedule(
        id: notificationId,
        title: 'Subscription Reminder',
        body: '${sub.name} billing is coming up',
        scheduledDate: reminderDate,
      );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subscription == null
              ? 'Add Subscription'
              : 'Edit Subscription',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _avatarSection(),
            const SizedBox(height: 24),

            _input(
              controller: _nameController,
              label: 'Subscription Name',
              hint: 'eg Netflix, Spotify',
              icon: Icons.search,
              onChanged: _detectBrand,
            ),

            _input(
              controller: _amountController,
              label: 'Amount',
              keyboard: TextInputType.number,
              icon: Icons.currency_rupee,
            ),

            const SizedBox(height: 16),
            _segmented(),
            const SizedBox(height: 16),

            _dateTile(),
            const SizedBox(height: 16),

            _categoryChips(), // ✅ RESTORED
            const SizedBox(height: 24),

            SwitchListTile(
              value: _pushReminder,
              onChanged: (v) => setState(() => _pushReminder = v),
              title: const Text('Push Notification'),
              secondary: const Icon(Icons.notifications),
            ),

            if (_pushReminder) _reminderDropdown(),

            const SizedBox(height: 12),

            _input(
              controller: _notesController,
              label: 'Notes',
              hint: 'Add any additional details',
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveSubscription,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= CATEGORY UI =================
  Widget _categoryChips() {
    return Wrap(
      spacing: 8,
      children: [
        ..._categories.map(
          (cat) => ChoiceChip(
            label: Text(cat),
            selected: _category == cat,
            onSelected: (_) => setState(() => _category = cat),
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.add),
          label: const Text('Add Category'),
          onPressed: () async => await _addCategoryDialog(),
        ),
      ],
    );
  }

  // ================= UI HELPERS =================
  Widget _avatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: _logoImage != null
                  ? FileImage(_logoImage!)
                  : _brandImage,
              child: _logoImage == null && _brandImage == null
                  ? const Icon(Icons.image, size: 32)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Upload photo', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _dateTile() {
    return ListTile(
      tileColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        _startDate == null
            ? 'First Bill'
            : _startDate!.toString().split(' ')[0],
      ),
      trailing: const Icon(Icons.calendar_today),
      onTap: () async => await _pickDate(),
    );
  }

  Widget _reminderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _reminderDays,
          isExpanded: true,
          items: List.generate(
            8,
            (i) => DropdownMenuItem(
              value: i,
              child: Text(
                i == 0 ? 'Notify on bill date' : 'Notify $i day(s) before',
              ),
            ),
          ),
          onChanged: (v) => setState(() => _reminderDays = v!),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType keyboard = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _segmented() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Monthly'),
            selected: _billingCycle == 'monthly',
            onSelected: (_) => setState(() => _billingCycle = 'monthly'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ChoiceChip(
            label: const Text('Yearly'),
            selected: _billingCycle == 'yearly',
            onSelected: (_) => setState(() => _billingCycle = 'yearly'),
          ),
        ),
      ],
    );
  }
}
