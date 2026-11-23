import 'dart:convert';

/// Represents the currently authenticated user.
class AppUser {
  final int id;
  final String name;
  final String email;

  /// Creates a profile containing the account identifier, display name and email.
  AppUser({required this.id, required this.name, required this.email});

  /// Reads either a backend authentication response or a locally cached profile.
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final info = json['user_info'] ?? {};

    return AppUser(
      id: (json['user_id'] ?? json['id'] ?? 0) as int,
      name: info['name'] ?? json['name'] ?? 'Unknown',
      email: info['email'] ?? json['email'] ?? 'No Email',
    );
  }

  /// Serializes the supported profile fields for account-specific local caching.
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'email': email};

  /// Encodes the local profile schema without retired birthdate fields.
  String toJsonString() => json.encode(toMap());
}
