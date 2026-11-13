import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/awards/data/supabase_awards_repository.dart';
import '../../features/awards/domain/awards.dart';
import '../../features/bestie_court/data/supabase_court_repository.dart';
import '../../features/bestie_court/domain/court_case.dart';
import '../../features/bluff/data/supabase_bluff_repository.dart';
import '../../features/bluff/domain/bluff_round.dart';
import '../../features/confessions/data/supabase_confession_repository.dart';
import '../../features/confessions/domain/confession.dart';
import '../../features/contracts/data/supabase_contract_repository.dart';
import '../../features/contracts/domain/friendship_contract.dart';
import '../../features/notifications/data/supabase_notification_repository.dart';
import '../../features/notifications/domain/app_notification.dart';
import '../../features/social/data/supabase_social_repository.dart';
import '../../features/social/domain/social_ping.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/friends/data/supabase_friend_repository.dart';
import '../../features/friends/domain/entities/friend_summary.dart';
import '../../features/friends/domain/repositories/friend_repository.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
import '../../features/profile/domain/entities/profile.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/roast_battle/data/supabase_roast_battle_repository.dart';
import '../../features/roast_battle/domain/entities/battle_view.dart';
import '../../features/roast_battle/domain/repositories/roast_battle_repository.dart';

/// Composition root. Only this file knows concrete implementations, which keeps
/// the Domain layer pure and makes repositories swappable with fakes in tests.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

final StreamProvider<AuthState> authStateChangesProvider =
    StreamProvider<AuthState>((Ref ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Current authenticated user; rebuilds whenever auth state changes.
final Provider<User?> currentUserProvider = Provider<User?>((Ref ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

final Provider<FriendRepository> friendRepositoryProvider =
    Provider<FriendRepository>((Ref ref) {
  return SupabaseFriendRepository(ref.watch(supabaseClientProvider));
});

final Provider<RoastBattleRepository> roastBattleRepositoryProvider =
    Provider<RoastBattleRepository>((Ref ref) {
  return SupabaseRoastBattleRepository(ref.watch(supabaseClientProvider));
});

/// My profile (display name, invite code, wins...).
final FutureProvider<Profile> myProfileProvider = FutureProvider<Profile>(
  (Ref ref) => ref.watch(profileRepositoryProvider).fetchMyProfile(),
);

/// Friendship coin balance (server-authoritative, read-only in the client).
final FutureProvider<int> myCoinBalanceProvider = FutureProvider<int>(
  (Ref ref) => ref.watch(profileRepositoryProvider).fetchMyCoinBalance(),
);

final FutureProvider<List<FriendSummary>> friendsProvider =
    FutureProvider<List<FriendSummary>>(
  (Ref ref) => ref.watch(friendRepositoryProvider).fetchFriends(),
);


/// Matches that are still open for me (waiting / active / voting).
final FutureProvider<List<MatchSummary>> openMatchesProvider =
    FutureProvider<List<MatchSummary>>(
  (Ref ref) => ref.watch(roastBattleRepositoryProvider).fetchOpenMatches(),
);

final Provider<BluffRepository> bluffRepositoryProvider =
    Provider<BluffRepository>((Ref ref) {
  return SupabaseBluffRepository(ref.watch(supabaseClientProvider));
});

final Provider<CourtRepository> courtRepositoryProvider =
    Provider<CourtRepository>((Ref ref) {
  return SupabaseCourtRepository(ref.watch(supabaseClientProvider));
});

final Provider<ContractRepository> contractRepositoryProvider =
    Provider<ContractRepository>((Ref ref) {
  return SupabaseContractRepository(ref.watch(supabaseClientProvider));
});

final Provider<ConfessionRepository> confessionRepositoryProvider =
    Provider<ConfessionRepository>((Ref ref) {
  return SupabaseConfessionRepository(ref.watch(supabaseClientProvider));
});

final Provider<SocialRepository> socialRepositoryProvider =
    Provider<SocialRepository>((Ref ref) {
  return SupabaseSocialRepository(ref.watch(supabaseClientProvider));
});

final Provider<AwardsRepository> awardsRepositoryProvider =
    Provider<AwardsRepository>((Ref ref) {
  return SupabaseAwardsRepository(ref.watch(supabaseClientProvider));
});

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>((Ref ref) {
  return SupabaseNotificationRepository(ref.watch(supabaseClientProvider));
});

/// Unread inbox badge.
final FutureProvider<int> unreadNotificationsProvider = FutureProvider<int>(
  (Ref ref) => ref.watch(notificationRepositoryProvider).fetchUnreadCount(),
);
