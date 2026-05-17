import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/app_style.dart';
import 'package:studently/models/ride.dart';
import 'package:studently/providers/carpool_provider.dart';
import 'package:studently/widgets/custom_nav_bar.dart';
import 'package:studently/screens/offer_ride_page.dart';
import 'package:studently/screens/create_ride_request_page.dart';
import 'package:studently/screens/ride_details_page.dart';
import 'package:studently/screens/chat_page.dart';
import 'package:intl/intl.dart';

class CarpoolFeedPage extends ConsumerStatefulWidget {
  const CarpoolFeedPage({super.key});

  @override
  ConsumerState<CarpoolFeedPage> createState() => _CarpoolFeedPageState();
}

class _CarpoolFeedPageState extends ConsumerState<CarpoolFeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "What would you like to do?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_car),
                label: const Text("Offer a Ride"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const OfferRidePage()));
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_pin_circle),
                label: const Text("Request a Ride"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateRideRequestPage()));
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Carpool",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: AppStyle.appBarTitleSize,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppStyle.primaryBlue),
            onPressed: _showCreateSheet,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppStyle.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppStyle.primaryBlue,
          tabs: const [
            Tab(text: "Offers"),
            Tab(text: "Requests"),
            Tab(text: "My Listings"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OffersTab(),
          _RequestsTab(),
          _MyListingsTab(),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 3),
    );
  }
}

