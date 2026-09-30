import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/adapters/auth_repository_impl.dart';
import '../../domain/models/auth_models.dart';
import '../../domain/repositories/auth_repository.dart';

/// Provider exposing the authentication repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Stream of auth state changes (UserProfile? or null if unauthenticated).
final authStateStreamProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Current authenticated user profile.
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});

/// Controller handling user authentication actions and loading/error states.
class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo, this._ref) : super(const AsyncValue.data(null));

  final AuthRepository _repo;
  final Ref _ref;

  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithGoogle();
      state = const AsyncValue.data(null);
      if (user != null) {
        _ref.invalidate(currentUserProfileProvider);
        return true;
      }
      return false; // User canceled
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithApple();
      state = const AsyncValue.data(null);
      if (user != null) {
        _ref.invalidate(currentUserProfileProvider);
        return true;
      }
      return false; // User canceled
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repo.signOut();
      _ref.invalidate(currentUserProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteAccount();
      _ref.invalidate(currentUserProfileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo, ref);
});
