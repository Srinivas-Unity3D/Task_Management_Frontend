class User {
  final String userId;
  final String username;
  final String email;
  final String phone;
  final String role;
  final String? fcmToken;
  
  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    this.fcmToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      fcmToken: json['fcm_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
      'fcm_token': fcmToken,
    };
  }
} 