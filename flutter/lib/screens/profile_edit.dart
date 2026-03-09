import 'package:flutter/material.dart';
import 'package:studently/models/user.dart';
import 'package:studently/repositories/user.dart';

class EditProfilePage extends StatefulWidget {
  final User user;
  final String userId;

  const EditProfilePage({super.key, required this.user, required this.userId});

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
    interestsController = TextEditingController(text: (widget.user.interests ?? []).join(", "));
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
      final updatedUser = await UserRepository().updateUserProfile(widget.userId, updatedData);
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
}
