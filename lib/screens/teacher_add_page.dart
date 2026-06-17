import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/models/teachers.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/providers/teachers_provider.dart';

class AddTeacherPage extends ConsumerStatefulWidget {
  const AddTeacherPage({super.key});

  @override
  ConsumerState<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends ConsumerState<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleOptions = const ['Mr.', 'Ms.', 'Dr.'];
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _linkedinController = TextEditingController();
  String _selectedTitle = 'Mr.';
  String? _selectedDepartmentCode;
  String? _selectedCampusCode;
  bool _isSaving = false;
  String _formError = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final hasEmail = _emailController.text.trim().isNotEmpty;
    final hasLinkedIn = _linkedinController.text.trim().isNotEmpty;
    if (!hasEmail && !hasLinkedIn) {
      setState(() {
        _formError = 'Provide either an email or a LinkedIn profile.';
      });
      return;
    }

    final config = ref.read(backendConfigProvider).maybeWhen(
          data: (config) => config,
          orElse: () => null,
        );
    final departments = config?.departments ?? const <Department>[];
    final campuses = config?.campuses ?? const <Campus>[];
    final selectedDepartment = departments.where(
      (dept) => dept.code == _selectedDepartmentCode,
    ).toList();
    final selectedCampus = campuses.where(
      (campus) => campus.code == _selectedCampusCode,
    ).toList();
    if (selectedDepartment.isEmpty) {
      setState(() {
        _formError = 'Select a department.';
      });
      return;
    }
    if (selectedCampus.isEmpty) {
      setState(() {
        _formError = 'Select a campus.';
      });
      return;
    }

    if (_formError.isNotEmpty) {
      setState(() => _formError = '');
    }

    setState(() => _isSaving = true);
    try {
        await ref.read(teachersProvider.notifier).createTeacher(
              TeacherCreateRequest(
                title: _selectedTitle,
                name: _nameController.text.trim(),
                email: _emailController.text.trim().isEmpty
                    ? null
                    : _emailController.text.trim(),
                linkedinProfile: _linkedinController.text.trim().isEmpty
                    ? null
                    : _linkedinController.text.trim(),
                department: selectedDepartment.first,
                campus: selectedCampus.first,
              ),
            );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher added successfully. Awaiting admin approval.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = 'Failed to add teacher: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(backendConfigProvider);
    final departments = configAsync.maybeWhen(
      data: (config) => config.departments,
      orElse: () => <Department>[],
    );
    final campuses = configAsync.maybeWhen(
      data: (config) => config.campuses,
      orElse: () => <Campus>[],
    );

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
          'Add Teacher',
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
                'Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints.tightFor(width: 90),
                    child: Container(
                      decoration: AppStyle.dropdownContainerDecoration(),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.white,
                          focusColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: DropdownButton<String>(
                              value: _selectedTitle,
                              isExpanded: true,
                              focusColor: Colors.transparent,
                              dropdownColor: Colors.white,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              items: _titleOptions
                                  .map(
                                    (title) => DropdownMenuItem(
                                      value: title,
                                      child: Text(title),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedTitle = value);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_formError.isNotEmpty) {
                          setState(() => _formError = '');
                        }
                      },
                      decoration: _fieldDecoration('Teacher name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Department',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: AppStyle.dropdownContainerDecoration(),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDepartmentCode,
                  decoration: AppStyle.dropdownInputDecoration(
                    hintText: 'Select department',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                  items: departments
                      .map(
                        (dept) => DropdownMenuItem(
                          value: dept.code,
                          child: Text(dept.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedDepartmentCode = value);
                    if (_formError.isNotEmpty) {
                      setState(() => _formError = '');
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a department';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Campus',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 50,
                decoration: AppStyle.dropdownContainerDecoration(),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCampusCode,
                  decoration: AppStyle.dropdownInputDecoration(
                    hintText: 'Select campus',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey,
                  ),
                  items: campuses
                      .map(
                        (campus) => DropdownMenuItem(
                          value: campus.code,
                          child: Text(campus.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedCampusCode = value);
                    if (_formError.isNotEmpty) {
                      setState(() => _formError = '');
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Select a campus';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_formError.isNotEmpty) {
                    setState(() => _formError = '');
                  }
                },
                decoration: _fieldDecoration('teacher@example.com'),
              ),
              const SizedBox(height: 20),
              const Text(
                'LinkedIn Profile',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _linkedinController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_formError.isNotEmpty) {
                    setState(() => _formError = '');
                  }
                },
                decoration: _fieldDecoration(
                  'https://linkedin.com/in/teacher',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF2D88B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Color(0xFF9A7B00),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Provide an email, a LinkedIn profile, or both.',
                        style: const TextStyle(
                          color: Color(0xFF7A6200),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Teacher'),
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
