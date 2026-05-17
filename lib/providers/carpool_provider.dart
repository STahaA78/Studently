import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studently/models/ride.dart';
import 'package:studently/repositories/carpool.dart';

// ========== OFFERS PROVIDER ==========
class CarpoolOffersNotifier extends AsyncNotifier<List<RideOffer>> {
  String? lastError;

  @override
  Future<List<RideOffer>> build() async {
    final repo = ref.read(carpoolRepositoryProvider);
    return await repo.getActiveOffers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      state = AsyncData(await repo.getActiveOffers());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<String?> createOffer({
    required String campus,
    required String homeLocation,
    required String direction,
    required String vehicleType,
    required List<String> availableDays,
    required int totalSeats,
    required int costPerSeat,
    required String genderPreference,
    required String groupChatName,
    required String departureTime,
  }) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      final result = await repo.createOffer(
        campus: campus,
        homeLocation: homeLocation,
        direction: direction,
        vehicleType: vehicleType,
        availableDays: availableDays,
        totalSeats: totalSeats,
        costPerSeat: costPerSeat,
        genderPreference: genderPreference,
        groupChatName: groupChatName,
        departureTime: departureTime,
      );
      await refresh();
      ref.invalidate(myOffersProvider);
      return result['conversation_id'];
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  Future<bool> joinOffer(String offerId) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.joinOffer(offerId);
      await refresh();
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }
}

// ========== REQUESTS PROVIDER ==========
class CarpoolRequestsNotifier extends AsyncNotifier<List<RideRequest>> {
  String? lastError;

  @override
  Future<List<RideRequest>> build() async {
    final repo = ref.read(carpoolRepositoryProvider);
    return await repo.getActiveRequests();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      state = AsyncData(await repo.getActiveRequests());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> createRequest({
    required String campus,
    required String otherLocation,
    required String direction,
    required String genderPreference,
    required DateTime neededDatetime,
  }) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.createRequest(
        campus: campus,
        otherLocation: otherLocation,
        direction: direction,
        genderPreference: genderPreference,
        neededDatetime: neededDatetime,
      );
      await refresh();
      ref.invalidate(myRequestsProvider);
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<Map<String, dynamic>?> contactRequester(String requestId) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      return await repo.contactRequester(requestId);
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }
}

final carpoolOffersProvider =
    AsyncNotifierProvider<CarpoolOffersNotifier, List<RideOffer>>(
  () => CarpoolOffersNotifier(),
);

final carpoolRequestsProvider =
    AsyncNotifierProvider<CarpoolRequestsNotifier, List<RideRequest>>(
  () => CarpoolRequestsNotifier(),
);

// ========== MY OFFERS PROVIDER ==========
class MyOffersNotifier extends AsyncNotifier<List<RideOffer>> {
  @override
  Future<List<RideOffer>> build() async {
    final repo = ref.read(carpoolRepositoryProvider);
    return await repo.getMyOffers();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      state = AsyncData(await repo.getMyOffers());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> reactivate(String id) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.reactivateOffer(id);
      await refresh();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deactivate(String id) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.deactivateOffer(id);
      await refresh();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> delete(String id) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.deleteOffer(id);
      await refresh();
      return true;
    } catch (_) { return false; }
  }
}

// ========== MY REQUESTS PROVIDER ==========
class MyRequestsNotifier extends AsyncNotifier<List<RideRequest>> {
  @override
  Future<List<RideRequest>> build() async {
    final repo = ref.read(carpoolRepositoryProvider);
    return await repo.getMyRequests();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      state = AsyncData(await repo.getMyRequests());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<bool> reactivate(String id) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.reactivateRequest(id);
      await refresh();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deactivate(String id) async {
    try {
      final repo = ref.read(carpoolRepositoryProvider);
      await repo.deactivateRequest(id);
      await refresh();
      return true;
    } catch (_) { return false; }
  }
}

final myOffersProvider =
    AsyncNotifierProvider<MyOffersNotifier, List<RideOffer>>(
  () => MyOffersNotifier(),
);

final myRequestsProvider =
    AsyncNotifierProvider<MyRequestsNotifier, List<RideRequest>>(
  () => MyRequestsNotifier(),
);
