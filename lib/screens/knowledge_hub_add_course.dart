import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/knowledge_hub.dart';
import 'package:studently/providers/knowledge_hub_provider.dart';

class AddCoursePage extends ConsumerStatefulWidget {
  const AddCoursePage({super.key});

  @override
  ConsumerState<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends ConsumerState<AddCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String _formError = '';

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_formError.isNotEmpty) {
      setState(() => _formError = '');
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(knowledgeHubRepositoryProvider).addCourse(
            Course(
              code: _codeController.text.trim().toUpperCase(),
              name: _nameController.text.trim(),
            ),
          );
      ref.invalidate(allCoursesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course added successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = 'Failed to add course: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Add Course',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            children: [
              const Text(
                'Course Code',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_formError.isNotEmpty) {
                    setState(() => _formError = '');
                  }
                },
                decoration: _fieldDecoration('e.g. CS101'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Course code is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Course Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_formError.isNotEmpty) {
                    setState(() => _formError = '');
                  }
                },
                decoration: _fieldDecoration('e.g. Data Structures'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Course name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Course'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_formError.isNotEmpty)
                Text(
                  _formError,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D0D0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D0D0), width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
