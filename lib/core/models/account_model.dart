class AccountModel {
  final String id;
  final String name; // "Cash", "HDFC Bank"
  final String type; // "Cash", "Bank", "Card"
  final double balance;
  final String icon; // Icon string identifier

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.icon = 'wallet',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'icon': icon,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Wallet',
      type: map['type'] ?? 'Cash',
      balance: (map['balance'] ?? 0).toDouble(),
      icon: map['icon'] ?? 'wallet',
    );
  }
}