import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/user.dart';
import 'package:studently/logger.dart';
import 'package:studently/screens/interests.dart';
import 'package:studently/providers/backend_config_provider.dart';
import 'package:studently/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupAdditionalPage extends ConsumerStatefulWidget {
  final User user;
  const SignupAdditionalPage({super.key, required this.user});

  @override
  ConsumerState<SignupAdditionalPage> createState() => _SignupAdditionalPageState();
}

class _SignupAdditionalPageState extends ConsumerState<SignupAdditionalPage> {
  String? selectedDate; // MM/DD/YYYY
  String? selectedDepartment;
  String? selectedBatch;

  String? _dateError;
  String? _departmentError;
  String? _batchError;

  @override
  void initState() {
    super.initState();
  }

  bool _validateAdditional() {
    final missing = <String>[];
    if (selectedDate == null) missing.add('Birthday');
    if (selectedDepartment == null || selectedDepartment!.isEmpty) missing.add('Department');
    if (selectedBatch == null || selectedBatch!.isEmpty) missing.add('Batch');

    setState(() {
      _dateError = selectedDate == null ? 'Please select your birthday' : null;
      _departmentError = (selectedDepartment == null || selectedDepartment!.isEmpty) ? 'Please select department' : null;
      _batchError = (selectedBatch == null || selectedBatch!.isEmpty) ? 'Please select batch' : null;
    });

    widget.user.birthday = selectedDate;
    widget.user.department = selectedDepartment;
    widget.user.batch = selectedBatch;

    return missing.isEmpty;
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
    );
    if (picked != null && context.mounted) {
      setState(() {
        selectedDate = '${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year}';
        widget.user.birthday = selectedDate;
        _dateError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color blue = const Color(0xFF1976D2);
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double formWidth = isLandscape ? screenSize.width * 0.6 : screenSize.width * 0.85;

    final configAsyncValue = ref.watch(backendConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              // Back Button Row (left aligned)
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: AppStyle.backButtonLeftPadding, bottom: AppStyle.backButtonBottomPadding),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF323743),
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              // Title (left aligned)
              Padding(
                padding: const EdgeInsets.only(left: AppStyle.signUpPageTitleLeftPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Let\'s Get Started',
                    style: GoogleFonts.poppins(
                      fontSize: AppStyle.signUpPageHeadingFontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppStyle.signUpPageTitleLeftPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'We need your basics to build your profile.',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              configAsyncValue.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text('Failed to load configuration'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.refresh(backendConfigProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (config) => SizedBox(
                  width: formWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Birthday', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _pickDate(context),
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _dateError != null ? Colors.redAccent : Colors.grey.shade300, width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(selectedDate ?? 'Select your birthday', style: TextStyle(fontSize: 15, color: selectedDate == null ? Colors.grey : Colors.black)),
                                const Icon(Icons.calendar_today, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                        if (_dateError != null) Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_dateError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                        const SizedBox(height: 20),

                        const Text('Department', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(height: 6),
                        _buildStyledDropdown<String>(
                          hint: 'Select your department',
                          value: selectedDepartment,
                          items: config.departments.map((dept) => dept.name).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDepartment = value;
                              widget.user.department = value;
                              _departmentError = null;
                            });
                          },
                        ),
                        if (_departmentError != null) Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_departmentError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                        const SizedBox(height: 20),

                        const Text('Batch', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        const SizedBox(height: 6),
                        _buildStyledDropdown<String>(
                          hint: 'Select your batch',
                          value: selectedBatch,
                          items: List.generate(
                            config.batchRange.end - config.batchRange.start + 1,
                            (index) => (config.batchRange.start + index).toString(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              selectedBatch = value;
                              widget.user.batch = value;
                              _batchError = null;
                            });
                          },
                        ),
                        if (_batchError != null) Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_batchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          height: 45,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_validateAdditional()) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => InterestsSelectionPage(
                                      initialInterests: widget.user.interests,
                                      user: widget.user,
                                      completeSignup: true,
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                            ),
                            child: const Text('Next', style: TextStyle(fontSize: 18, color: Colors.white)),
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
        );
  }

  Widget _buildStyledDropdown<T>({
    required String hint,
    required T? value,
    required List<String> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8)),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
        hint: Text(hint, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        items: items.map((item) => DropdownMenuItem<T>(value: item as T, child: Text(item, style: const TextStyle(fontSize: 15)))).toList(),
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(20),
        menuMaxHeight: 220,
      ),
    );
  }
}