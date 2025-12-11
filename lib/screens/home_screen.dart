import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';
import '../database/receipt_model.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  
  @override
  void initState() {
    super.initState();
    // Load data when screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReceiptProvider>(context, listen: false).loadReceipts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Dépenses'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: Consumer<ReceiptProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
             return const Center(child: CircularProgressIndicator());
          }
          
          final receipts = provider.receipts;
          final totalSpending = provider.totalSpending;
          final uniqueCategories = receipts.map((e) => e.category).toSet().length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Statistiques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatCard("Total Reçus", "${receipts.length}", Icons.receipt, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard("Catégories", "$uniqueCategories", Icons.category, Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Dépenses Totales", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text("${totalSpending.toStringAsFixed(2)} DH", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text("Dépenses Récentes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...receipts.take(5).map((receipt) => _buildTransactionItem(receipt)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Receipt receipt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(receipt.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(receipt.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text("-${receipt.amount.toStringAsFixed(2)} DH", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }
}
