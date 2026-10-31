import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../storage/local_chat_storage.dart';
import '../../models/user_model.dart';

/// Sync status for Profile Data Loading Sequence
enum ProfileSyncState {
  initial,
  loadingCache,
  syncing, // Background fetching from authorized API
  synced, // Reconciled with server & local storage updated
  offline, // Offline / server unreachable; retaining cached data
}

/// Immutable state containing the user profile and current sync status
class ProfileDataState {
  final UserModel? profile;
  final ProfileSyncState syncState;
  final String? syncError;
  final DateTime? lastSyncedAt;

  const ProfileDataState({
    this.profile,
    this.syncState = ProfileSyncState.initial,
    this.syncError,
    this.lastSyncedAt,
  });

  bool get isOffline => syncState == ProfileSyncState.offline;
  bool get isSyncing => syncState == ProfileSyncState.syncing;
  bool get hasData => profile != null;

  ProfileDataState copyWith({
    UserModel? profile,
    ProfileSyncState? syncState,
    String? syncError,
    DateTime? lastSyncedAt,
  }) {
    return ProfileDataState(
      profile: profile ?? this.profile,
      syncState: syncState ?? this.syncState,
      syncError: syncError,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

/// Notifier implementing the 6-step Profile Data Loading Sequence:
/// 1. Open profile: receives userId from caller
/// 2. Read SQLite / Local Storage: load cached profile and render immediately (0ms)
/// 3. Fetch API: request latest authorized profile data in background
/// 4. Reconcile: validate response and update local profile record
/// 5. Reactive refresh: Riverpod observes database stream and refreshes UI
/// 6. Handle failures: retain cached data if offline and show subtle sync status
class ProfileNotifier extends Notifier<ProfileDataState> {
  final int userId;
  final UserModel? initialUser;
  StreamSubscription<UserModel>? _dbStreamSub;

  ProfileNotifier(this.userId, {this.initialUser});

  @override
  ProfileDataState build() {
    ref.onDispose(() {
      _dbStreamSub?.cancel();
    });

    _initSequence();

    return ProfileDataState(
      profile: initialUser,
      syncState: initialUser != null
          ? ProfileSyncState.syncing
          : ProfileSyncState.loadingCache,
    );
  }

  Future<void> _initSequence() async {
    // Step 5: Reactive refresh - Riverpod observes the database stream
    _dbStreamSub = LocalChatStorage.instance
        .watchUserProfile(userId)
        .listen((updatedRecord) {
      state = state.copyWith(profile: updatedRecord);
    });

    // Step 2: Read SQLite / local cache and render immediately (0ms wait)
    final cached = await LocalChatStorage.instance.getCachedUserProfile(userId);
    if (cached != null) {
      state = state.copyWith(
        profile: cached,
        syncState: ProfileSyncState.syncing,
      );
    } else if (initialUser != null) {
      // Seed initial record into local storage
      unawaited(LocalChatStorage.instance.saveUserProfile(initialUser!));
    }

    // Step 3 & 4: Fetch authorized profile in background and reconcile
    await _fetchAndReconcile();
  }

  /// Manually re-sync / pull to refresh
  Future<void> refresh() async {
    state = state.copyWith(
      syncState: ProfileSyncState.syncing,
      syncError: null,
    );
    await _fetchAndReconcile();
  }

  Future<void> _fetchAndReconcile() async {
    try {
      // Step 3: Fetch API in background
      final serverProfile = await ApiClient.instance.getUserProfile(userId);

      // Step 4: Reconcile - validate response & persist to local SQLite / storage
      await LocalChatStorage.instance.saveUserProfile(serverProfile);

      state = state.copyWith(
        profile: serverProfile,
        syncState: ProfileSyncState.synced,
        lastSyncedAt: DateTime.now(),
        syncError: null,
      );
    } catch (e) {
      // Step 6: Handle failures: retain cached data if offline, show subtle sync status
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      state = state.copyWith(
        syncState: ProfileSyncState.offline,
        syncError: errorMsg.isNotEmpty
            ? errorMsg
            : 'Offline. Showing cached profile.',
      );
    }
  }
}

/// Riverpod family provider for any userId
final profileNotifierProvider =
    NotifierProvider.family<ProfileNotifier, ProfileDataState, int>(
  (userId) => ProfileNotifier(userId),
);
