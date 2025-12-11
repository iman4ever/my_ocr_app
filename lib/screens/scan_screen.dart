import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';
import '../database/receipt_model.dart';
import '../utils/receipt_parser.dart';
import 'package:intl/intl.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool _isBusy = false;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
        await _processImage(InputImage.fromFilePath(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // FIX: Sort text lines top-to-bottom to ensure correct reading order
      final String sortedText = ReceiptParser.getSortedText(recognizedText);
      print("DEBUG: SORTED OCR TEXT:\n$sortedText\n----------------------");
      
      final double detectedAmount = ReceiptParser.extractAmount(sortedText);
      final DateTime detectedDate = ReceiptParser.extractDate(sortedText);
      final String detectedTitle = ReceiptParser.extractMerchant(sortedText);
      final List<ReceiptItem> detectedItems = ReceiptParser.extractItems(sortedText);
      
      if (mounted) {
        _showEditDialog(detectedTitle, detectedAmount, detectedDate, _image!.path, detectedItems);
      }
      
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de reconnaissance: $e')));
    }
  }
  
  void _showEditDialog(String title, double amount, DateTime date, String imagePath, List<ReceiptItem> items) {
    final titleController = TextEditingController(text: title);
    final amountController = TextEditingController(text: amount.toString());
    final List<ReceiptItem> currentItems = List.from(items); // Mutable copy
    
    String selectedCategory = "Général";
    DateTime selectedDate = date;
    
    final List<String> categories = ["Alimentation", "Général", "Transport", "Shopping", "Factures", "Santé"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder to update list
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85, // Taller modal
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Confirmer les détails", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: "Marchand/Titre", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: "Montant Total", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 20),
                    const Text("Articles détectés:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Appuyez sur un article pour le modifier ou le supprimer",
                              style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300)
                        ),
                        child: currentItems.isEmpty 
                           ? const Center(child: Text("Aucun article détecté. Ajouter manuellement?"))
                           : ListView.builder(
                               itemCount: currentItems.length,
                                itemBuilder: (ctx, idx) {
                                  final item = currentItems[idx];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item.name, overflow: TextOverflow.ellipsis),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("${item.price.toStringAsFixed(2)} DH"),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                          onPressed: () {
                                             setModalState(() {
                                               currentItems.removeAt(idx);
                                               // Auto-update total? Optional. Let's keep total manual for now as OCR might miss items.
                                             });
                                          },
                                        )
                                      ],
                                    ),
                                    onTap: () async {
                                      // Show edit dialog
                                      final nameController = TextEditingController(text: item.name);
                                      final priceController = TextEditingController(text: item.price.toStringAsFixed(2));
                                      
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Modifier l'article"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                controller: nameController,
                                                decoration: const InputDecoration(labelText: "Nom de l'article"),
                                              ),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: priceController,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                decoration: const InputDecoration(labelText: "Prix (DH)"),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text("Annuler"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                final newName = nameController.text.trim();
                                                final newPrice = double.tryParse(priceController.text) ?? item.price;
                                                
                                                if (newName.isNotEmpty) {
                                                  setModalState(() {
                                                    currentItems[idx] = ReceiptItem(name: newName, price: newPrice);
                                                  });
                                                }
                                                Navigator.pop(ctx);
                                              },
                                              child: const Text("Enregistrer"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                             ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Add Item Button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final nameController = TextEditingController();
                        final priceController = TextEditingController();
                        
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text("Ajouter un article"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(labelText: "Nom de l'article"),
                                  autofocus: true,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: "Prix (DH)"),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Annuler"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final newName = nameController.text.trim();
                                  final newPrice = double.tryParse(priceController.text) ?? 0.0;
                                  
                                  if (newName.isNotEmpty && newPrice > 0) {
                                    setModalState(() {
                                      currentItems.add(ReceiptItem(name: newName, price: newPrice));
                                    });
                                  }
                                  Navigator.pop(ctx);
                                },
                                child: const Text("Ajouter"),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Ajouter un article"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(labelText: "Catégorie", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setModalState(() => selectedCategory = v!),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                         final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                         if (d != null) setModalState(() => selectedDate = d);
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                           final double finalAmount = double.tryParse(amountController.text) ?? 0.0;
                           if (finalAmount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Montant invalide")));
                              return;
                           }
                           
                           final newReceipt = Receipt(
                             title: titleController.text.isEmpty ? "Inconnu" : titleController.text,
                             amount: finalAmount,
                             date: selectedDate,
                             category: selectedCategory,
                             imagePath: imagePath,
                             items: currentItems, // Save the items!
                           );
                           
                           Provider.of<ReceiptProvider>(context, listen: false).addReceipt(newReceipt);
                           Navigator.pop(context);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reçu enregistré!")));
                        },
                        child: const Text("ENREGISTRER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                     const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             if (_isBusy) const CircularProgressIndicator() else ...[
               Container(
                 padding: const EdgeInsets.all(20),
                 decoration: const BoxDecoration(
                   color: Colors.white,
                   shape: BoxShape.circle,
                   boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]
                 ),
                 child: const Icon(Icons.qr_code_scanner, size: 80, color: Colors.green),
               ),
               const SizedBox(height: 40),
               ElevatedButton.icon(
                 icon: const Icon(Icons.camera_alt),
                 label: const Text("Scanner un reçu"),
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                   textStyle: const TextStyle(fontSize: 18),
                 ),
                 onPressed: () => _pickImage(ImageSource.camera),
               ),
               const SizedBox(height: 16),
               TextButton.icon(
                 icon: const Icon(Icons.image),
                 label: const Text("Importer de la galerie"),
                 onPressed: () => _pickImage(ImageSource.gallery),
               )
             ]
          ],
        ),
      ),
    );
  }
}
