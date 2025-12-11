import 'dart:convert';

class ReceiptItem {
  final String name;
  final double price;

  ReceiptItem({required this.name, required this.price});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory ReceiptItem.fromMap(Map<String, dynamic> map) {
    return ReceiptItem(
      name: map['name'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
    );
  }
}

class Receipt {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String imagePath;
  final List<ReceiptItem> items; // New field

  Receipt({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.imagePath,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'imagePath': imagePath,
      'items': jsonEncode(items.map((e) => e.toMap()).toList()), // Store as JSON string
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    List<ReceiptItem> loadedItems = [];
    if (map['items'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['items']);
        loadedItems = decoded.map((e) => ReceiptItem.fromMap(e)).toList();
      } catch (e) {
        // Handle legacy data or error
      }
    }

    return Receipt(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
      imagePath: map['imagePath'],
      items: loadedItems,
    );
  }
  
  String get formattedDate {
    return "${date.day}/${date.month}/${date.year}";
  }
}
