import 'package:flutter/material.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  final User user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController departmentController;
  late TextEditingController batchController;
  late TextEditingController interestsController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    departmentController = TextEditingController(text: widget.user.department);
    batchController = TextEditingController(text: widget.user.batch);
    interestsController = TextEditingController(
      text: widget.user.interests.join(', '),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    departmentController.dispose();
    batchController.dispose();
    interestsController.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);
    final updatedData = {
      'name': nameController.text.trim(),
      'department': departmentController.text.trim(),
      'batch': batchController.text.trim(),
      'interests': interestsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              /// Profile Photo
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

              const SizedBox(height: 28),

              /// Section Label
              _sectionLabel('Personal Info'),
              const SizedBox(height: 12),

              /// Name
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),

              /// Department
              TextFormField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your department' : null,
              ),
              const SizedBox(height: 16),

              /// Batch
              TextFormField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Batch',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your batch' : null,
              ),

              const SizedBox(height: 28),

              /// Section Label
              _sectionLabel('Interests'),
              const SizedBox(height: 8),

              Text(
                'Separate each interest with a comma  (e.g. Flutter, AI, Design)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: interestsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Interests',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.tag_outlined),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              /// Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Colors.black54,
        ),
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