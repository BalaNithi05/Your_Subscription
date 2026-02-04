import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../services/currency_service.dart';
import '../main.dart'; // currencyNotifier

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  final _client = Supabase.instance.client;
  final ProfileRepository _repository = ProfileRepository();

  File? _imageFile;
  String? _existingAvatarUrl;

  // 🔥 STORE CURRENCY CODE
  String _currency = 'INR';

  bool _saving = false;
  bool _loading = true;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOAD PROFILE =================
  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final profile = await _repository.fetchProfile(user.id);

    if (!mounted) return;

    if (profile != null) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone ?? '';
      _bioController.text = profile.bio ?? '';
      _currency = profile.currency ?? 'INR';
      _existingAvatarUrl = profile.avatarUrl;
    }

    setState(() => _loading = false);
  }

  // ================= PICK IMAGE =================
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  // ================= SAVE PROFILE =================
  Future<void> _saveProfile() async {
    if (_saving) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty')));
      return;
    }

    setState(() => _saving = true);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      String? avatarUrl = _existingAvatarUrl;

      // 🔹 Upload avatar if changed
      if (_imageFile != null) {
        final ext = _imageFile!.path.split('.').last;
        final fileName = '${user.id}.$ext';

        await _client.storage
            .from('avatars')
            .upload(
              fileName,
              _imageFile!,
              fileOptions: const FileOptions(upsert: true),
            );

        avatarUrl = _client.storage.from('avatars').getPublicUrl(fileName);
      }

      final updatedProfile = Profile(
        id: user.id,
        name: _nameController.text.trim(),
        email: user.email ?? '',
        plan: 'free',
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        currency: _currency, // ✅ SAVE CODE
        avatarUrl: avatarUrl,
        themeMode: 'system',
        fcmToken: null,
      );

      await _repository.updateProfile(updatedProfile);

      // 🔥 VERY IMPORTANT
      // Reload CurrencyService
      await CurrencyService.loadUserCurrency();

      // Update global notifier (symbol)
      currencyNotifier.value = CurrencyService.symbol;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _saving = false);
    }
  }

  // ================= CURRENCY LABEL =================
  String _currencyLabel(String code) {
    switch (code) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '₹';
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // AVATAR
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : _existingAvatarUrl != null
                    ? NetworkImage(_existingAvatarUrl!)
                    : null,
                child: _imageFile == null && _existingAvatarUrl == null
                    ? const Icon(Icons.camera_alt, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            // NAME
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // EMAIL
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                hintText: user?.email ?? '',
              ),
            ),
            const SizedBox(height: 16),

            // PHONE
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // BIO
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // CURRENCY
            DropdownButtonFormField<String>(
              value: _currency,
              items: _currencies.map((code) {
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text(_currencyLabel(code)), // symbol only
                );
              }).toList(),
              onChanged: (v) => setState(() => _currency = v!),
              decoration: const InputDecoration(
                labelText: 'Default Currency',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
