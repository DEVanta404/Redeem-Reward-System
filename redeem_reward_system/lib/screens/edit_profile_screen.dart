import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../services/supabase_profiles.dart';

class EditProfileScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onSaved;

  const EditProfileScreen({
    super.key,
    required this.state,
    required this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _birthdayCtrl;
  late String _avatarPath;
  late String _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.state.user.name);
    _emailCtrl = TextEditingController(text: widget.state.user.email);
    _phoneCtrl = TextEditingController(text: widget.state.user.phone);
    _birthdayCtrl = TextEditingController(text: widget.state.user.birthday);
    _avatarPath = widget.state.user.avatarPath;
    _avatarUrl = widget.state.user.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _birthdayCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null || !mounted) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: const Color(0xFF3E2723),
            toolbarWidgetColor: Colors.white,
            statusBarLight: false,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile == null || !mounted) return;

      setState(() {
        _avatarPath = croppedFile.path;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the image picker. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }

    final currentUserId =
        widget.state.user.id.isNotEmpty
            ? widget.state.user.id
            : Supabase.instance.client.auth.currentUser?.id ?? '';

    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save profile without a valid user ID.'),
        ),
      );
      return;
    }

    String? savedAvatarUrl = _avatarUrl;

    if (_avatarPath.trim().isNotEmpty && File(_avatarPath).existsSync()) {
      debugPrint('Attempting to upload avatar from path: $_avatarPath');
      savedAvatarUrl = await SupabaseProfilesService().uploadAvatar(
        userId: currentUserId,
        localPath: _avatarPath,
      );
      debugPrint('Avatar upload result: $savedAvatarUrl');

      if (savedAvatarUrl == null && _avatarUrl.isEmpty) {
        debugPrint(
          'Avatar upload skipped: storage bucket not configured. Saving profile without a picture.',
        );
      }
    } else {
      debugPrint('No new avatar selected, using existing URL: $savedAvatarUrl');
    }

    final finalAvatarUrl = savedAvatarUrl ?? _avatarUrl;
    debugPrint('Final avatar URL to save: $finalAvatarUrl');

    final updatedProfile = widget.state.user.copyWith(
      id: currentUserId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      birthday: _birthdayCtrl.text.trim(),
      avatarPath: _avatarPath,
      avatarUrl: finalAvatarUrl,
    );

    debugPrint(
      'Saving profile with phone: ${updatedProfile.phone} and avatarUrl: ${updatedProfile.avatarUrl}',
    );

    widget.state.updateProfile(updatedProfile);

    try {
      await SupabaseProfilesService().createOrUpdateProfile(
        userId: currentUserId,
        email: updatedProfile.email,
        fullName: updatedProfile.name,
        username: updatedProfile.name,
        phone: updatedProfile.phone,
        birthday: updatedProfile.birthday,
        avatarUrl: finalAvatarUrl,
      );
      widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $error'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _avatarPath.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF3E2723),
                      backgroundImage:
                          hasAvatar ? FileImage(File(_avatarPath)) : null,
                      child: hasAvatar
                          ? null
                          : ValueListenableBuilder(
                              valueListenable: _nameCtrl,
                              builder: (_, value, _) => Text(
                                value.text.isNotEmpty
                                    ? value.text[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _FormField(
              controller: _nameCtrl,
              label: 'Username',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 14),
            _FormField(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _FormField(
              controller: _phoneCtrl,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _FormField(
              controller: _birthdayCtrl,
              label: 'Birthday',
              icon: Icons.cake_outlined,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3E2723),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF795548)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}
