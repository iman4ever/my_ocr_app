import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../database/receipt_model.dart';

class ReceiptParser {
  static String _normalizeOcr(String text) {
    if (text.isEmpty) return text;
    String s = text;
    s = s.replaceAll('\r', '\n');
    s = s.replaceAll('\t', ' ');
    s = s.replaceAll(',', '.');
    s = s.replaceAll(RegExp(r'\s+(DH|MAD)\b', caseSensitive: false), ' DH');
    s = s.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    s = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
    return s;
  }

  static String getSortedText(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return '';
    List<TextBlock> sortedBlocks = List.from(recognizedText.blocks);
    sortedBlocks.sort((a, b) {
      int yDiff = (a.boundingBox.top.compareTo(b.boundingBox.top));
      if (yDiff != 0) return yDiff;
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return sortedBlocks.map((block) => block.text).join('\n');
  }

  static List<ReceiptItem> extractItems(String text) {
    text = _normalizeOcr(text);
    List<ReceiptItem> items = [];
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'([0-9]+[.][0-9]{2})');
    
    print('DEBUG: Extracting Items from ${lines.length} lines...');
    
    // Skip header until "OPERATION" or first price
    int startIndex = 0;
    for (int i = 0; i < lines.length && i < 15; i++) {
      String lower = lines[i].toLowerCase();
      if (lower.contains('operation') || lower.contains('vente') || priceRegex.hasMatch(lines[i])) {
        startIndex = i;
        break;
      }
    }
    
    print('DEBUG: Structural Header Skip -> Starting item scan at line $startIndex');
    
    // keep a stack/queue of pending names; some receipts list multiple names before prices
    List<String> pendingNames = [];

    // Find the end index: stop scanning at the first occurrence of total/footer keywords
    int endIndex = lines.length;
    for (int k = startIndex; k < lines.length; k++) {
      final lk = lines[k].toLowerCase();
      if (lk.contains('total') || lk.contains('paiement') || lk.contains('paienent') || lk.contains('nombre article') || lk.contains('net à payer') || lk.contains('total amount')) {
        endIndex = k;
        break;
      }
    }

    for (int i = startIndex; i < endIndex; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;
      
      String lower = line.toLowerCase();
      
      // STOP at footer keywords
      if (lower.contains('paiement') || lower.contains('paienent') || 
          lower.contains('ventilation') || lower.contains('nombre article')) {
        print("DEBUG: Hit footer section '$line'. Stopping item parsing.");
        break;
      }
      
      // Skip metadata lines
      if (lower.contains('operation') || lower.contains('vente') ||
          lower.contains('total') || lower.contains('change') || 
          lower.contains('espece') || lower.contains('rendu') ||
          lower.contains('timbre') || lower.contains('droit') ||
          lower.contains('tva') || lower.contains('merci') ||
          lower.contains('telephone') || lower.contains('fax') ||
          lower.contains('patente') || lower.contains('ice') ||
          lower.contains('horaire') || lower.contains('cash') ||
          lower.contains('prix promotion') || lower.contains('fruits & legumes') ||
          lower.contains('epicerie') || lower.contains('boulangerie') ||
          lower.contains('cremerie') || lower.contains('biscuiterie') ||
          lower.contains('confiserie') || lower.contains('category') ||
          lower.contains('ventilation') || lower.contains('taux')) {
        print('  -> Rejected: Keyword blocklist');
        continue;
      }
      
      // EARLY SKIP: Lines that START with a barcode (e.g., "(5)2100040000850 AUBERGINE KG")
      // These are receipt-internal metadata and should not be items
      final barcodePrefix = RegExp(r'^\s*[\(\[]?\d{3,}[\)\]]?\s');
      if (barcodePrefix.hasMatch(line)) {
        print("  -> Skipped storing (starts with barcode): '$line'");
        continue;
      }
      
      // Try to find a price on this line
      final matches = priceRegex.allMatches(line);
      
      // Detect quantity x unit-price lines like '2 x 1.20'
      final qtyMatch = RegExp(r'(\d+)\s*[x×]\s*([0-9]+[.][0-9]{2})').firstMatch(line);
      if (qtyMatch != null) {
        int qty = int.parse(qtyMatch.group(1)!);
        double unit = double.parse(qtyMatch.group(2)!.replaceAll(',', '.'));
        double total = (qty * unit);
        if (pendingNames.isNotEmpty) {
          String name = pendingNames.removeLast();
          print('  -> QUANTITY LINE: $qty x $unit -> $total; attaching to $name');
          items.add(ReceiptItem(name: name, price: total));
          continue;
        } else {
          // No pending name; treat as standalone price (skip)
          print('  -> Quantity line found but no pending name; skipping');
          continue;
        }
      }

      // Detect weight/quantity + unit-price lines like "0.129 kg x 5.95" or "0.129 x 5.95"
      // Only match if line starts with weight pattern (strict matching to avoid spurious items)
      final weightMatch = RegExp(r'^(\d+[.]\d+)\s*(?:kg|kgx|lbs|lb|g)?\s*[x×]\s*(\d+[.]\d{2})').firstMatch(line);
      if (weightMatch != null) {
        double weight = double.parse(weightMatch.group(1)!);
        double unitPrice = double.parse(weightMatch.group(2)!.replaceAll(',', '.'));
        double total = weight * unitPrice;
        if (pendingNames.isNotEmpty) {
          String name = pendingNames.removeLast();
          print('  -> WEIGHT LINE: $weight x $unitPrice -> $total; attaching to $name');
          items.add(ReceiptItem(name: name, price: total));
          continue;
        } else {
          print('  -> Weight line found but no pending name; skipping');
          continue;
        }
      }

      if (matches.isNotEmpty) {
        String priceStr = matches.last.group(1)!;
        double? price = double.tryParse(priceStr);

        if (price != null && price > 0.1) {
          // Extract name (text before the price)
          String name = line.substring(0, matches.last.start).trim();

          // Clean: remove leading numbers, barcodes, etc.
          name = name.replaceAll(RegExp(r'^\d+\s*'), '').trim();
          // Remove barcode prefixes like "(5)2100040000850 " or "(2>6111..."
          name = name.replaceAll(RegExp(r'^\s*[\(\[]?[0-9>)]+[\)\]]?\s+'), '').trim();
          name = name.replaceAll(RegExp(r'[()0-9>]+'), '').trim();
          name = name.replaceAll(RegExp(r'\s+'), ' ').trim();

          // If name is empty (price-only line), look ahead to see if next line is a weight line
          if (name.isEmpty && pendingNames.isNotEmpty && i + 1 < endIndex) {
            String nextLine = lines[i + 1].trim();
            final nextWeightMatch = RegExp(r'^(\d+[.]\d+)\s*(?:kg|kgx|lbs|lb|g)?\s*[x×]\s*(\d+[.]\d{2})').firstMatch(nextLine);
            if (nextWeightMatch != null) {
              // Next line is a weight line; skip this price-only line and let weight compute the total
              print('  -> SKIP PRICE-ONLY LINE (weight line follows): $price');
              continue;
            }
          }

          // If name is empty but we had pending names, attach to earliest pending (FIFO)
          if ((name.isEmpty || name.length <= 2) && pendingNames.isNotEmpty) {
            String pending = pendingNames.removeAt(0);
            name = pending;
            // Also clean barcode prefix from pending name
            name = name.replaceAll(RegExp(r'^\s*[\(\[]?[0-9>)]+[\)\]]?\s+'), '').trim();
          }

          if (name.length > 2) {
            print('  -> ACCEPTED ITEM: $name - $price');
            items.add(ReceiptItem(name: name, price: price));
            // ensure we don't leave stale pending names
            if (pendingNames.isNotEmpty && pendingNames.last == name) pendingNames.removeLast();
          }
        }
      } else {
        // No price on this line. Possible cases:
        // 1) This line is an item name and the price is on the next line(s).
        // 2) This line is a price-only line (e.g. "2.40") which should attach to pendingName.

        // If the line itself looks like a single price, attach to pendingName
        final priceOnly = RegExp(r'^\s*[0-9]+[.][0-9]{2}\s*$');
        if (priceOnly.hasMatch(line)) {
          double? price = double.tryParse(priceOnly.firstMatch(line)!.group(0)!.trim());
          if (price != null && pendingNames.isNotEmpty) {
            // LOOK AHEAD: check if the next line is a weight line
            // If so, don't accept this price-only line yet; wait for the weight line
            bool nextIsWeight = false;
            if (i + 1 < endIndex) {
              String nextLine = lines[i + 1].trim();
              final nextWeightMatch = RegExp(r'^(\d+[.]\d+)\s*(?:kg|kgx|lbs|lb|g)?\s*[x×]\s*(\d+[.]\d{2})').firstMatch(nextLine);
              if (nextWeightMatch != null) {
                nextIsWeight = true;
                print('  -> SKIP PRICE-ONLY LINE (weight line follows): $price');
              }
            }
            
            if (!nextIsWeight) {
              // Attach to earliest pending name (FIFO) so earlier listed products get earlier prices
              String target = pendingNames.removeAt(0);
              print('  -> ATTACH PRICE-ONLY LINE: $target -> $price');
              items.add(ReceiptItem(name: target, price: price));
              continue;
            }
          }
        }

        // Otherwise, store as pending name expecting price on next line(s)
        if (line.length > 2) {
          // Avoid storing barcodes or numeric-only lines as names
          final barcodeLike = RegExp(r'^[\(\[]?\d{3,}[\)\]\d\s-]*$');
          final qtyLine = RegExp(r'^\s*\d+\s*[x×]\s*\d');
          // UUID pattern: lines containing UUID (case-insensitive) or standard UUID hex-dash format
          final uuidLike = RegExp(r'uuid|[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}', caseSensitive: false);
          // Very long numeric strings (invoice/transaction IDs, typically 15+ digits)
          final longNumeric = RegExp(r'^\d{15,}$');
          
          int letterCount = line.replaceAll(RegExp(r'[^A-Za-z]'), '').length;

          if (barcodeLike.hasMatch(line) || qtyLine.hasMatch(line) || letterCount < 3 || uuidLike.hasMatch(line) || longNumeric.hasMatch(line)) {
            print("  -> Skipped storing (barcode/qty/uuid/invoice): '$line'");
          } else {
            // push into pending names list (clean barcode prefixes first)
            String cleanName = line.replaceAll(RegExp(r'^\s*[\(\[]?[0-9>)]+[\)\]]?\s+'), '').trim();
            cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();
            pendingNames.add(cleanName);
            print("  -> Pushed pending name: '${pendingNames.last}'");
          }
        }
      }
    }
    
    // Print count and explicit list of extracted items (name -> price)
    final itemListStr = items.map((it) => "${it.name} -> ${it.price.toStringAsFixed(2)}").join(' | ');
    print('DEBUG: Extracted ${items.length} items${itemListStr.isNotEmpty ? ': ' : ''}$itemListStr');
    return items;
  }

  static double extractAmount(String text) {
    text = _normalizeOcr(text);
    final lines = text.split('\n');
    final RegExp priceRegex = RegExp(r'([0-9]+[.][0-9]{2})');

    print('DEBUG: --- START EXTRACT AMOUNT ---');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.toLowerCase().contains('total')) {
        print("DEBUG: Found TOTAL keyword in line: '$line'");

        // 1) try same-line
        final sameLine = priceRegex.firstMatch(line);
        if (sameLine != null) {
          double amount = double.parse(sameLine.group(1)!.replaceAll(',', '.'));
          if (amount > 0.1 && amount != 0.06) {
            print('  -> Found amount on same line: $amount');
            return amount;
          }
        }

        // 2) search in a window +/-5 lines and pick the closest valid price (prefer before the label)
        int start = (i - 5).clamp(0, lines.length - 1);
        int end = (i + 5).clamp(0, lines.length - 1);
        List<Map<String, dynamic>> candidates = [];
        final Set<String> paymentKeywords = {'cash', 'espece', 'especes', 'change', 'rendu', 'paiement'};

        for (int j = start; j <= end; j++) {
          String l = lines[j];
          String ll = l.toLowerCase();
          // if this line clearly indicates a payment method, skip
          bool isPaymentLine = paymentKeywords.any((k) => ll.contains(k));

          final matches = priceRegex.allMatches(l);
          for (final m in matches) {
            double val = double.parse(m.group(1)!.replaceAll(',', '.'));
            if (val == 0.06) continue; // skip timbre tiny fee
            if (val <= 0.1) continue;
            // skip price if it's on a payment line
            if (isPaymentLine) continue;

            candidates.add({
              'price': val,
              'distance': (j - i).abs(),
              'before': j <= i,
              'index': j,
            });
          }
        }

        if (candidates.isNotEmpty) {
          candidates.sort((a, b) {
            int da = a['distance'] as int;
            int db = b['distance'] as int;
            if (da != db) return da.compareTo(db);
            // prefer the one that is before or on the same line
            bool ab = a['before'] as bool;
            bool bb = b['before'] as bool;
            if (ab == bb) return 0;
            return ab ? -1 : 1;
          });

          double chosen = candidates.first['price'] as double;
          print('  -> Found amount in window closest to TOTAL: $chosen');
          return chosen;
        }

        // 3) as a last resort check next lines only (older behavior)
        for (int j = 1; j <= 5 && (i + j) < lines.length; j++) {
          String nextLine = lines[i + j];
          final m = priceRegex.firstMatch(nextLine);
          if (m != null) {
            double amount = double.parse(m.group(1)!.replaceAll(',', '.'));
            if (amount > 0.1 && amount != 0.06) {
              print('  -> Found amount on next line (+$j): $amount');
              return amount;
            }
          }
        }
      }
    }

