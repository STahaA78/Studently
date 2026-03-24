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
    interestsController = TextEditingController(text: (widget.user.interests).join(", "));
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
      'name': nameController.text,
      'department': departmentController.text,
      'batch': batchController.text,
      'interests': interestsController.text.split(',').map((e) => e.trim()).toList(),
    };
    try {
      final updatedUser = await UserRepository().updateUserProfile(updatedData);
      if (!mounted) return;
      Navigator.pop(context, updatedUser);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile photo
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.grey.shade400,
                backgroundImage: widget.user.profilePhotoUrl!.isNotEmpty
                  ? NetworkImage(widget.user.profilePhotoUrl!)
                  : null,
                child: widget.user.profilePhotoUrl!.isEmpty
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profile Photo'),
                onPressed: _showEditPhotoOptions,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
                validator: (v) => v == null || v.isEmpty ? 'Enter department' : null,
              ),
              TextFormField(
                controller: batchController,
                decoration: const InputDecoration(labelText: 'Batch'),
                validator: (v) => v == null || v.isEmpty ? 'Enter batch' : null,
              ),
              TextFormField(
                controller: interestsController,
                decoration: const InputDecoration(labelText: 'Interests (comma separated)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                child: isSaving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPhotoOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'take'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Add from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Photo'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'remove') {
      await UserRepository().removeProfilePhoto();
      setState(() {
        widget.user.profilePhotoUrl = '';
      });
    } else if (action == 'gallery' || action == 'take') {
      // Pick image from gallery or camera
      // Requires image_picker package
      final ImageSource source = action == 'gallery' ? ImageSource.gallery : ImageSource.camera;
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        await UserRepository().uploadProfilePhoto(pickedFile.path);
        // Ideally, refetch user profile to get updated URL from backend
        setState(() {
          // This will trigger UI update, but you should refetch user profile for latest URL
        });
      }
    }
  }
}