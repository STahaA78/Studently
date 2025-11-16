import 'package:flutter/material.dart';
import 'signup_email_verification_page.dart'; // Import for navigation

class SignupAdditionalPage extends StatefulWidget {
  const SignupAdditionalPage({super.key});

  @override
  State<SignupAdditionalPage> createState() => _SignupAdditionalPageState();
}

class _SignupAdditionalPageState extends State<SignupAdditionalPage> {
  DateTime? selectedDate;
  String? selectedDepartment;
  String? selectedBatch;
  final List<String> departments = ['Computer Science', 'IT', 'ECE', 'Mechanical'];
  final List<String> batches = ['2022', '2023', '2024', '2025'];
  final List<String> interests = ['Programming', 'Gaming'];
  final TextEditingController _interestController = TextEditingController();

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                // ===== Header =====
                const Text(
                  'Almost Done!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Help us personalize your experience by\nproviding a few more details.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 30),

                // ===== Form =====
                SizedBox(
                  width: formWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ===== Birthday =====
                      const Text(
                        'Birthday',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? 'Pick a date'
                                    : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const Icon(Icons.calendar_today, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ===== Department =====
                      const Text(
                        'Department',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      _buildStyledDropdown<String>(
                        hint: 'Select your department',
                        value: selectedDepartment,
                        items: departments,
                        onChanged: (value) => setState(() => selectedDepartment = value),
                      ),
                      const SizedBox(height: 20),

                      // ===== Batch =====
                      const Text(
                        'Batch',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      _buildStyledDropdown<String>(
                        hint: 'Select your batch',
                        value: selectedBatch,
                        items: batches,
                        onChanged: (value) => setState(() => selectedBatch = value),
                      ),
                      const SizedBox(height: 20),

                      // ===== Interests =====
                      const Text(
                        'Interests',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.transparent,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ...interests.map(
                              (interest) => Chip(
                                label: Text(interest),
                                deleteIcon: const Icon(Icons.close),
                                backgroundColor: blue.withOpacity(0.2),
                                onDeleted: () {
                                  setState(() {
                                    interests.remove(interest);
                                  });
                                },
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Add Interest'),
                                    content: TextField(
                                      controller: _interestController,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter new interest',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            if (_interestController.text.isNotEmpty) {
                                              interests.add(_interestController.text);
                                            }
                                            _interestController.clear();
                                          });
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text('Add'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Icon(Icons.add, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // ===== Complete Sign Up Button =====
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupEmailVerificationPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Complete Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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

  ///  Stylish Dropdown Builder
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        isExpanded: true,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
        hint: Text(
          hint,
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item as T,
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(20), // Rounded popup
        menuMaxHeight: 220,
      ),
    );
  }
}
