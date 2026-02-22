import 'dart:convert';

/// Represents the currently authenticated user.
class AppUser {
  final int id;
  final String name;
  final String email;
  final DateTime birthday;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.birthday,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final info = json['user_info'] ?? {};

    return AppUser(
      id: (json['user_id'] ?? json['id'] ?? 0) as int,
      name: info['name'] ?? json['name'] ?? 'Unknown',
      email: info['email'] ?? json['email'] ?? 'No Email',
      birthday:
          DateTime.tryParse(info['birthday'] ?? json['birthday'] ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'birthday': birthday.toIso8601String(),
  };

  String toJsonString() => json.encode(toMap());
}
