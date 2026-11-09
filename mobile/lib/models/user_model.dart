/// User model representing the authenticated DevOps engineer
/// Matches Vinuka's GET /api/me response & Supabase Auth session
class UserModel {
  final String id;
  final String email;
  final String role;
  final String? name;
  final String? accessToken;

  UserModel({
    required this.id,
    required this.email,
    this.role = 'DevOps Engineer',
    this.name,
    this.accessToken,
  });

  /// Factory from Vinuka's GET /api/me endpoint:
  /// {
  ///   "success": true,
  ///   "message": "Authentication successful!",
  ///   "user": { "id": "USER_UUID", "email": "user@example.com" }
  /// }
  factory UserModel.fromApiMe(Map<String, dynamic> json, {String? token}) {
    final userData = json['user'] as Map<String, dynamic>? ?? json;
    final email = userData['email']?.toString() ?? 'engineer@devops.local';
    final extractedName = email.split('@').first.replaceAll('.', ' ');

    return UserModel(
      id: userData['id']?.toString() ?? 'usr-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      role: userData['role']?.toString() ?? 'DevOps Engineer',
      name: userData['name']?.toString() ?? _capitalize(extractedName),
      accessToken: token,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'DevOps Engineer',
      name: json['name']?.toString(),
      accessToken: json['access_token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'name': name,
      'access_token': accessToken,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }
}
