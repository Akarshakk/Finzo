class User {
  final String id;
  final String name;
  final String email;
  final String? profilePicture;
  final String upiId;
  final double monthlyBudget;
  final double savingsTarget;
  final DateTime createdAt;
  final String kycStatus;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePicture,
    this.upiId = '',
    required this.monthlyBudget,
    this.savingsTarget = 0,
    required this.createdAt,
    this.kycStatus = 'NOT_STARTED',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle createdAt which may be a String, Map (Firestore Timestamp), or null
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is Map) {
        // Firestore Timestamp comes as {_seconds: xxx, _nanoseconds: xxx}
        final seconds = value['_seconds'] ?? value['seconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      return DateTime.now();
    }

    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profilePicture: json['profilePicture'],
      upiId: json['upiId'] ?? '',
      monthlyBudget: (json['monthlyBudget'] ?? 0).toDouble(),
      savingsTarget: (json['savingsTarget'] ?? 0).toDouble(),
      createdAt: parseCreatedAt(json['createdAt']),
      kycStatus: json['kycStatus'] ?? 'NOT_STARTED',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePicture': profilePicture,
      'upiId': upiId,
      'monthlyBudget': monthlyBudget,
      'savingsTarget': savingsTarget,
      'createdAt': createdAt.toIso8601String(),
      'kycStatus': kycStatus,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePicture,
    String? upiId,
    double? monthlyBudget,
    double? savingsTarget,
    DateTime? createdAt,
    String? kycStatus,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      upiId: upiId ?? this.upiId,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      savingsTarget: savingsTarget ?? this.savingsTarget,
      createdAt: createdAt ?? this.createdAt,
      kycStatus: kycStatus ?? this.kycStatus,
    );
  }
}
