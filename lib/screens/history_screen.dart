import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';
import '../database/receipt_model.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: Consumer<ReceiptProvider>(
        builder: (context, provider, child) {
          if (provider.receipts.isEmpty) {
            return const Center(child: Text("Aucun reçu trouvé"));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.receipts.length,
            itemBuilder: (context, index) {
              final receipt = provider.receipts[index];
              return Dismissible(
                key: Key(receipt.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  // Store the deleted receipt for undo
                  final deletedReceipt = receipt;
                  
                  provider.deleteReceipt(receipt.id!);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${receipt.title} supprimé'),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () {
                          // Restore the receipt
                          provider.addReceipt(deletedReceipt);
                        },
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: const Icon(Icons.receipt, color: Colors.green),
                    ),
                    title: Text(receipt.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(receipt.category),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${receipt.amount.toStringAsFixed(2)} DH", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(receipt.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
