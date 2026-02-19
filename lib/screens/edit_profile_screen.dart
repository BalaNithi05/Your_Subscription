import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../services/currency_service.dart';
import '../main.dart';

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

  String _currency = 'INR';

  bool _saving = false;
  bool _loading = true;

  final List<String> _currencies = ['INR', 'USD', 'EUR', 'GBP'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

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
        currency: _currency,
        avatarUrl: avatarUrl,
        themeMode: 'system',
        fcmToken: null,
      );

      await _repository.updateProfile(updatedProfile);

      await CurrencyService.loadUserCurrency();
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

  String _currencyLabel(String code) {
    switch (code) {
      case 'USD':
        return 'USD (\$)';
      case 'EUR':
        return 'EUR (€)';
      case 'GBP':
        return 'GBP (£)';
      default:
        return 'INR (₹)';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                title: const Text('Edit Profile'),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _glassAvatarCard(),
                      const SizedBox(height: 30),
                      _inputCard(
                        child: Column(
                          children: [
                            _inputField(
                              controller: _nameController,
                              label: 'Name',
                            ),
                            const SizedBox(height: 16),
                            _inputField(
                              readOnly: true,
                              label: 'Email',
                              hint: user?.email ?? '',
                            ),
                            const SizedBox(height: 16),
                            _inputField(
                              controller: _phoneController,
                              label: 'Phone',
                              keyboard: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            _inputField(
                              controller: _bioController,
                              label: 'Bio',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _currency,
                              items: _currencies
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(_currencyLabel(code)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _currency = v!),
                              decoration: InputDecoration(
                                labelText: 'Default Currency',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF2563EB),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassAvatarCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : _existingAvatarUrl != null
                      ? NetworkImage(_existingAvatarUrl!)
                      : null,
                  child: _imageFile == null && _existingAvatarUrl == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: Colors.black,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Tap to change photo",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: child,
    );
  }

  Widget _inputField({
    TextEditingController? controller,
    required String label,
    String? hint,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}
