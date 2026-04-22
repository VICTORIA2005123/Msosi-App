class User {
  final String id;
  final String name;
  final String email;
  final String? token;
  final bool isAdmin;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.token,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      email: json['email'],
      token: json['token'],
      isAdmin: json['is_admin'] == 1 || json['is_admin'] == true || json['email'] == 'admin@msosi.com',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
      'is_admin': isAdmin ? 1 : 0,
    };
  }
}
