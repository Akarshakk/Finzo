class GroupMember {
  final String userId;
  final String name;
  final String email;
  final String upiId; // Member's UPI ID for settlements (optional)
  final double amountOwed; // How much this user owes in total
  final double amountLent; // How much this user has lent

  GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    this.upiId = '',
    this.amountOwed = 0.0,
    this.amountLent = 0.0,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      upiId: json['upiId'] ?? '',
      amountOwed: (json['amountOwed'] ?? 0).toDouble(),
      amountLent: (json['amountLent'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'upiId': upiId,
      'amountOwed': amountOwed,
      'amountLent': amountLent,
    };
  }

  double get balance => amountLent - amountOwed;
}

class GroupExpenseSplit {
  final String memberId;
  final String memberName;
  final double amount;

  GroupExpenseSplit({
    required this.memberId,
    required this.memberName,
    required this.amount,
  });

  factory GroupExpenseSplit.fromJson(Map<String, dynamic> json) {
    return GroupExpenseSplit(
      memberId: json['memberId'] ?? '',
      memberName: json['memberName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'amount': amount,
    };
  }
}

class GroupExpense {
  final String id;
  final String groupId;
  final String paidBy; // userId
  final String paidByName;
  final double amount;
  final String description;
  final List<GroupExpenseSplit> splits;
  final DateTime date;
  final String category;

  GroupExpense({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.paidByName,
    required this.amount,
    required this.description,
    required this.splits,
    required this.date,
    required this.category,
  });

  factory GroupExpense.fromJson(Map<String, dynamic> json) {
    return GroupExpense(
      id: json['_id'] ?? json['id'] ?? '',  // MongoDB uses _id
      groupId: json['groupId'] ?? '',
      paidBy: json['paidBy'] ?? '',
      paidByName: json['paidByName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      splits: (json['splits'] as List<dynamic>?)
          ?.map((e) => GroupExpenseSplit.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      category: json['category'] ?? 'others',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'amount': amount,
      'description': description,
      'splits': splits.map((e) => e.toJson()).toList(),
      'date': date.toIso8601String(),
      'category': category,
    };
  }
}

class Group {
  final String id;
  final String name;
  final String description;
  final List<GroupMember> members;
  final List<GroupExpense> expenses;
  final DateTime createdAt;
  final String createdBy;
  final String imageUrl;
  final String inviteCode;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.expenses,
    required this.createdAt,
    required this.createdBy,
    this.imageUrl = '',
    this.inviteCode = '',
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['_id'] ?? json['id'] ?? '',  // MongoDB uses _id
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      members: (json['members'] as List<dynamic>?)
          ?.map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      expenses: (json['expenses'] as List<dynamic>?)
          ?.map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      inviteCode: json['inviteCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'members': members.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'imageUrl': imageUrl,
      'inviteCode': inviteCode,
    };
  }

  double getTotalExpenses() {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> getSettlements() {
    Map<String, double> settlements = {};
    
    for (var member in members) {
      settlements[member.userId] = member.balance;
    }
    
    return settlements;
  }
}


