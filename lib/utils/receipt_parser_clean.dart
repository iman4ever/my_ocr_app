import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../database/receipt_model.dart';

class ReceiptParser {
  // Normalize common OCR mistakes to improve parsing accuracy
  static String _normalizeOcr(String text) {
    if (text.isEmpty) return text;
    String s = text;
    s = s.replaceAll('\r', '\n');
    s = s.replaceAll('\t', ' ');
    s = s.replaceAllMapped(RegExp(r'(?<=\D)O(?=\d)'), (m) => '0');
    s = s.replaceAllMapped(RegExp(r'(?<=\d)O(?=\D)'), (m) => '0');
    s = s.replaceAllMapped(RegExp(r'(?<=\s)O(?=\s)'), (m) => '0');
    s = s.replaceAll(',', '.');
    s = s.replaceAll(RegExp(r'\s+(DH|MAD)\b', caseSensitive: false), ' DH');
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    s = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
    return s;
  }

  static List<ReceiptItem> extractItems(String text) {
    text = _normalizeOcr(text);
    List<ReceiptItem> items = [];
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'([0-9]+[.,][0-9]{2})');
    
    print("DEBUG: Extracting Items from ${lines.length} lines...");
    
    // Skip header lines until we find "OPERATION" or first price
    int startIndex = 0;
    for (int i = 0; i < lines.length && i < 15; i++) {
      String lower = lines[i].toLowerCase();
      if (lower.contains('operation') || lower.contains('vente') || priceRegex.hasMatch(lines[i])) {
        startIndex = i;
        break;
      }
    }
    
    print("DEBUG: Item scan starting at line $startIndex");
    
    String? pendingName;
    
    for (int i = startIndex; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      String lower = line.toLowerCase();
      
      // STOP at footer keywords
      if (lower.contains('paiement') || lower.contains('paienent') || 
          lower.contains('ventilation') || lower.contains('nombre article')) {
        print("DEBUG: Hit footer section '$line'. Stopping.");
        break;
      }
      
      // Skip lines that are pure metadata/noise
      if (lower.contains('operation') || lower.contains('vente') ||
          lower.contains('total') || lower.contains('change') || 
          lower.contains('espece') || lower.contains('rendu') ||
          lower.contains('timbre') || lower.contains('droit') ||
          lower.contains('tva') || lower.contains('merci') ||
          lower.contains('telephone') || lower.contains('fax') ||
          lower.contains('patente') || lower.contains('ice')) {
        print("  -> Skipped: Metadata line '$line'");
        continue;
      }
      
      // Try to find a price in this line
      final matches = priceRegex.allMatches(line);
      if (matches.isNotEmpty) {
        // Use the LAST price (usually the total item price, not unit price)
        String priceStr = matches.last.group(1)!.replaceAll(',', '.');
        double? price = double.tryParse(priceStr);
        
        if (price != null && price > 0.1) {  // Ignore tiny amounts (0.01, 0.06)
          // Extract name (everything before the price)
          String name = line.substring(0, matches.last.start).trim();
          
          // Clean up: remove leading numbers like "2 1.20 2.40" -> keep "2.40" as price
          name = name.replaceAll(RegExp(r'^\d+\s*'), '').trim();
          name = name.replaceAll(RegExp(r'[()0-9>]+'), '').trim();  // Remove barcodes
          
          // If previous line was a name with no price, merge them
          if (pendingName != null && name.isEmpty) {
            name = pendingName;
            pendingName = null;
          }
          
          if (name.length > 2) {
            print("  -> ITEM: '$name' -> $price");
            items.add(ReceiptItem(name: name, price: price));
            pendingName = null;
          }
        }
      } else {
        // No price on this line — might be a name for the next line
        if (line.length > 3 && !lower.startsWith('x ')) {
          print("  -> Pending name: '$line'");
          pendingName = line;
        }
      }
    }
    
    return items;
  }

  static String getSortedText(RecognizedText recognizedText) {
    List<TextLine> allLines = [];
    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    
    allLines.sort((a, b) {
      int yDiff = a.boundingBox.top.toInt() - b.boundingBox.top.toInt();
      if (yDiff.abs() < 20) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return yDiff;
    });

    if (allLines.isEmpty) return "";

    List<String> mergedLines = [];
    List<TextLine> currentRow = [allLines.first];
    
    for (int i = 1; i < allLines.length; i++) {
        TextLine current = allLines[i];
        TextLine previous = currentRow.last; 
        
        if ((current.boundingBox.top - previous.boundingBox.top).abs() < 24) {
            currentRow.add(current);
        } else {
            currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
            mergedLines.add(currentRow.map((e) => e.text).join(" ")); 
            currentRow = [current];
        }
    }
    currentRow.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    mergedLines.add(currentRow.map((e) => e.text).join(" "));

    return mergedLines.join('\n');
  }

  static double extractAmount(String text) {
    if (text.isEmpty) return 0.0;
    text = _normalizeOcr(text);
    final lowerText = text.toLowerCase();
    final lines = lowerText.split('\n');
    
    print("DEBUG: --- START EXTRACT AMOUNT ---");
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.contains('total') || line.contains('ttc')) {
        final RegExp priceRegex = RegExp(r'([0-9]+[.,][0-9]{2})');
        final matches = priceRegex.allMatches(line);
        if (matches.isNotEmpty) {
          String priceStr = matches.last.group(1)!.replaceAll(',', '.');
          double? price = double.tryParse(priceStr);
          if (price != null && price > 0.1) {
            print("DEBUG: Found total: $price");
            return price;
          }
        }
      }
    }
    
    return 0.0;
  }

  static DateTime extractDate(String text) {
    text = _normalizeOcr(text);
    final RegExp dateRegex = RegExp(r'(\d{2}[/.-]\d{2}[/.-]\d{4})|(\d{4}[/.-]\d{2}[/.-]\d{2})');
    final matches = dateRegex.allMatches(text);
    
    for (var match in matches) {
      try {
        String dateStr = match.group(0)!;
        dateStr = dateStr.replaceAll('.', '/').replaceAll('-', '/');
        
        DateTime? dt;
        final parts = dateStr.split('/');
        if (parts[0].length == 4) {
          dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else if (parts[2].length == 4) {
          dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
        
        if (dt != null && dt.year >= 2020 && dt.year <= 2030) {
          return dt;
        }
      } catch (e) {
        continue;
      }
    }
    
    return DateTime.now();
  }

  static String extractMerchant(String text) {
    if (text.isEmpty) return "Unknown";
    text = _normalizeOcr(text);
    final lines = text.split('\n');
    
    final List<String> knownBrands = [
      'BIM', 'MARJANE', 'ASWAK ASSALAM', 'CARREFOUR', 'ACIMA', 'GLOVO', 'JUMIA'
    ];
    
    final Map<String, String> typoMap = {
      'BIH': 'BIM',
      '8IM': 'BIM',
      'B1M': 'BIM',
      'ASWAK': 'ASWAK ASSALAM',
    };
    
    print("DEBUG: Extracting Merchant from top lines...");
    
    for (int i = 0; i < lines.length && i < 10; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      String upperLine = line.toUpperCase();
      
      for (var typo in typoMap.keys) {
        if (upperLine.contains(typo)) {
          print("  -> FOUND TYPO MATCH: $typo -> ${typoMap[typo]}");
          return typoMap[typo]!;
        }
      }
      
      for (var brand in knownBrands) {
        if (upperLine.contains(brand)) {
          print("  -> FOUND KNOWN BRAND: $brand");
          return brand;
        }
      }
    }
    
    return "Unknown";
  }
}
