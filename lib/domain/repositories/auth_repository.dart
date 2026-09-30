import '../models/auth_models.dart';

/// Contract for authentication and user identity management.
/// Normalizes external identity providers (Google, Apple) and session lifecycle.
abstract interface class AuthRepository {
  /// Stream emitting the active user profile whenever authentication state changes.
  /// Emits `null` when the user is unauthenticated / logged out.
  Stream<UserProfile?> get authStateChanges;

  /// Retrieves the currently authenticated user profile, or null if anonymous.
  Future<UserProfile?> getCurrentUser();

  /// Initiates native Google Sign-In and exchanges ID token with Supabase Auth.
  /// Returns the authenticated [UserProfile], or `null` if user canceled.
  Future<UserProfile?> signInWithGoogle();

  /// Initiates native Sign in with Apple (iOS) and exchanges ID token with Supabase Auth.
  /// Returns the authenticated [UserProfile], or `null` if user canceled.
  Future<UserProfile?> signInWithApple();

  /// Signs out the active user and clears local session tokens.
  Future<void> signOut();

  /// Permanently deletes the active user's account and all cascaded data.
  /// Complies with Apple Store Guideline 5.1.1(v) and Google Play account deletion.
  Future<void> deleteAccount();
}
