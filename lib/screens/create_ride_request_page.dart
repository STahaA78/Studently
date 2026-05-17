import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/providers/carpool_provider.dart';
import 'package:studently/screens/offer_ride_page.dart' show fastCampuses;
import 'package:intl/intl.dart';

class CreateRideRequestPage extends ConsumerStatefulWidget {
  const CreateRideRequestPage({super.key});
  @override
  ConsumerState<CreateRideRequestPage> createState() => _State();
}

class _State extends ConsumerState<CreateRideRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _locC = TextEditingController();
  String? _campus;
  String _dir = "campus_to_other";
  String _gender = "mix";
  DateTime? _date;
  TimeOfDay? _time;
  bool _loading = false;

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (d != null) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (t != null) setState(() { _date = d; _time = t; });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_campus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a FAST campus')));
      return;
    }
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select date & time')));
      return;
    }
    setState(() => _loading = true);
    final dt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    final ok = await ref.read(carpoolRequestsProvider.notifier).createRequest(
      campus: _campus!, otherLocation: _locC.text.trim(),
      direction: _dir, genderPreference: _gender, neededDatetime: dt,
    );
    setState(() => _loading = false);
    if (ok && mounted) Navigator.pop(context);
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Request a Ride", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Campus dropdown
          const Text("FAST Campus", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppStyle.formFieldRadius),
              border: Border.all(color: AppStyle.borderLight),
              color: AppStyle.backgroundLight,
            ),
            child: DropdownButtonFormField<String>(
              value: _campus,
              hint: const Text("Select Campus"),
              isExpanded: true,
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: fastCampuses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _campus = val),
              validator: (val) => val == null ? "Required" : null,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(controller: _locC, decoration: const InputDecoration(labelText: "Other Location"), validator: (v) => v!.isEmpty ? "Required" : null),
          const SizedBox(height: 20),

          const Text("Direction", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Text("FAST → Other"), selected: _dir == "campus_to_other", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() => _dir = "campus_to_other"))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(label: const Text("Other → FAST"), selected: _dir == "other_to_campus", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() => _dir = "other_to_campus"))),
          ]),
          const SizedBox(height: 20),

          const Text("When do you need the ride?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: AppStyle.borderLight), borderRadius: BorderRadius.circular(AppStyle.formFieldRadius), color: AppStyle.backgroundLight),
              child: Row(children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 12),
                Text(_date == null ? "Select Date & Time" : "${DateFormat('MMM d, yyyy').format(_date!)} at ${_time!.format(context)}", style: const TextStyle(fontSize: 16)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          const Text("Gender Preference", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Text("Mix Gender"), selected: _gender == "mix", selectedColor: Colors.green.withOpacity(0.15), onSelected: (_) => setState(() => _gender = "mix"))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(label: const Text("Same Gender"), selected: _gender == "same", selectedColor: Colors.orange.withOpacity(0.15), onSelected: (_) => setState(() => _gender = "same"))),
          ]),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: const Text("Post Request"))),
        ])),
      ),
    );
  }
}
