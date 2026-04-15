import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'interests.dart';
import 'package:studently/models/user.dart' as studently_user;
import 'package:studently/logger.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:studently/utils/constants.dart';
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
  String? _completionError;
  String? _departmentCode; // Store the extracted department code
  bool _departmentExtracted = false; // Track if department was extracted
  bool _batchExtracted = false; // Track if batch was extracted
  
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _validateName();
    });

    // Listen to Firebase auth state changes
    // If user gets signed out (e.g., abandoned signup), navigate back to login
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) {
        logger.i("[$runtimeType] Firebase user signed out, navigating back to login");
        // Use pushReplacementNamed to safely replace the current route
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }

  void _initializeFields() {
    // Get the current Firebase user (already signed in via Google)
    final googleSignUpUser = authService.value.currentUser;
    if (googleSignUpUser != null) {
      _nameController.text = googleSignUpUser.displayName ?? '';
      
      // Extract department and batch from name
      _extractDepartmentAndBatch(_nameController.text);
    }
  }

  /// Extracts department and batch from name
  /// Example: "BSCS 2022 FAST NU LHR" -> department: "CS", batch: "2022"
  void _extractDepartmentAndBatch(String fullName) {
    logger.d("[$runtimeType] Extracting dept/batch from: $fullName");
    
    // Clean up the name
    final parts = fullName.split(' ');
    
    String department = '';
    String batch = '';
    
    // Look for patterns like BSCS, BSSE, BSIT, BSAI etc.
    for (String part in parts) {
      // Check if part starts with 'BS' and is followed by letters
      if (part.startsWith('BS') && part.length > 2) {
        // Extract letters after 'BS'
        department = part.substring(2);
        break;
      }
    }
    
    // Look for year/batch (4 digits)
    for (String part in parts) {
      if (RegExp(r'^\d{4}$').hasMatch(part)) {
        batch = part;
        break;
      }
    }
    
    setState(() {
      _departmentCode = department;
      _departmentExtracted = department.isNotEmpty;
      _batchController.text = batch;
      _batchExtracted = batch.isNotEmpty;
    });
    
    logger.d("[$runtimeType] Extracted - Department Code: $department, Batch: $batch");
  }

  Future<void> _handleBirthdayPicker() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                // Header
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
                      constraints: BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.grey),
                // Calendar
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SfDateRangePicker(
                      onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                        if (args.value is DateTime) {
                          setState(() {
                            _selectedBirthday = args.value as DateTime;
                            // Format as MM/DD/YYYY as expected by backend
                            _birthdayController.text = 
                                "${_selectedBirthday!.month}/${_selectedBirthday!.day}/${_selectedBirthday!.year}";
                            _birthdayError = null;
                          });
                          Navigator.pop(context);
                        }
                      },
                      selectionMode: DateRangePickerSelectionMode.single,
                      initialSelectedDate: _selectedBirthday,
                      // Restrict selection to past dates only
                      selectableDayPredicate: (DateTime dateTime) {
                        return dateTime.isBefore(DateTime.now());
                      },
                      backgroundColor: Colors.white,
                      monthViewSettings: DateRangePickerMonthViewSettings(
                        viewHeaderHeight: 40,
                        viewHeaderStyle: DateRangePickerViewHeaderStyle(
                          backgroundColor: const Color(0xFF1976D2),
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
                      todayHighlightColor: const Color(0xFF1976D2),
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
    final department = _departmentCode ?? ''; // Use the department code, not display name
    final batch = _batchController.text.trim();
    
    logger.i("[$runtimeType] Google Signup Completion - Name: $name, Birthday: $birthday");
    
    if (_validateBirthday() && _validateName()) {
      setState(() { _completionError = null; });
      
      // Get the Firebase user (already signed in)
      final googleSignUpUser = authService.value.currentUser;
      
      if (googleSignUpUser != null) {
        // Navigate directly to interests selection (skip email verification and additional pages)
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InterestsSelectionPage(
              initialInterests: [],
              user: studently_user.User(
                id: googleSignUpUser.uid,
                name: name,
                email: googleSignUpUser.email ?? '',
                password: '', // Empty for Google signin
                department: department,
                batch: batch,
                birthday: birthday,
                picture: googleSignUpUser.photoURL ?? '',
                interests: [],
              ),
              completeSignup: true,
            ),
          ),
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
    final Color blue = const Color(0xFF1976D2);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth =
        isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back Button and Title
              Column(
                children: [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: AppStyle.backButtonLeftPadding,
                            bottom: AppStyle.backButtonBottomPadding),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF323743),
                            size: 30,
                          ),
                          onPressed: () async {
                            // Sign out from Firebase and navigate back
                            await authService.value.signOut();
                            logger.i("[$runtimeType] Signed out from Firebase");
                            if (!context.mounted) return;
                            // Use pushReplacementNamed to safely replace the current route
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: AppStyle.signUpPageTitleLeftPadding, right: 40),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 400),
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
                              SvgPicture.asset(
                                'assets/images/logo.svg',
                                height: AppStyle.logoSize,
                              ),
                              Text(
                                'Studently',
                                style: GoogleFonts.poppins(
                                  color: blue,
                                  fontSize: AppStyle.titleFontSize,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.5,
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
              const SizedBox(height: 15),

              // Subtitle
              const Text(
                "Complete your profile",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // FORM
              SizedBox(
                width: formWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    const Text(
                      'Full Name',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 50,
                      child: TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
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
                        onChanged: (_) {
                          if (_nameError != null) setState(() => _nameError = null);
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

                    // Department (editable if not extracted)
                    const Text(
                      'Department',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    if (_departmentExtracted) ...[
                      // Read-only display if extracted - show full name from config
                      ref.watch(backendConfigProvider).when(
                        data: (config) {
                          // Find the department name for the extracted code
                          String deptName = _departmentCode!;
                          for (final dept in config.departments) {
                            if (dept.code.toUpperCase() == _departmentCode!.toUpperCase()) {
                              deptName = dept.name;
                              break;
                            }
                          }
                          return SizedBox(
                            height: 50,
                            child: TextField(
                              controller: TextEditingController(text: deptName),
                              enabled: false,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
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
                          );
                        },
                        loading: () => const SizedBox(
                          height: 50,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stack) => SizedBox(
                          height: 50,
                          child: TextField(
                            controller: TextEditingController(text: _departmentCode!),
                            enabled: false,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
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
                      ),
                    ] else ...[
                      // Editable dropdown if not extracted
                        ref.watch(backendConfigProvider).when(
                          data: (config) {
                            return SizedBox(
                              height: 50,
                              child: DropdownButtonFormField<String>(
                                initialValue: _departmentCode,
                                hint: const Text('Select Department'),
                                items: config.departments.map((dept) {
                                  return DropdownMenuItem<String>(
                                    value: dept.code,
                                    child: Text(dept.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _departmentCode = value;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
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
                      ],
                      const SizedBox(height: 16),

                      // Batch (for Google signup - editable if not extracted)
                      const Text(
                        'Batch',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      if (_batchExtracted) ...[
                        // Read-only display if extracted
                        SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _batchController,
                            enabled: false,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
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
                        // Editable dropdown if not extracted
                        ref.watch(backendConfigProvider).when(
                          data: (config) {
                            final batches = List<int>.generate(
                              config.batchRange.end - config.batchRange.start + 1,
                              (i) => config.batchRange.start + i,
                            );
                            return SizedBox(
                              height: 50,
                              child: DropdownButtonFormField<String>(
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
                                    setState(() {
                                      _batchController.text = value;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
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

                    // Birthday
                    const Text(
                      'Birthday',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
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
                                horizontal: 18, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(Icons.calendar_today),
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
                    // NEXT BUTTON
                    SizedBox(
                      height: 45,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _handleCompletion();
                        },
                        child: Text(
                          'Next',
                          style: const TextStyle(
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
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
