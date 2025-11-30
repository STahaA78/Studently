import 'package:flutter/material.dart';
import 'signup_email_verification_page.dart';
import 'package:studently/models.dart';
import 'package:studently/logger.dart';
import 'package:email_otp/email_otp.dart';

class SignupAdditionalPage extends StatefulWidget {
  final User user;
  const SignupAdditionalPage({super.key, required this.user});

  @override
  State<SignupAdditionalPage> createState() => _SignupAdditionalPageState();
}

class _SignupAdditionalPageState extends State<SignupAdditionalPage> {
  String? selectedDate; // MM/DD/YYYY
  String? selectedDepartment;
  String? selectedBatch;
  final List<String> departments = ['Computer Science', 'IT', 'ECE', 'Mechanical'];
  final List<String> batches = ['2022', '2023', '2024', '2025'];
  List<String> interests = ['Programming', 'Gaming'];
  final TextEditingController _interestController = TextEditingController();

  String? _dateError;
  String? _departmentError;
  String? _batchError;
  String? _interestsError;

  @override
  void initState() {
    super.initState();
    // Sync initial interests to User object
    widget.user.interests = List.from(interests);
  }

  bool _validateAdditional() {
    final missing = <String>[];
    if (selectedDate == null) missing.add('Birthday');
    if (selectedDepartment == null || selectedDepartment!.isEmpty) missing.add('Department');
    if (selectedBatch == null || selectedBatch!.isEmpty) missing.add('Batch');
    if (interests.isEmpty) missing.add('Interests');

    setState(() {
      _dateError = selectedDate == null ? 'Please select your birthday' : null;
      _departmentError = (selectedDepartment == null || selectedDepartment!.isEmpty) ? 'Please select department' : null;
      _batchError = (selectedBatch == null || selectedBatch!.isEmpty) ? 'Please select batch' : null;
      _interestsError = interests.isEmpty ? 'Please add at least one interest' : null;
    });

    // Always update final state of User before sending OTP/API
    widget.user.birthday = selectedDate;
    widget.user.department = selectedDepartment;
    widget.user.batch = selectedBatch;
    widget.user.interests = List.from(interests);

    return missing.isEmpty;
  }

  Future<bool> _sendOtp() async {
    logger.i("[$runtimeType] SendOTP Started");
    logger.d("[$runtimeType] Email: ${widget.user.email}");
    try {
      await EmailOTP.sendOTP(email: widget.user.email);
      logger.i("[$runtimeType] OTP sent successfully to ${widget.user.email}");
    } catch (e) {
      logger.e("[$runtimeType] Failed to send OTP to ${widget.user.email}", error: e);
      return false;
    }
    return true;
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                const Text('Almost Done!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Help us personalize your experience by\nproviding a few more details.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: formWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // Birthday
                      const Text('Birthday', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedDate ?? 'Pick a date', style: const TextStyle(fontSize: 15)),
                              const Icon(Icons.calendar_today, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      if (_dateError != null) Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_dateError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      const SizedBox(height: 20),

                      // Department Dropdown
                      const Text('Department', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 6),
                      _buildStyledDropdown<String>(
                        hint: 'Select your department',
                        value: selectedDepartment,
                        items: departments,
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

                      // Batch Dropdown
                      const Text('Batch', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 6),
                      _buildStyledDropdown<String>(
                        hint: 'Select your batch',
                        value: selectedBatch,
                        items: batches,
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
                      const SizedBox(height: 20),

                      // Interests
                      const Text('Interests', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...interests.map((interest) => Chip(
                            label: Text(interest),
                            deleteIcon: const Icon(Icons.close),
                            backgroundColor: blue.withOpacity(0.2),
                            onDeleted: () {
                              setState(() {
                                interests.remove(interest);
                                widget.user.interests = List.from(interests);
                                if (interests.isNotEmpty) _interestsError = null;
                              });
                            },
                          )),
                          GestureDetector(
                            onTap: () async {
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Add Interest'),
                                  content: TextField(controller: _interestController, decoration: const InputDecoration(hintText: 'Enter new interest')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                    TextButton(onPressed: () {
                                      setState(() {
                                        if (_interestController.text.isNotEmpty) {
                                          interests.add(_interestController.text);
                                          widget.user.interests = List.from(interests);
                                          _interestsError = null;
                                        }
                                        _interestController.clear();
                                      });
                                      Navigator.pop(ctx);
                                    }, child: const Text('Add')),
                                  ],
                                ),
                              );
                            },
                            child: const Icon(Icons.add, color: Colors.blue),
                          ),
                        ],
                      ),
                      if (_interestsError != null) Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_interestsError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                      ),
                      const SizedBox(height: 30),

                      // Complete Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!_validateAdditional()) return;
                            bool otpSent = await _sendOtp();
                            if (!otpSent || !context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SignupEmailVerificationPage(user: widget.user),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Text('Complete Sign Up', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
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
