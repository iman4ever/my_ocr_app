import 'package:flutter/material.dart';
import '../database/receipt_model.dart';
import '../database/database_helper.dart';

class ReceiptProvider with ChangeNotifier {
  List<Receipt> _receipts = [];
  bool _isLoading = false;

  List<Receipt> get receipts => _receipts;
  bool get isLoading => _isLoading;

  Future<void> loadReceipts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _receipts = await DatabaseHelper.instance.readAllReceipts();
    } catch (e) {
      print("Error loading receipts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReceipt(Receipt receipt) async {
    await DatabaseHelper.instance.create(receipt);
    await loadReceipts(); // Refresh list
  }

  Future<void> deleteReceipt(int id) async {
    // Optimistic update: Remove from UI immediately to satisfy Dismissible
    _receipts.removeWhere((element) => element.id == id);
    notifyListeners();
    
    try {
      await DatabaseHelper.instance.delete(id);
    } catch (e) {
      print("Error deleting receipt: $e");
      // Optionally rollback if delete fails, but unlikely for local DB
      await loadReceipts(); 
    }
  }
  
  double get totalSpending {
    return _receipts.fold(0, (sum, item) => sum + item.amount);
  }
  
  Map<String, double> get spendingByCategory {
    Map<String, double> stats = {};
    for (var receipt in _receipts) {
       stats[receipt.category] = (stats[receipt.category] ?? 0) + receipt.amount;
    }
    return stats;
  }
}
