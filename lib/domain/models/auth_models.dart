/// Pure domain entities for authentication and user profile.
/// Completely decoupled from Supabase or any third-party framework.

enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final DateTime? createdAt;

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          email == other.email &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      id.hashCode ^ displayName.hashCode ^ email.hashCode ^ avatarUrl.hashCode;

  @override
  String toString() =>
      'UserProfile(id: $id, name: $displayName, email: $email)';
}

class UserSession {
  const UserSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final UserProfile user;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSession &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          user == other.user;

  @override
  int get hashCode => accessToken.hashCode ^ user.hashCode;

  @override
  String toString() => 'UserSession(user: ${user.displayName})';
}
