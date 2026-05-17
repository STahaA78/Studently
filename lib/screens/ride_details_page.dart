import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/ride.dart';
import 'package:studently/providers/carpool_provider.dart';
import 'package:studently/providers/auth_provider.dart';

class RideDetailsPage extends ConsumerStatefulWidget {
  final RideOffer? offer;
  final RideRequest? request;
  const RideDetailsPage({super.key, this.offer, this.request});
  @override
  ConsumerState<RideDetailsPage> createState() => _State();
}

class _State extends ConsumerState<RideDetailsPage> {
  bool _loading = false;

  void _joinRide() async {
    if (widget.offer == null) return;
    setState(() => _loading = true);
    final ok = await ref.read(carpoolOffersProvider.notifier).joinOffer(widget.offer!.id);
    setState(() => _loading = false);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined! Check group chat in DMs.')));
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(carpoolOffersProvider.notifier).lastError ?? 'Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).value?.id;
    final offer = widget.offer;

    return Scaffold(
      backgroundColor: AppStyle.backgroundLight,
      appBar: AppBar(title: const Text("Ride Details", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, iconTheme: const IconThemeData(color: Colors.black)),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: offer != null ? _buildOfferDetails(offer, uid) : const Center(child: Text("No details")),
      ),
    );
  }

  Widget _buildOfferDetails(RideOffer offer, String? uid) {
    final isDriver = offer.driverId == uid;
    final hasJoined = offer.passengers.contains(uid);
    final isFull = offer.availableSeats <= 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Route card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppStyle.borderLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Route", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Icon(offer.direction == 'campus_to_home' ? Icons.school : Icons.home, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(offer.direction == 'campus_to_home' ? offer.campus : offer.homeLocation, style: const TextStyle(fontSize: 16))),
          ]),
          const Padding(padding: EdgeInsets.only(left: 11, top: 4, bottom: 4), child: Icon(Icons.more_vert, color: Colors.grey, size: 20)),
          Row(children: [
            Icon(offer.direction == 'campus_to_home' ? Icons.home : Icons.school, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(offer.direction == 'campus_to_home' ? offer.homeLocation : offer.campus, style: const TextStyle(fontSize: 16))),
          ]),
        ]),
      ),
      const SizedBox(height: 16),

      // Details card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppStyle.borderLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row(Icons.person, "Driver", offer.driverName),
          const SizedBox(height: 10),
          _row(Icons.event_seat, "Seats", "${offer.availableSeats} of ${offer.totalSeats}"),
          const SizedBox(height: 10),
          _row(Icons.payments, "Cost", offer.costPerSeat == 0 ? "Free" : "Rs. ${offer.costPerSeat}/seat"),
          const SizedBox(height: 10),
          _row(Icons.people, "Gender", offer.genderPreference == 'same' ? 'Same Gender Only' : 'Mix Gender'),
        ]),
      ),
      const SizedBox(height: 16),

      // Days
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppStyle.borderLight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Available Days", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: offer.availableDays.map((d) => Chip(label: Text(d), backgroundColor: AppStyle.primaryBlue.withOpacity(0.08))).toList()),
        ]),
      ),
      const SizedBox(height: 24),

      // Actions
      if (!isDriver && !hasJoined && !isFull)
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _joinRide, child: const Text("Join Ride"))),
      if (hasJoined)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Text("You've joined! Check DMs for the group chat.", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
      if (isFull && !hasJoined && !isDriver)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Text("This ride is full.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      if (isDriver)
        const Padding(padding: EdgeInsets.all(12), child: Text("This is your ride offer.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
    ]);
  }

  Widget _row(IconData icon, String title, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.grey, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 16)),
      ])),
    ]);
  }
}
