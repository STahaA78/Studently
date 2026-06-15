import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/providers/carpool_provider.dart';
import 'package:studently/screens/chat_page.dart';

const List<String> fastCampuses = [
  "FAST Islamabad",
  "FAST Lahore",
  "FAST Karachi",
  "FAST Peshawar",
  "FAST Faisalabad",
  "FAST Chiniot-Faisalabad",
];

class OfferRidePage extends ConsumerStatefulWidget {
  const OfferRidePage({super.key});
  @override
  ConsumerState<OfferRidePage> createState() => _OfferRidePageState();
}

class _OfferRidePageState extends ConsumerState<OfferRidePage> {
  final _formKey = GlobalKey<FormState>();
  final _homeC = TextEditingController();
  final _chatC = TextEditingController();
  final _costC = TextEditingController(text: "0");
  String? _campus;
  String _dir = "campus_to_home";
  String _gender = "mix";
  String _vehicle = "car";
  int _seats = 3;
  bool _loading = false;
  TimeOfDay? _departureTime;

  final _days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
  final Set<String> _selDays = {};

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 15, minute: 0));
    if (t != null) setState(() => _departureTime = t);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_campus == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a FAST campus')));
      return;
    }
    if (_selDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one day')));
      return;
    }
    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select departure time')));
      return;
    }
    setState(() => _loading = true);
    final conversationId = await ref.read(carpoolOffersProvider.notifier).createOffer(
      campus: _campus!, homeLocation: _homeC.text.trim(),
      direction: _dir, vehicleType: _vehicle, availableDays: _selDays.toList(), totalSeats: _seats,
      costPerSeat: int.tryParse(_costC.text.trim()) ?? 0,
      genderPreference: _gender, groupChatName: _chatC.text.trim(),
      departureTime: _departureTime!.format(context),
    );
    setState(() => _loading = false);
    if (conversationId != null && mounted) {
      Navigator.pop(context);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conversationId,
              otherUserId: 'group',
              otherUserName: _chatC.text.trim(),
            ),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Offer a Ride", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
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

          TextFormField(controller: _homeC, decoration: const InputDecoration(labelText: "Other Location (e.g. Johar Town)"), validator: (v) => v!.isEmpty ? "Required" : null),
          const SizedBox(height: 20),

          // Direction
          const Text("Direction", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Text("FAST → Area"), selected: _dir == "campus_to_home", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() => _dir = "campus_to_home"))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(label: const Text("Area → FAST"), selected: _dir == "home_to_campus", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() => _dir = "home_to_campus"))),
          ]),
          const SizedBox(height: 20),

          // Vehicle type
          const Text("Vehicle", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_car, size: 18), SizedBox(width: 6), Text("Car")]), selected: _vehicle == "car", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() { _vehicle = "car"; _seats = 3; }))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(label: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.two_wheeler, size: 18), SizedBox(width: 6), Text("Bike")]), selected: _vehicle == "bike", selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (_) => setState(() { _vehicle = "bike"; _seats = 1; }))),
          ]),
          const SizedBox(height: 20),

          // Days
          const Text("Available Days", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: _days.map((d) => FilterChip(label: Text(d.substring(0, 3)), selected: _selDays.contains(d), selectedColor: AppStyle.primaryBlue.withOpacity(0.15), onSelected: (v) => setState(() => v ? _selDays.add(d) : _selDays.remove(d)))).toList()),
          const SizedBox(height: 20),

          // Time picker
          const Text("Departure Time", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: AppStyle.borderLight), borderRadius: BorderRadius.circular(AppStyle.formFieldRadius), color: AppStyle.backgroundLight),
              child: Row(children: [
                const Icon(Icons.access_time, color: Colors.grey),
                const SizedBox(width: 12),
                Text(_departureTime == null ? "Select Time" : _departureTime!.format(context), style: const TextStyle(fontSize: 16)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          // Seats
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Available Seats", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            Row(children: [
              IconButton(onPressed: () { if (_seats > 1) setState(() => _seats--); }, icon: const Icon(Icons.remove_circle_outline)),
              Text("$_seats", style: const TextStyle(fontSize: 18)),
              IconButton(onPressed: () { if (_seats < 6) setState(() => _seats++); }, icon: const Icon(Icons.add_circle_outline)),
            ]),
          ]),
          const SizedBox(height: 16),

          TextFormField(controller: _costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Contribution per seat (Rs.)", helperText: "Enter 0 if free")),
          const SizedBox(height: 20),

          // Gender
          const Text("Gender Preference", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ChoiceChip(label: const Text("Mix Gender"), selected: _gender == "mix", selectedColor: Colors.green.withOpacity(0.15), onSelected: (_) => setState(() => _gender = "mix"))),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(label: const Text("Same Gender"), selected: _gender == "same", selectedColor: Colors.orange.withOpacity(0.15), onSelected: (_) => setState(() => _gender = "same"))),
          ]),
          const SizedBox(height: 20),

          TextFormField(controller: _chatC, decoration: const InputDecoration(labelText: "Group Chat Name", hintText: "e.g. Johar Town Carpool Gang"), validator: (v) => v!.isEmpty ? "Required" : null),
          const SizedBox(height: 32),

          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, child: const Text("Publish Ride Offer"))),
        ])),
      ),
    );
  }
}
