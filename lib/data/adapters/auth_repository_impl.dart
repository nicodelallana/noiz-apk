import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/auth_models.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository] integrating with Supabase Auth,
/// Google Sign-In, and Sign in with Apple.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    SupabaseClient? supabaseClient,
    GoogleSignIn? googleSignIn,
  })  : _supabase = supabaseClient ?? _tryGetSupabaseClient(),
        _injectedGoogleSignIn = googleSignIn;

  final SupabaseClient? _supabase;
  final GoogleSignIn? _injectedGoogleSignIn;

  // Created on first use: on the web the constructor initialises Google
  // Identity Services straight away, which throws without a web client ID.
  late final GoogleSignIn _googleSignIn =
      _injectedGoogleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']);

  static SupabaseClient? _tryGetSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    final client = _supabase;
    if (client == null) {
      return Stream.value(null);
    }
    return client.auth.onAuthStateChange.map((authState) {
      final user = authState.session?.user;
      if (user == null) return null;
      return _mapSupabaseUserToProfile(user);
    });
  }

  @override
  Future<UserProfile?> getCurrentUser() async {
    final client = _supabase;
    if (client == null) return null;
    final user = client.auth.currentUser;
    if (user == null) return null;

    // Attempt to read profile from profiles table first
    try {
      final response = await client
          .from('profiles')
          .select('id, display_name, avatar_url, created_at')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserProfile(
          id: response['id'] as String,
          displayName: (response['display_name'] as String?) ?? 'Usuario',
          email: user.email,
          avatarUrl: response['avatar_url'] as String?,
          createdAt: response['created_at'] != null
              ? DateTime.parse(response['created_at'] as String)
              : null,
        );
      }
    } catch (_) {
      // Fallback to auth.user metadata if network/table error
    }

    return _mapSupabaseUserToProfile(user);
  }

  @override
  Future<UserProfile?> signInWithGoogle() async {
    final client = _supabase;
    if (client == null) {
      throw const AuthException('Supabase no está configurado en este entorno.');
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled login dialog gracefully
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw const AuthException('No Google ID Token available.');
      }

      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = authResponse.user;
      if (user == null) return null;
      return _mapSupabaseUserToProfile(user);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  @override
  Future<UserProfile?> signInWithApple() async {
    final client = _supabase;
    if (client == null) {
      throw const AuthException('Supabase no está configurado en este entorno.');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('No Apple identity token returned.');
      }

      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      final user = authResponse.user;
      if (user == null) return null;

      // Update profile with Apple full name if provided on first login
      if (credential.givenName != null || credential.familyName != null) {
        final fullName = [credential.givenName, credential.familyName]
            .where((n) => n != null && n.isNotEmpty)
            .join(' ');
        if (fullName.isNotEmpty) {
          try {
            await client.from('profiles').update({
              'display_name': fullName,
            }).eq('id', user.id);
          } catch (_) {}
        }
      }

      return _mapSupabaseUserToProfile(user);
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        // User canceled dialog gracefully
        return null;
      }
      throw AuthException(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    final client = _supabase;
    await Future.wait([
      // On the web the session is Supabase's; don't create the Google client
      // (and trigger its initialisation) just to sign out.
      if (!kIsWeb || _injectedGoogleSignIn != null) _googleSignIn.signOut(),
      if (client != null) client.auth.signOut(),
    ]);
  }

  @override
  Future<void> deleteAccount() async {
    final client = _supabase;
    if (client == null) return;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Call server-side RPC function which cascades deletion across all tables
    await client.rpc<void>('delete_user_account');

    // Clean up local session
    await signOut();
  }

  UserProfile _mapSupabaseUserToProfile(User user) {
    final metadata = user.userMetadata ?? {};
    final displayName = (metadata['full_name'] as String?) ??
        (metadata['name'] as String?) ??
        (user.email != null ? user.email!.split('@').first : 'Usuario');
    final avatarUrl =
        (metadata['avatar_url'] as String?) ?? (metadata['picture'] as String?);

    return UserProfile(
      id: user.id,
      displayName: displayName,
      email: user.email,
      avatarUrl: avatarUrl,
      createdAt: DateTime.tryParse(user.createdAt),
    );
  }
}
