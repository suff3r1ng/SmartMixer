class AppUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? fullName; // Adding fullName field to match app_state usage
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime? updatedAt; // Added updatedAt field
  final DateTime? lastSignIn;

  AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.fullName,
    required this.isAdmin,
    required this.createdAt,
    this.updatedAt,
    this.lastSignIn,
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? fullName,
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSignIn,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSignIn: lastSignIn ?? this.lastSignIn,
    );
  }

  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName!;
    } else if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return email.split('@').first; // Use the part before @ as a fallback name
    }
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      email: map['email'] ?? '',
      firstName: map['first_name'],
      lastName: map['last_name'],
      fullName: map['full_name'],
      isAdmin: map['is_admin'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt:
          map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      lastSignIn: map['last_sign_in_at'] != null
          ? DateTime.parse(map['last_sign_in_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'is_admin': isAdmin,
    };
  }
}
