/// The signed-in user, as returned by /api/auth/login and /api/profile.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String role;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        role: json['role'] as String? ?? 'User',
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
      );
}
