import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/friends/data/supabase_friend_repository.dart';
import '../../features/friends/domain/repositories/friend_repository.dart';
import '../../features/profile/data/supabase_profile_repository.dart';
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
