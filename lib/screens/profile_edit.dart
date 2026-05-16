import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'dart:typed_data';
import 'package:studently/models/user.dart';
import 'package:studently/models/backend_config.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:studently/screens/interests.dart';
import 'package:studently/screens/photo_crop.dart';
import 'package:studently/logger.dart';
import 'package:studently/providers/auth_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  final User user;

  const EditProfilePage({super.key, required this.user});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  String? selectedDepartment;
  String? selectedBatch;
  List<Interest> interests = [];
  bool isSaving = false;
  String? _departmentError;
  String? _batchError;

  // Store original profile photo data with crop info
  Uint8List? _originalPhotoBytes;
  Uint8List? _croppedPreviewBytes;
  Map<String, dynamic>? _photosCropData;
  String? _croppedPhotoFileName;
  bool _profileImageFailed = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.user.name);
    selectedDepartment = widget.user.department?.name;
    selectedBatch = widget.user.batch?.trim();
    interests = List<Interest>.from(widget.user.interests);
  }

  List<String> _buildDropdownOptions(List<String> defaults, String? current) {
    final options = <String>[];
    final seen = <String>{};

    void addValue(String? raw) {
      if (raw == null) return;
      final value = raw.trim();
      if (value.isEmpty) return;
      if (seen.add(value)) {
        options.add(value);
      }
    }

    for (final item in defaults) {
      addValue(item);
    }
    addValue(current);

    return options;
  }

  String? _normalizeSelectedValue(String? value, List<String> options) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return options.contains(normalized) ? normalized : null;
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

    setState(() => isSaving = true);

    // Get the Department object from backend config by matching the selected name
    final configAsync = ref.watch(backendConfigProvider);
    Department? selectedDepartmentObj;

    configAsync.whenData((config) {
      for (final dept in config.departments) {
        if (dept.name == selectedDepartment) {
          selectedDepartmentObj = dept;
          break;
        }
      }
    });

    final updatedData = {
      'department': selectedDepartmentObj != null
          ? {
              'name': selectedDepartmentObj!.name,
              'code': selectedDepartmentObj!.code,
            }
          : null,
      'interests': interests,
    };

    try {
      // If user selected a new profile photo, upload it first
      if (_originalPhotoBytes != null) {
        logger.i('Uploading profile photo with crop data...');
        await ref
            .read(authProvider.notifier)
            .updateProfilePhoto(
              filePath: _croppedPhotoFileName ?? 'profile_photo.jpg',
              fileBytes: _originalPhotoBytes,
              filename: _croppedPhotoFileName ?? 'profile_photo.jpg',
              cropData: _photosCropData,
            );
        logger.i('Profile photo uploaded successfully');
        _originalPhotoBytes = null;
        _croppedPreviewBytes = null;
        _photosCropData = null;
        _croppedPhotoFileName = null;
      }

      // Then update other profile data
      await ref.read(authProvider.notifier).updateProfile(updatedData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).value ?? widget.user;
    final configAsync = ref.watch(backendConfigProvider);

    final configDepartments = configAsync.maybeWhen(
      data: (config) => config.departments.map((d) => d.name).toList(),
      orElse: () => <String>[],
    );

    final configBatches = configAsync.maybeWhen(
      data: (config) {
        return List<String>.generate(
          config.batchRange.end - config.batchRange.start + 1,
          (i) => (config.batchRange.start + i).toString(),
        );
      },
      orElse: () => <String>[],
    );

    final departmentOptions = _buildDropdownOptions(
      configDepartments,
      selectedDepartment ?? widget.user.department?.name,
    );
    final batchOptions = _buildDropdownOptions(
      configBatches,
      selectedBatch ?? widget.user.batch,
    );

    final effectiveDepartmentValue = _normalizeSelectedValue(
      selectedDepartment,
      departmentOptions,
    );
    final effectiveBatchValue = _normalizeSelectedValue(
      selectedBatch,
      batchOptions,
    );

    final bool hasPhoto = currentUser.picture?.isNotEmpty ?? false;
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
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
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
                      child: GestureDetector(
                        onTap: _showEditPhotoOptions,
                        child: Column(
                          children: [
                          CircleAvatar(
                            key: ValueKey<String?>(
                              (_croppedPreviewBytes != null || _originalPhotoBytes != null)
                                  ? 'cropped'
                                  : currentUser.picture,
                            ),
                            radius: 52,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _croppedPreviewBytes != null
                                ? MemoryImage(_croppedPreviewBytes!)
                                : _originalPhotoBytes != null
                                ? MemoryImage(_originalPhotoBytes!)
                                : (hasPhoto
                                      ? NetworkImage(currentUser.picture!)
                                      : null),
                            onBackgroundImageError:
                                _croppedPreviewBytes == null && _originalPhotoBytes == null && hasPhoto
                                ? (exception, stackTrace) {
                                    // Defer setState to avoid calling it during paint phase
                                    SchedulerBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(
                                              () => _profileImageFailed =
                                                  true,
                                            );
                                          }
                                        });
                                  }
                                : null,
                            child:
                                ((_croppedPreviewBytes == null && _originalPhotoBytes == null) &&
                                        (!hasPhoto || _profileImageFailed))
                                ? const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _showEditPhotoOptions,
                            child: const Text('Change Profile Photo'),
                          ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    // Name
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        nameController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Department Dropdown
                    const Text(
                      'Department',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: effectiveDepartmentValue,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          errorText: _departmentError,
                        ),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey,
                        ),
                        items: departmentOptions
                            .map(
                              (dept) => DropdownMenuItem(
                                value: dept,
                                child: Text(dept),
                              ),
                            )
                            .toList(),
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
                    if (_departmentError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 8),
                        child: Text(
                          _departmentError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Batch Dropdown
                    const Text(
                      'Batch',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        effectiveBatchValue ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_batchError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 8),
                        child: Text(
                          _batchError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Gender - Read Only
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.user.gender?.displayName ?? 'Not specified',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                builder: (context, ref, _) => ref
                                    .watch(backendConfigProvider)
                                    .when(
                                      loading: () => const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(),
                                      ),
                                      error: (_, _) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: interests.map((interest) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE0E6ED,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (interest
                                                      .emoji
                                                      .isNotEmpty) ...[
                                                    Text(
                                                      interest.emoji,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: interests.map((interest) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE0E6ED,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    interest.emoji,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Text(
                                  'No interests selected yet',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
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
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 20,
              top: 10,
            ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPhotoOptions() async {
    final currentUser = ref.read(authProvider).value ?? widget.user;
    final bool hasPhoto = currentUser.picture?.isNotEmpty ?? false;

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Material(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.camera_alt_outlined),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.pop(context, 'take'),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Choose from Gallery'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(height: 6),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
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
          ),
        );
      },
    );

    if (action == 'remove') {
      // Clear the pending cropped photo if user removes
      setState(() {
        _originalPhotoBytes = null;
        _croppedPreviewBytes = null;
        _photosCropData = null;
        _croppedPhotoFileName = null;
      });
      // Provider handles backend deletion AND state clearing
      await ref.read(authProvider.notifier).removeProfilePhoto();
    } else if (action == 'gallery' || action == 'take') {
      final source = action == 'gallery'
          ? ImageSource.gallery
          : ImageSource.camera;
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        // Navigate to crop screen
        if (!mounted) return;
        final croppedResult = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (context) =>
                ProfilePhotoCropScreen(initialImage: pickedFile),
          ),
        );

        // Store the photo data locally (original bytes + crop info, no upload yet)
        if (croppedResult != null && mounted) {
          final originalImageBytes = croppedResult['originalBytes'] as Uint8List?;
          final croppedPreviewBytes = croppedResult['bytes'] as Uint8List?;
          final cropData = croppedResult['cropData'] as Map<String, dynamic>?;
          if (originalImageBytes != null && cropData != null) {
            setState(() {
              _originalPhotoBytes = originalImageBytes;
              _croppedPreviewBytes = croppedPreviewBytes;
              _photosCropData = cropData;
              _croppedPhotoFileName = pickedFile.name;
            });
          }
        }
      }
    }
  }
}
