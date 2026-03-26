import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/user.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/repositories/user.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/screens/interests.dart';

class EditProfilePage extends StatefulWidget {
  final User user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  String? selectedDepartment;
  String? selectedBatch;
  List<Interest> interests = [];
  final List<String> departments = ['Computer Science', 'IT', 'ECE', 'Mechanical'];
  final List<String> batches = ['2022', '2023', '2024', '2025'];
  bool isSaving = false;
  String? _departmentError;
  String? _batchError;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    selectedDepartment = widget.user.department;
    selectedBatch = widget.user.batch;
    interests = List<Interest>.from(widget.user.interests);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void _openInterestsPage() async {
    final selectedInterests = await Navigator.of(context).push<List<Interest>>(
      MaterialPageRoute(
        builder: (_) => InterestsSelectionPage(
          initialInterests: interests,
          completeSignup: false,
        ),
      ),
    );
    if (selectedInterests != null) {
      setState(() {
        interests = selectedInterests;
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDepartment == null || selectedDepartment!.isEmpty) {
      setState(() => _departmentError = 'Select department');
      return;
    } else {
      setState(() => _departmentError = null);
    }
    if (selectedBatch == null || selectedBatch!.isEmpty) {
      setState(() => _batchError = 'Select batch');
      return;
    } else {
      setState(() => _batchError = null);
    }

    setState(() => isSaving = true);
    final updatedData = {
      'name': nameController.text.trim(),
      'department': selectedDepartment,
      'batch': selectedBatch,
      'interests': interests,
    };
    try {
      final updatedUser = await UserRepository().updateUserProfile(updatedData);
      if (!mounted) return;
      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  bool get _hasPhoto =>
      (widget.user.profilePhotoUrl?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Profile Photo
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage: _hasPhoto
                              ? NetworkImage(widget.user.profilePhotoUrl!)
                              : null,
                          child: !_hasPhoto
                              ? const Icon(Icons.person, size: 48, color: Colors.white)
                              : null,
                        ),
                        GestureDetector(
                          onTap: _showEditPhotoOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.edit, size: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _showEditPhotoOptions,
                      child: const Text('Change Profile Photo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              // Name
              const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                ),
              ),
              const SizedBox(height: 20),
              // Department Dropdown
              const Text('Department', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedDepartment,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    border: InputBorder.none,
                    errorText: _departmentError,
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  items: departments.map((dept) => DropdownMenuItem(
                    value: dept,
                    child: Text(dept),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedDepartment = val;
                      _departmentError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  menuMaxHeight: 220,
                ),
              ),
              if (_departmentError != null) Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Text(_departmentError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
              const SizedBox(height: 20),
              // Batch Dropdown
              const Text('Batch', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBatch,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    border: InputBorder.none,
                    errorText: _batchError,
                  ),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  items: batches.map((batch) => DropdownMenuItem(
                    value: batch,
                    child: Text(batch),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedBatch = val;
                      _batchError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  menuMaxHeight: 220,
                ),
              ),
              if (_batchError != null) Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: Text(_batchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
              const SizedBox(height: 28),
              const Text('Interests', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _openInterestsPage,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Change your interests',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 24),
                              onPressed: _openInterestsPage,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey.shade300),
                      if (interests.isNotEmpty)
                        Consumer(
                          builder: (context, ref, _) =>
                            ref.watch(backendConfigProvider).when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                              error: (_, _) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: interests.map((interest) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE0E6ED),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (interest.emoji.isNotEmpty) ...[Text(interest.emoji, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6),
                                          ],
                                          Text(
                                            interest.name,
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              data: (config) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: interests.map((interest) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFFE0E6ED),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(interest.emoji, style: const TextStyle(fontSize: 14)),
                                          const SizedBox(width: 6),
                                          Text(
                                            interest.name,
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            'No interests selected yet',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isSaving ? null : saveProfile,
          child: isSaving
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    ),
    ],
    ),
  );
}

  void _showEditPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, 'take'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                if (_hasPhoto) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(context, 'remove'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (action == 'remove') {
      await UserRepository().removeProfilePhoto();
      if (!mounted) return;
      setState(() {
        widget.user.profilePhotoUrl = '';
      });
    } else if (action == 'gallery' || action == 'take') {
      final source =
          action == 'gallery' ? ImageSource.gallery : ImageSource.camera;
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        await UserRepository().uploadProfilePhoto(pickedFile.path);
        if (!mounted) return;
        setState(() {});
      }
    }
  }
}