import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/user.dart';
import 'package:studently/providers/discover_provider.dart';
import 'package:studently/screens/profile_main.dart';
import 'package:studently/widgets/custom_nav_bar.dart';

class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  final Color primaryBlue = const Color(0xFF0F74C5);

  Future<void> _handleRespond(User user, String action) async {
    final success = await ref
        .read(discoverRequestsProvider.notifier)
        .respondRequest(user.id, action);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to respond to request.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(discoverRequestsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, requestsState.didChangeRequests);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.black),
            onPressed: () =>
                Navigator.pop(context, requestsState.didChangeRequests),
          ),
          centerTitle: true,
          title: const Text(
            'Pending Requests',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
          ),
        ),
        body: Builder(
          builder: (context) {
            if (requestsState.isLoading &&
                !requestsState.hasLoadedRequests) {
              return const Center(child: CircularProgressIndicator());
            }

            if (requestsState.errorMessage != null &&
                !requestsState.hasLoadedRequests) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Connection Issue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We couldn't reach our Backend. Please check your internet and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => ref
                              .read(discoverRequestsProvider.notifier)
                              .refreshRequests(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final requests = requestsState.requests;
            if (requests.isEmpty) {
              return const Center(
                child: Text(
                  'No pending requests',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(requests[index], requestsState);
              },
            );
          },
        ),
        bottomNavigationBar: const CustomNavBar(currentIndex: 1),
      ),
    );
  }

  Widget _buildRequestCard(User user, DiscoverRequestsState state) {
    final isProcessing = state.inFlightRequestIds.contains(user.id);

    return GestureDetector(
      onTap: isProcessing
          ? null
          : () async {
              final bool? changed = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage(userId: user.id)),
              );

              if (changed == true && mounted) {
                ref.read(discoverRequestsProvider.notifier).markChanged();
                await ref
                    .read(discoverRequestsProvider.notifier)
                    .refreshRequests(showLoading: false);
              }
            },
      child: Opacity(
        opacity: isProcessing ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    user.picture != null && user.picture!.isNotEmpty
                        ? NetworkImage(user.picture!)
                        : null,
                child: user.picture == null || user.picture!.isEmpty
                    ? const Icon(Icons.person, size: 32, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${user.department?.name ?? 'N/A'} • Batch ${user.batch}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isProcessing
                    ? null
                    : () => _handleRespond(user, 'reject'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Icon(Icons.close, color: Colors.red, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isProcessing
                    ? null
                    : () => _handleRespond(user, 'accept'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryBlue,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