// ======== OFFERS TAB ========
class _OffersTab extends ConsumerWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOffers = ref.watch(carpoolOffersProvider);

    return asyncOffers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
      data: (offers) {
        if (offers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("No ride offers right now.",
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(carpoolOffersProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) =>
                _OfferCard(offer: offers[index]),
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final RideOffer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RideDetailsPage(offer: offer)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppStyle.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route
            Row(
              children: [
                Icon(
                    offer.direction == 'campus_to_home'
                        ? Icons.school
                        : Icons.home,
                    color: AppStyle.primaryBlue,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offer.direction == 'campus_to_home'
                        ? "${offer.campus} → ${offer.homeLocation}"
                        : "${offer.homeLocation} → ${offer.campus}",
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Driver name + vehicle
            Row(children: [
              Text("by ${offer.driverName}",
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 8),
              Icon(offer.vehicleType == 'bike' ? Icons.two_wheeler : Icons.directions_car, color: Colors.grey, size: 16),
              const SizedBox(width: 3),
              Text(offer.vehicleType == 'bike' ? 'Bike' : 'Car', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ]),
            const SizedBox(height: 10),
            // Days chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: offer.availableDays
                  .map((d) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppStyle.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(d,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppStyle.primaryBlue,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            // Departure time
            if (offer.departureTime.isNotEmpty)
              Row(children: [
                const Icon(Icons.access_time, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text("Leaves at ${offer.departureTime}",
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            if (offer.departureTime.isNotEmpty)
              const SizedBox(height: 10),
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.event_seat, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text("${offer.availableSeats} seats",
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13)),
                ]),
                Text(
                  offer.costPerSeat == 0
                      ? "Free"
                      : "Rs. ${offer.costPerSeat}/seat",
                  style: TextStyle(
                    color: offer.costPerSeat == 0
                        ? Colors.green
                        : AppStyle.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: offer.genderPreference == 'same'
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    offer.genderPreference == 'same'
                        ? "Same Gender"
                        : "Mix",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: offer.genderPreference == 'same'
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======== REQUESTS TAB ========
class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRequests = ref.watch(carpoolRequestsProvider);

    return asyncRequests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text("Error: $err")),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text("No ride requests right now.",
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.read(carpoolRequestsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _RequestCard(request: requests[index]),
          ),
        );
      },
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final RideRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('EEE, MMM d • h:mm a')
      .format(request.neededDatetime.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyle.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  request.direction == 'campus_to_other'
                      ? Icons.school
                      : Icons.location_on,
                  color: AppStyle.primaryBlue,
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.direction == 'campus_to_other'
                      ? "${request.campus} → ${request.otherLocation}"
                      : "${request.otherLocation} → ${request.campus}",
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("by ${request.requesterName}",
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Text(timeStr,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: request.genderPreference == 'same'
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.genderPreference == 'same'
                      ? "Same Gender"
                      : "Mix",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: request.genderPreference == 'same'
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await ref
                      .read(carpoolRequestsProvider.notifier)
                      .contactRequester(request.id);
                  if (result != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          conversationId: result['conversation_id'],
                          otherUserId: result['requester_id'],
                          otherUserName: result['requester_name'],
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.message, size: 16),
                label: const Text("Message"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ======== MY LISTINGS TAB ========
class _MyListingsTab extends ConsumerWidget {
  const _MyListingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOffers = ref.watch(myOffersProvider);
    final asyncRequests = ref.watch(myRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(myOffersProvider.notifier).refresh();
        await ref.read(myRequestsProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("My Ride Offers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          asyncOffers.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Text("Error: $e"),
            data: (offers) {
              if (offers.isEmpty) return const Text("No offers yet.", style: TextStyle(color: Colors.grey));
              return Column(children: offers.map((o) => _MyOfferCard(offer: o)).toList());
            },
          ),
          const SizedBox(height: 24),
          const Text("My Ride Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          asyncRequests.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Text("Error: $e"),
            data: (requests) {
              if (requests.isEmpty) return const Text("No requests yet.", style: TextStyle(color: Colors.grey));
              return Column(children: requests.map((r) => _MyRequestCard(request: r)).toList());
            },
          ),
        ],
      ),
    );
  }
}

class _MyOfferCard extends ConsumerWidget {
  final RideOffer offer;
  const _MyOfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInactive = offer.status == 'inactive';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isInactive ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isInactive ? Colors.orange.shade200 : AppStyle.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            offer.direction == 'campus_to_home' ? "${offer.campus} → ${offer.homeLocation}" : "${offer.homeLocation} → ${offer.campus}",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isInactive ? Colors.orange.withOpacity(0.15) : (offer.status == 'full' ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isInactive ? "Inactive" : (offer.status == 'full' ? "Full" : "Active"),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isInactive ? Colors.orange : (offer.status == 'full' ? Colors.red : Colors.green)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text("${offer.availableSeats}/${offer.totalSeats} seats • ${offer.costPerSeat == 0 ? 'Free' : 'Rs. ${offer.costPerSeat}/seat'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (isInactive)
            TextButton.icon(
              onPressed: () async {
                await ref.read(myOffersProvider.notifier).reactivate(offer.id);
                ref.invalidate(carpoolOffersProvider);
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Reactivate"),
            ),
          if (!isInactive && offer.status != 'full')
            TextButton.icon(
              onPressed: () async {
                await ref.read(myOffersProvider.notifier).deactivate(offer.id);
                ref.invalidate(carpoolOffersProvider);
              },
              icon: const Icon(Icons.pause_circle_outline, size: 16),
              label: const Text("Deactivate"),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Ride?"),
                  content: const Text("This will delete the ride and associated group chat. This cannot be undone."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                  ],
                ),
              ) ?? false;
              if (confirmed) {
                await ref.read(myOffersProvider.notifier).delete(offer.id);
                ref.invalidate(carpoolOffersProvider);
              }
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text("Delete"),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ]),
      ]),
    );
  }
}

class _MyRequestCard extends ConsumerWidget {
  final RideRequest request;
  const _MyRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInactive = request.status == 'inactive';
    final timeStr = DateFormat('MMM d • h:mm a').format(request.neededDatetime.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isInactive ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isInactive ? Colors.orange.shade200 : AppStyle.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            request.direction == 'campus_to_other' ? "${request.campus} → ${request.otherLocation}" : "${request.otherLocation} → ${request.campus}",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isInactive ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isInactive ? "Expired" : "Active",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isInactive ? Colors.orange : Colors.green),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text("Needed: $timeStr", style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (!isInactive)
            TextButton.icon(
              onPressed: () async {
                await ref.read(myRequestsProvider.notifier).deactivate(request.id);
                ref.invalidate(carpoolRequestsProvider);
              },
              icon: const Icon(Icons.close, size: 16),
              label: const Text("Take Down"),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
        ]),
      ]),
    );
  }
}
