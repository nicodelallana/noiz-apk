import 'dart:async';

import 'package:bizkaia_transit/data/adapters/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class FakePostgrestFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  FakePostgrestFilterBuilder([this._value]);
  final T? _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue,
      {Function? onError}) {
    return Future<T?>.value(_value)
        .then((v) => onValue(v as T), onError: onError);
  }

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    return Future<T?>.value(_value).then((v) => v as T).whenComplete(action);
  }

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) {
    return Future<T?>.value(_value)
        .then((v) => v as T)
        .catchError(onError, test: test);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthRepositoryImpl authRepo;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockGoogleSignIn = MockGoogleSignIn();

    when(() => mockSupabase.auth).thenReturn(mockAuth);

    authRepo = AuthRepositoryImpl(
      supabaseClient: mockSupabase,
      googleSignIn: mockGoogleSignIn,
    );
  });

  group('AuthRepositoryImpl', () {
    test('signInWithGoogle returns null when user cancels dialog', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final result = await authRepo.signInWithGoogle();

      expect(result, isNull);
      verify(() => mockGoogleSignIn.signIn()).called(1);
      verifyNever(() => mockAuth.signInWithIdToken(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
          ));
    });

    test(
        'signInWithGoogle exchanges idToken with Supabase and returns UserProfile',
        () async {
      final mockAccount = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();

      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockAccount);
      when(() => mockAccount.authentication)
          .thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.idToken).thenReturn('google_id_token_123');
      when(() => mockGoogleAuth.accessToken)
          .thenReturn('google_access_token_456');

      final fakeUser = User(
        id: 'user_uuid_789',
        appMetadata: {},
        userMetadata: {
          'full_name': 'Nicolas Pascual',
          'avatar_url': 'https://lh3.googleusercontent.com/photo.jpg',
        },
        aud: 'authenticated',
        email: 'nicolas@example.com',
        createdAt: '2026-09-30T08:00:00Z',
      );

      final fakeResponse = AuthResponse(
        session: Session(
          accessToken: 'sb_access_token',
          tokenType: 'bearer',
          user: fakeUser,
        ),
        user: fakeUser,
      );

      when(() => mockAuth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: 'google_id_token_123',
            accessToken: 'google_access_token_456',
          )).thenAnswer((_) async => fakeResponse);

      final profile = await authRepo.signInWithGoogle();

      expect(profile, isNotNull);
      expect(profile!.id, 'user_uuid_789');
      expect(profile.displayName, 'Nicolas Pascual');
      expect(profile.email, 'nicolas@example.com');
      expect(profile.avatarUrl, 'https://lh3.googleusercontent.com/photo.jpg');
    });

    test('deleteAccount calls delete_user_account RPC and signs out', () async {
      final fakeUser = User(
        id: 'user_uuid_789',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-09-30T08:00:00Z',
      );

      when(() => mockAuth.currentUser).thenReturn(fakeUser);
      when(() => mockSupabase.rpc<void>('delete_user_account'))
          .thenAnswer((_) => FakePostgrestFilterBuilder<void>());
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authRepo.deleteAccount();

      verify(() => mockSupabase.rpc<void>('delete_user_account')).called(1);
      verify(() => mockAuth.signOut()).called(1);
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });

    test('signOut terminates Google and Supabase sessions', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authRepo.signOut();

      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockAuth.signOut()).called(1);
    });
  });
}
