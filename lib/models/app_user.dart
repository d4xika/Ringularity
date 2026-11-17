import 'dart:convert';

/// Represents the currently authenticated user.
class AppUser {
  final int id;
  final String name;
  final String email;

  AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final info = json['user_info'] ?? {};

    return AppUser(
      id: (json['user_id'] ?? json['id'] ?? 0) as int,
      name: info['name'] ?? json['name'] ?? 'Unknown',
      email: info['email'] ?? json['email'] ?? 'No Email',
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'email': email};

  String toJsonString() => json.encode(toMap());
}
