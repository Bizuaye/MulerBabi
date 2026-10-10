class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final double creditLimit;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.creditLimit = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'creditLimit': creditLimit,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'],
        name: m['name'],
        phone: m['phone'],
        address: m['address'],
        creditLimit: (m['creditLimit'] as num?)?.toDouble() ?? 0,
      );
}

class CreditTransaction {
  final int? id;
  final int customerId;
  final int? drugId;
  final String description;
  final double amount;
  final String date;
  final String type;

  CreditTransaction({
    this.id,
    required this.customerId,
    this.drugId,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerId': customerId,
        'drugId': drugId,
        'description': description,
        'amount': amount,
        'date': date,
        'type': type,
      };

  factory CreditTransaction.fromMap(Map<String, dynamic> m) => CreditTransaction(
        id: m['id'],
        customerId: m['customerId'],
        drugId: m['drugId'],
        description: m['description'],
        amount: (m['amount'] as num).toDouble(),
        date: m['date'],
        type: m['type'],
      );

  DateTime get dateTime => DateTime.parse(date);
}
