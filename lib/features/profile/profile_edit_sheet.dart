// lib/features/profile/profile_edit_sheet.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/storage/profile_storage.dart';

class ProfileEditSheet extends StatefulWidget {
  final Profile initial;
  final String? initialAvatarUrl;

  const ProfileEditSheet({
    Key? key,
    required this.initial,
    this.initialAvatarUrl,
  }) : super(key: key);

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _imageBase64 = '';
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.name);
    _emailController = TextEditingController(text: widget.initial.email);
    _passwordController = TextEditingController();
    _imageBase64 = widget.initial.imageBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: src, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBase64 = base64Encode(bytes);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Uint8List? _imageBytes() {
    if (_imageBase64.isEmpty) return null;
    try {
      return base64Decode(_imageBase64);
    } catch (e) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.initial.copyWith(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      imageBase64: _imageBase64,
    );

    final ok = await Profile.saveProfile(updated);
    setState(() => _saving = false);
    if (ok) {
      // Password is UI-only for now (Firebase or backend integration later).
      if (_passwordController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change not configured (UI only).')));
      }
      Navigator.of(context).pop(updated);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save profile')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgBytes = _imageBytes();
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final src = await showModalBottomSheet<ImageSource?>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from gallery'),
                            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Take a photo'),
                            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('Remove photo'),
                            onTap: () => Navigator.of(ctx).pop(null),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (src == null) {
                    setState(() => _imageBase64 = '');
                  } else {
                    await _pickImage(src);
                  }
                },
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: imgBytes != null ? MemoryImage(imgBytes) : (widget.initialAvatarUrl != null ? NetworkImage(widget.initialAvatarUrl!) as ImageProvider : null),
                  child: imgBytes == null && (widget.initialAvatarUrl == null || widget.initialAvatarUrl!.isEmpty) ? const Icon(Icons.person, size: 36) : null,
                ),
              ),
              TextButton(onPressed: () async {
                // open same bottom sheet as tapping avatar
                final src = await showModalBottomSheet<ImageSource?>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choose from gallery'),
                          onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Take a photo'),
                          onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete),
                          title: const Text('Remove photo'),
                          onTap: () => Navigator.of(ctx).pop(null),
                        ),
                      ],
                    ),
                  ),
                );
                if (src == null) {
                  setState(() => _imageBase64 = '');
                } else {
                  await _pickImage(src);
                }
              }, child: const Text('Change photo')),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: _saving ? const Text('Saving...') : const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
