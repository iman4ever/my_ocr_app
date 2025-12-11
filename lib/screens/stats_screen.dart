import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/receipt_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses par Catégorie'),
        backgroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: Consumer<ReceiptProvider>(
        builder: (context, provider, child) {
          final data = provider.spendingByCategory;
          
          if (data.isEmpty) {
             return const Center(child: Text("Aucune donnée à afficher"));
          }
          
          return Column(
            children: [
              const SizedBox(height: 32),
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _buildPieSections(data),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildLegend(data)),
            ],
          );
        },
      ),
    );
  }
  
  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final List<Color> colors = [Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.red, Colors.teal];
    int i = 0;
    
    return data.entries.map((entry) {
      final color = colors[i % colors.length];
      i++;
      final double value = entry.value;
      
      return PieChartSectionData(
        color: color,
        value: value,
        title: '${value.toInt()}DH',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }
  
  Widget _buildLegend(Map<String, double> data) {
    final List<Color> colors = [Colors.blue, Colors.orange, Colors.purple, Colors.green, Colors.red, Colors.teal];
    int i = 0;
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: data.entries.map((entry) {
         final color = colors[i % colors.length];
         i++;
         return Container(
           margin: const EdgeInsets.only(bottom: 12),
           child: Row(
             children: [
               Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
               const SizedBox(width: 12),
               Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
               const Spacer(),
               Text("${entry.value.toStringAsFixed(2)} DH"),
             ],
           ),
         );
      }).toList(),
    );
  }
}