    // Fallback: return largest reasonable price found in document (ignore obvious payment lines)
    final allMatches = <double>[];
    for (int i = 0; i < lines.length; i++) {
      String l = lines[i];
      String ll = l.toLowerCase();
      if ({'cash', 'espece', 'especes', 'change', 'rendu', 'paiement'}.any((k) => ll.contains(k))) continue;
      for (final m in priceRegex.allMatches(l)) {
        double val = double.parse(m.group(1)!.replaceAll(',', '.'));
        if (val == 0.06 || val <= 0.1) continue;
        allMatches.add(val);
      }
    }
    if (allMatches.isNotEmpty) {
      double maxP = allMatches.reduce((a, b) => a > b ? a : b);
      print('DEBUG: Fallback max price: $maxP');
      return maxP;
    }

    print('DEBUG: No TOTAL found; returning 0.0');
    return 0.0;
  }

  static DateTime extractDate(String text) {
    text = _normalizeOcr(text);
    final ddmmyyyyRegex = RegExp(r'(\d{2})/(\d{2})/(\d{4})');
    final match = ddmmyyyyRegex.firstMatch(text);
    if (match != null) {
      int day = int.parse(match.group(1)!);
      int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    
    final yyyymmddRegex = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    final match2 = yyyymmddRegex.firstMatch(text);
    if (match2 != null) {
      int year = int.parse(match2.group(1)!);
      int month = int.parse(match2.group(2)!);
      int day = int.parse(match2.group(3)!);
      return DateTime(year, month, day);
    }
    
    return DateTime.now();
  }

  static String extractMerchant(String text) {
    text = _normalizeOcr(text);
    final lines = text.split('\n');
    
    print('DEBUG: Extracting Merchant from top lines...');
    

    // Normalize and map OCR variants to canonical merchant names.
    final ignoreTokens = {'RECEIPT', 'THANK', 'MODIF.AI', 'MERCI', 'TICKET'};

    for (int i = 0; i < lines.length && i < 12; i++) {
      String raw = lines[i].trim();
      if (raw.isEmpty) continue;
      // uppercase and remove extra whitespace for matching
      String upper = raw.toUpperCase();
      String compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

      // Ignore obvious non-merchant lines
      if (ignoreTokens.any((t) => upper.contains(t))) continue;

      // ASWAK family (many OCR variants). If we detect ASWAK anywhere, normalize to canonical.
      if (compact.contains('ASWAK') || compact.contains('ASWAKASS') || compact.contains('ASSALAM') || compact.contains('ASSATAM') || compact.contains('ASSATAM')) {
        print('  -> SELECTED BEST (normalized): ASWAK ASSALAM');
        return 'ASWAK ASSALAM';
      }

      // Other known brands
      if (compact.contains('MAROC') || compact.contains('BIH') || compact.contains('B1M') || compact.contains('B1M MAROC') || compact.contains('BIH MAROC')) {
        print('  -> SELECTED BEST (normalized): BIM MAROC');
        return 'BIM MAROC';
      }
      if (compact.contains('MARJANE')) {
        print('  -> SELECTED BEST (normalized): MARJANE');
        return 'MARJANE';
      }
      if (compact.contains('CARREFOUR')) {
        print('  -> SELECTED BEST (normalized): CARREFOUR');
        return 'CARREFOUR';
      }
      if (compact.contains('ACIMA')) {
        print('  -> SELECTED BEST (normalized): ACIMA');
        return 'ACIMA';
      }
    }

    // Fallback: pick the first non-metadata line with enough letters
    for (int i = 0; i < lines.length && i < 12; i++) {
      String lower = lines[i].toLowerCase();
      int letterCount = lines[i].replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (!lower.contains('operation') && !lower.contains('total') &&
          !lower.contains('cash') && letterCount >= 3) {
        print('  -> SELECTED BEST (fallback): ${lines[i]}');
        return lines[i];
      }
    }
    
    print('  -> SELECTED BEST: UNKNOWN');
    return 'UNKNOWN';
  }
}
