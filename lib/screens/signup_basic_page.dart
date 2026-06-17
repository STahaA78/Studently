import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'interests.dart';
import 'package:studently/models/user.dart' as studently_user;
import 'package:studently/models/backend_config.dart';
import 'package:studently/logger.dart';
import 'package:studently/app_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/services/firebase_auth.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import 'package:studently/providers/backend_config_provider.dart';

class SignupBasicPage extends ConsumerStatefulWidget {
  const SignupBasicPage({super.key});

  @override
  ConsumerState<SignupBasicPage> createState() => _SignupBasicPageState();
}

class _SignupBasicPageState extends ConsumerState<SignupBasicPage> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // Focus nodes for validation on focus change
  final FocusNode _nameFocus = FocusNode();

  String? _nameError;
  String? _birthdayError;
  String? _genderError;
  String? _completionError;
  String? _departmentCode; // Selected department code (always via dropdown)
  String? _campusCode;
  studently_user.Gender? _selectedGender; // Selected gender
  bool _batchExtracted = false; // Track if batch was extracted from name
  bool _extractedFields = true; // True only if both name and batch were found

  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    _initializeFields();

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _validateName();
    });

    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) {
        logger.i(
          "[$runtimeType] Firebase user signed out, navigating back to login",
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }

  void _initializeFields() {
    final googleSignUpUser = authService.value.currentUser;
    if (googleSignUpUser != null) {
      _nameController.text = googleSignUpUser.displayName ?? '';
      _campusCode = _deriveCampusCode(googleSignUpUser.email ?? '');
      _extractNameAndBatch(_nameController.text);
    }
  }

  String? _deriveCampusCode(String email) {
    final localPart = email.trim().split('@').first.toLowerCase();
    if (localPart.isEmpty) return null;
    switch (localPart[0]) {
      case 'l':
        return 'LHR';
      case 'k':
        return 'KHI';
      case 'f':
        return 'FSD';
      case 'i':
        return 'ISB';
      case 'p':
        return 'PES';
      default:
        return null;
    }
  }

  String _stripRollPrefix(String fullName, String? email) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return fullName.trim();
    final localPart = (email ?? '').trim().split('@').first.toLowerCase();
    if (localPart.isNotEmpty && parts.first.toLowerCase() == localPart) {
      return parts.skip(1).join(' ').trim();
    }
    final rollPattern = RegExp(r'^[a-zA-Z]\d+$');
    if (rollPattern.hasMatch(parts.first)) {
      return parts.skip(1).join(' ').trim();
    }
    return fullName.trim();
  }

  String _fallbackCampusName(String? code) {
    switch (code?.toUpperCase()) {
      case 'LHR':
        return 'Lahore';
      case 'KHI':
        return 'Karachi';
      case 'ISB':
        return 'Islamabad';
      case 'PES':
        return 'Peshawar';
      case 'FSD':
        return 'Chiniot-Faisalabad';
      default:
        return '';
    }
  }

  /// Extracts name and batch from Google profile display name.
  ///
  /// Mirrors the backend Python logic:
  ///   - Scan for the first 4-digit token → that is the batch year.
  ///   - Name = all tokens *before* the token that precedes the batch
  ///     (i.e. parts[0 .. batchIndex-1], dropping the degree abbreviation).
  ///   - If no batch is found, keep the full display name as-is.
  ///
  /// Example: "Hassan Musa BSCS 2022 FAST NU LHR"
  ///   batchIndex = 3  →  name = parts[0..1] = "Hassan Musa", batch = "2022"
  void _extractNameAndBatch(String fullName) {
    logger.d("[$runtimeType] Extracting name/batch from: $fullName");

    final googleSignUpUser = authService.value.currentUser;
    final cleanedName = _stripRollPrefix(fullName, googleSignUpUser?.email);
    final parts = cleanedName.split(' ');
    final batchPattern = RegExp(r'^\d{4}$');

    String batch = '';
    int batchIndex = -1;

    for (int i = 0; i < parts.length; i++) {
      if (batchPattern.hasMatch(parts[i])) {
        batch = parts[i];
        batchIndex = i;
        break;
      }
    }

    // Only treat the Firebase display name as extracted when both a batch and
    // a non-empty name prefix are found. Otherwise fall back to full user input.
    final bool extractedSuccessfully = batchIndex >= 1;
    final String extractedName = extractedSuccessfully
        ? parts.sublist(0, batchIndex - 1).join(' ')
        : fullName;

    final bool hasValidExtraction =
        extractedSuccessfully && extractedName.trim().isNotEmpty;
    final String resolvedBatch = hasValidExtraction ? batch : '';

    setState(() {
      _nameController.text = extractedName;
      _batchController.text = resolvedBatch;
      _campusCode ??= _deriveCampusCode(googleSignUpUser?.email ?? '');
      _batchExtracted = hasValidExtraction;
      // Both name AND batch must have been resolved for "extractedFields" to be true.
      _extractedFields = hasValidExtraction;
    });

    logger.d(
      "[$runtimeType] Extracted → Name: $extractedName | Batch: $resolvedBatch | Success: $_extractedFields",
    );
  }

  Future<void> _handleBirthdayPicker() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Container(
            height: 450,
            width: 350,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Your Birthday',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.grey),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SfDateRangePicker(
                      onSelectionChanged:
                          (DateRangePickerSelectionChangedArgs args) {
                            if (args.value is DateTime) {
                              setState(() {
                                _selectedBirthday = args.value as DateTime;
                                _birthdayController.text =
                                    "${_selectedBirthday!.month}/${_selectedBirthday!.day}/${_selectedBirthday!.year}";
                                _birthdayError = null;
                              });
                              Navigator.pop(context);
                            }
                          },
                      selectionMode: DateRangePickerSelectionMode.single,
                      initialSelectedDate: _selectedBirthday,
                      selectableDayPredicate: (DateTime dateTime) {
                        return dateTime.isBefore(DateTime.now());
                      },
                      backgroundColor: Colors.white,
                      monthViewSettings: DateRangePickerMonthViewSettings(
                        viewHeaderHeight: 40,
                        viewHeaderStyle: DateRangePickerViewHeaderStyle(
                          backgroundColor: AppStyle.primaryBlue,
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      selectionTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      todayHighlightColor: AppStyle.primaryBlue,
                      toggleDaySelection: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCompletion() async {
    final name = _nameController.text.trim();
    final birthday = _birthdayController.text.trim();
    final departmentCode = _departmentCode ?? '';
    final batch = _batchController.text.trim();
    final campusCode = _campusCode ?? _deriveCampusCode(
      authService.value.currentUser?.email ?? '',
    );

    logger.i(
      "[$runtimeType] Google Signup Completion — Name: $name | Birthday: $birthday | DeptCode: $departmentCode | Batch: $batch | CampusCode: $campusCode | Gender: $_selectedGender",
    );

    // Extra guard: department must be selected
    if (departmentCode.isEmpty) {
      setState(() => _completionError = 'Please select your department');
      return;
    }

    if (_validateBirthday() && _validateName() && _validateGender()) {
      setState(() => _completionError = null);

      final googleSignUpUser = authService.value.currentUser;
      if (googleSignUpUser != null) {
        final backendConfigAsync = ref.watch(backendConfigProvider);

        backendConfigAsync.when(
          data: (config) {
            Department? department;
            for (final dept in config.departments) {
              if (dept.code.toUpperCase() == departmentCode.toUpperCase()) {
                department = dept;
                break;
              }
            }
            department ??= config.departments.isNotEmpty
                ? config.departments.first
                : null;
            Campus? campus;
            if (campusCode != null) {
              for (final c in config.campuses) {
                if (c.code.toUpperCase() == campusCode.toUpperCase()) {
                  campus = c;
                  break;
                }
              }
            }
            campus ??= config.campuses.isNotEmpty ? config.campuses.first : null;

            if (department == null) {
              setState(
                () => _completionError = 'Department not found in config',
              );
              return;
            }

            if (campus == null) {
              setState(
                () => _completionError = 'Campus not found in config',
              );
              return;
            }

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InterestsSelectionPage(
                  initialInterests: const [],
                  user: studently_user.User(
                    id: googleSignUpUser.uid,
                    name: name,
                    email: googleSignUpUser.email ?? '',
                    password: '',
                    department: department,
                    batch: batch,
                    campus: campus,
                    birthday: birthday,
                    gender: _selectedGender,
                    picture: googleSignUpUser.photoURL ?? '',
                    interests: const [],
                  ),
                  completeSignup: true,
                  extractedFields: _extractedFields,
                ),
              ),
            );
          },
          loading: () {
            setState(
              () => _completionError = 'Loading department information...',
            );
          },
          error: (error, stack) {
            setState(
              () => _completionError = 'Error loading department information',
            );
            logger.e("[$runtimeType] Error loading backend config: $error");
          },
        );
      }
    }
  }

  bool _validateName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Full name cannot be empty');
      return false;
    }
    if (_nameError != null) setState(() => _nameError = null);
    return true;
  }

  bool _validateBirthday() {
    if (_selectedBirthday == null) {
      setState(() => _birthdayError = 'Please select your birthday');
      return false;
    }
    if (_birthdayError != null) setState(() => _birthdayError = null);
    return true;
  }

  bool _validateGender() {
    if (_selectedGender == null) {
      setState(() => _genderError = 'Please select your gender');
      return false;
    }
    if (_genderError != null) setState(() => _genderError = null);
    return true;
  }

  @override
  void dispose() {
    logger.i("[Signup Basic] Disposing Controllers Started");
    _nameController.dispose();
    _departmentController.dispose();
    _batchController.dispose();
    _birthdayController.dispose();
    _nameFocus.dispose();
    super.dispose();
    logger.i("[Signup Basic] Disposing Controllers Ended");
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = AppStyle.primaryBlue;
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth = isLandscape
        ? screenSize.width * 0.6
        : screenSize.width * 0.85;
    final configAsync = ref.watch(backendConfigProvider);
    final campusName = configAsync.maybeWhen(
      data: (config) {
        final code = _campusCode ?? _deriveCampusCode(
          authService.value.currentUser?.email ?? '',
        );
        final match = config.campuses.where((c) => c.code == code).toList();
        if (match.isNotEmpty) {
          return match.first.name;
        }
        return _fallbackCampusName(code);
      },
      orElse: () => _fallbackCampusName(_campusCode),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Back Button + Title ──────────────────────────────────────
              Column(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppStyle.backButtonLeftPadding,
                          bottom: AppStyle.backButtonBottomPadding,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF323743),
                            size: 30,
                          ),
                          onPressed: () async {
                            await authService.value.signOut();
                            logger.i("[$runtimeType] Signed out from Firebase");
                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppStyle.signUpPageTitleLeftPadding,
                      right: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Welcome to',
                              style: GoogleFonts.poppins(
                                fontSize: AppStyle.signUpPageHeadingFontSize,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,

                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 40.0),
                                child: Text(
                                  'Studently',
                                  style: GoogleFonts.poppins(
                                    color: blue,
                                    fontSize: AppStyle.titleFontSize,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── Form ────────────────────────────────────────────────────
              SizedBox(
                width: formWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name ──────────────────────────────────────────
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        // Read-only when batch was successfully extracted;
                        // editable only when extraction failed so the user can correct it.
                        enabled: !_batchExtracted,
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD0D0D0),
                              width: 1.2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD0D0D0),
                              width: 1.2,
                            ),
                          ),
                          filled: _batchExtracted,
                          fillColor: _batchExtracted ? Colors.grey[200] : null,
                        ),
                        onChanged: (_) {
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          }
                        },
                      ),
                    ),
                    if (_nameError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          _nameError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Department — always a dropdown ─────────────────────
                    const Text(
                      'Department',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ref
                        .watch(backendConfigProvider)
                        .when(
                          data: (config) {
                              return Container(
                                height: 50,
                                decoration:
                                    AppStyle.dropdownContainerDecoration(),
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_departmentCode),
                                  initialValue: _departmentCode,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                                hint: const Text(
                                  'Select Department',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                items: config.departments.map((dept) {
                                  return DropdownMenuItem<String>(
                                    value: dept.code,
                                    child: Text(dept.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _departmentCode = value);
                                  }
                                },
                                decoration: AppStyle.dropdownInputDecoration(
                                  hintText: 'Select Department',
                                ),
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                menuMaxHeight: 220,
                              ),
                            );
                          },
                          loading: () => const SizedBox(
                            height: 50,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, stack) => SizedBox(
                            height: 50,
                            child: TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: 'Error loading departments',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),

                    // Batch ───────────────────────────────────────────────
                    const Text(
                      'Batch',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_batchExtracted) ...[
                      // Read-only if successfully extracted
                      SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _batchController,
                          enabled: false,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFD0D0D0),
                                width: 1.2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Dropdown if not extracted
                      ref
                          .watch(backendConfigProvider)
                          .when(
                            data: (config) {
                              final batches = List<int>.generate(
                                config.batchRange.end -
                                    config.batchRange.start +
                                    1,
                                (i) => config.batchRange.start + i,
                              );
                              return Container(
                                height: 50,
                                decoration:
                                    AppStyle.dropdownContainerDecoration(),
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_batchController.text),
                                  initialValue: _batchController.text.isNotEmpty
                                      ? _batchController.text
                                      : null,
                                  hint: const Text('Select Batch'),
                                  items: batches.map((batch) {
                                    return DropdownMenuItem<String>(
                                      value: batch.toString(),
                                      child: Text(batch.toString()),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(
                                        () => _batchController.text = value,
                                      );
                                    }
                                  },
                                  decoration: AppStyle.dropdownInputDecoration(
                                    hintText: 'Select Batch',
                                  ),
                                  isExpanded: true,
                                  dropdownColor: Colors.white,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  menuMaxHeight: 220,
                                ),
                              );
                            },
                            loading: () => const SizedBox(
                              height: 50,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (error, stack) => SizedBox(
                              height: 50,
                              child: TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText: 'Error loading batches',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                    const SizedBox(height: 16),

                    // Birthday ────────────────────────────────────────────
                    const Text(
                      'Campus',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: TextFormField(
                        initialValue: campusName,
                        enabled: false,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD0D0D0),
                              width: 1.2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Birthday',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: GestureDetector(
                        onTap: _handleBirthdayPicker,
                        child: TextField(
                          controller: _birthdayController,
                          enabled: false,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'MM/DD/YYYY',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFD0D0D0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_birthdayError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Text(
                          _birthdayError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Gender ──────────────────────────────────────────────
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...studently_user.Gender.values.map((gender) {
                          final bool isSelected = _selectedGender == gender;
                          final Color blue = AppStyle.primaryBlue;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedGender = gender;
                                _genderError = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? blue : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? blue
                                      : const Color(0xFFE0E6ED),
                                ),
                              ),
                              child: Text(
                                gender.displayName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    if (_genderError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          _genderError!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Next Button ─────────────────────────────────────────
                    SizedBox(
                      height: 45,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async => _handleCompletion(),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (_completionError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _completionError!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
